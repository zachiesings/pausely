import Foundation
import Combine
import UserNotifications

/// Per-kind reminder configuration, persisted as JSON.
struct ReminderConfig: Codable {
    var enabled: Bool
    var minutes: Int
}

/// Owns reminder configuration, schedules local notifications, tracks the
/// next-break countdown, and keeps a lightweight in-app daily stat of breaks.
///
/// The actual alerts are delivered by `UNUserNotificationCenter`. The in-app
/// countdown and stats are best-effort conveniences computed from the
/// scheduled fire times.
@MainActor
final class ReminderStore: ObservableObject {
    private let d = UserDefaults.standard
    private let center = UNUserNotificationCenter.current()

    private let configKey = "pausely.config"
    private let statsPrefix = "pausely.stats."

    /// Current configuration per kind.
    @Published private(set) var configs: [ReminderKind: ReminderConfig]

    /// Next scheduled fire date per enabled kind (used for the countdown).
    @Published private(set) var nextFire: [ReminderKind: Date] = [:]

    /// Whether the user has granted notification permission.
    @Published private(set) var authorized = false

    /// Today's completed-break counts per kind (in-app stat only).
    @Published private(set) var todayCounts: [ReminderKind: Int]

    /// Drives the live countdown / passed-fire detection.
    private var tick: Timer?

    init() {
        configs = Self.loadConfigs(d, key: configKey)
        todayCounts = [:]
        todayCounts = loadTodayCounts()
        startTick()
        Task { await refreshAuthorization() }
    }

    // MARK: - Persistence

