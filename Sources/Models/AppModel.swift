import SwiftUI
import Combine

@MainActor
final class AppModel: ObservableObject {
    let store = ReminderStore()
    let entitlements = Entitlements()
    let settings = Settings.shared

    private var bag = Set<AnyCancellable>()

    init() {
        // Re-broadcast nested ObservableObject changes so SwiftUI views update.
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
        entitlements.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
    }

    var isPro: Bool { entitlements.isPro }

    // MARK: - Free vs Pro gating
    //
    // FREE: exactly ONE reminder kind may be enabled at a time, and its
    //       interval is locked to the default (cannot be edited).
    // PRO:  enable all kinds simultaneously, custom intervals, stats, sound.

    /// Whether `kind` can be turned on right now given the current plan.
    /// Pro can always enable. Free can enable a kind only if no other kind is
    /// currently enabled (turning the already-enabled one off is always fine).
    func canEnableAnother(_ kind: ReminderKind) -> Bool {
        if isPro { return true }
        if store.isEnabled(kind) { return true }
        return store.enabledKinds.isEmpty
    }

    /// Whether the user may edit reminder intervals (Pro only).
    var canEditInterval: Bool { isPro }

    /// Toggle a reminder, enforcing the free-tier single-reminder rule.
    /// Returns false if the action is blocked (caller should show the paywall).
    @discardableResult
    func toggle(_ kind: ReminderKind, to enabled: Bool) -> Bool {
        if enabled && !canEnableAnother(kind) { return false }
        store.setEnabled(kind, enabled)
        return true
    }

    /// Apply a custom interval if allowed; returns false if blocked (free).
    @discardableResult
    func setMinutes(_ kind: ReminderKind, _ minutes: Int) -> Bool {
        guard canEditInterval else { return false }
        store.setMinutes(kind, minutes)
        return true
    }
}