    private static func loadConfigs(_ d: UserDefaults, key: String) -> [ReminderKind: ReminderConfig] {
        if let data = d.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: ReminderConfig].self, from: data) {
            var result: [ReminderKind: ReminderConfig] = [:]
            for kind in ReminderKind.allCases {
                if let cfg = decoded[kind.rawValue] {
                    result[kind] = cfg
                } else {
                    result[kind] = Self.defaultConfig(for: kind)
                }
            }
            return result
        }
        // First launch: only eyes enabled at its default cadence.
        var result: [ReminderKind: ReminderConfig] = [:]
        for kind in ReminderKind.allCases {
            result[kind] = Self.defaultConfig(for: kind)
        }
        return result
    }

    private static func defaultConfig(for kind: ReminderKind) -> ReminderConfig {
        ReminderConfig(enabled: kind == .eyes, minutes: kind.defaultMinutes)
    }

    private func persistConfigs() {
        var raw: [String: ReminderConfig] = [:]
        for (kind, cfg) in configs { raw[kind.rawValue] = cfg }
        if let data = try? JSONEncoder().encode(raw) {
            d.set(data, forKey: configKey)
        }
    }

    // MARK: - Accessors

    func config(for kind: ReminderKind) -> ReminderConfig {
        configs[kind] ?? Self.defaultConfig(for: kind)
    }

    func isEnabled(_ kind: ReminderKind) -> Bool { config(for: kind).enabled }
    func minutes(_ kind: ReminderKind) -> Int { config(for: kind).minutes }

    var enabledKinds: [ReminderKind] {
        ReminderKind.allCases.filter { isEnabled($0) }
    }

    var anyEnabled: Bool { !enabledKinds.isEmpty }

    // MARK: - Mutations

    func setEnabled(_ kind: ReminderKind, _ enabled: Bool) {
        var cfg = config(for: kind)
        cfg.enabled = enabled
        configs[kind] = cfg
        persistConfigs()
        Task {
            if enabled { await requestAuthIfNeeded() }
            reschedule()
        }
    }

    func setMinutes(_ kind: ReminderKind, _ minutes: Int) {
        var cfg = config(for: kind)
        cfg.minutes = max(1, minutes)
        configs[kind] = cfg
        persistConfigs()
        reschedule()
    }

    // MARK: - Authorization

    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    /// Request authorization the first time the user enables a reminder.
    /// Never crashes if denied — we silently degrade to the in-app countdown.
    func requestAuthIfNeeded() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            authorized = granted
        case .authorized, .provisional:
            authorized = true
        default:
            authorized = false
        }
    }

    // MARK: - Scheduling

    /// Cancel all pending Pausely notifications and re-add the enabled ones.
    func reschedule() {
        let ids = ReminderKind.allCases.map { Self.identifier(for: $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        var fires: [ReminderKind: Date] = [:]
        let now = Date()

        for kind in enabledKinds {
            let interval = TimeInterval(max(1, minutes(kind)) * 60)
            fires[kind] = now.addingTimeInterval(interval)

            // Only schedule the OS notification if we're allowed to.
            guard authorized else { continue }

            let content = UNMutableNotificationContent()
            content.title = kind.title
            content.body = kind.notificationBody
            // Pro can mute the sound; free always uses the default sound.
            content.sound = Settings.shared.playSound ? .default : nil

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.identifier(for: kind),
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error = error {
                    NSLog("Pausely notification schedule error (\(kind.rawValue)): \(error.localizedDescription)")
                }
            }
        }

        nextFire = fires
    }

    private static func identifier(for kind: ReminderKind) -> String {
        "pausely.reminder.\(kind.rawValue)"
    }

    // MARK: - Countdown

    /// Soonest upcoming enabled kind and its remaining time interval.
    var nextBreak: (kind: ReminderKind, remaining: TimeInterval)? {
        let now = Date()
        let upcoming = nextFire.map { ($0.key, $0.value.timeIntervalSince(now)) }
        guard let soonest = upcoming.min(by: { $0.1 < $1.1 }) else { return nil }
        return (soonest.0, max(0, soonest.1))
    }

    /// "mm:ss" of the next break, or "" if none.
    var nextBreakText: String {
        guard let next = nextBreak else { return "" }
        let total = Int(next.remaining.rounded())
        let m = total / 60, s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// Whole minutes until the next break, rounded up (for the menu-bar label).
    var nextBreakMinutes: Int? {
        guard let next = nextBreak else { return nil }
        return max(1, Int((next.remaining / 60).rounded(.up)))
    }

    // MARK: - Stats

    private func todayKey() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return statsPrefix + f.string(from: Date())
    }

    private func loadTodayCounts() -> [ReminderKind: Int] {
        guard let raw = d.dictionary(forKey: todayKey()) as? [String: Int] else { return [:] }
        var result: [ReminderKind: Int] = [:]
        for (k, v) in raw {
            if let kind = ReminderKind(rawValue: k) { result[kind] = v }
        }
        return result
    }

    private func persistTodayCounts() {
        var raw: [String: Int] = [:]
        for (kind, count) in todayCounts { raw[kind.rawValue] = count }
        d.set(raw, forKey: todayKey())
    }

    private func bump(_ kind: ReminderKind) {
        todayCounts[kind, default: 0] += 1
        persistTodayCounts()
    }

    /// Total breaks taken today across all kinds.
    var todayTotal: Int { todayCounts.values.reduce(0, +) }

    // MARK: - Foreground tick

    private func startTick() {
        tick?.invalidate()
        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.onTick() }
        }
    }

    /// Detects passed fires (for in-app stats), reloads stats at midnight, and
    /// republishes so the countdown view updates each second.
    private func onTick() {
        let now = Date()

        // Detect any fire times that have elapsed: bump the stat and advance to
        // the next occurrence so the in-app countdown keeps cycling.
        for kind in enabledKinds {
            guard let fire = nextFire[kind] else { continue }
            if fire <= now {
                bump(kind)
                let interval = TimeInterval(max(1, minutes(kind)) * 60)
                nextFire[kind] = fire.addingTimeInterval(interval)
            }
        }

        // Keep today's counts pointed at the right day across a midnight cross.
        let reloaded = loadTodayCounts()
        if reloaded != todayCounts && reloaded.isEmpty {
            todayCounts = reloaded
        }

        // Nudge SwiftUI so the live countdown re-renders.
        objectWillChange.send()
    }
}
