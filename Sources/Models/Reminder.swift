import Foundation

/// The four kinds of gentle break reminders Pausely offers.
enum ReminderKind: String, CaseIterable, Identifiable, Codable {
    case eyes, stand, water, stretch

    var id: String { rawValue }

    /// Short title shown in the menu rows.
    var title: String {
        switch self {
        case .eyes:    return "Rest your eyes"
        case .stand:   return "Stand up"
        case .water:   return "Drink water"
        case .stretch: return "Stretch"
        }
    }

    /// One-line supporting description.
    var detail: String {
        switch self {
        case .eyes:    return "Look 20 feet away for 20 seconds"
        case .stand:   return "Get up and move around a little"
        case .water:   return "Take a sip and stay hydrated"
        case .stretch: return "Loosen up your neck and shoulders"
        }
    }

    /// SF Symbol name for the row icon.
    var symbol: String {
        switch self {
        case .eyes:    return "eye.fill"
        case .stand:   return "figure.stand"
        case .water:   return "drop.fill"
        case .stretch: return "figure.flexibility"
        }
    }

    /// Default cadence in minutes (also the locked interval for free users).
    var defaultMinutes: Int {
        switch self {
        case .eyes:    return 20
        case .stand:   return 50
        case .water:   return 45
        case .stretch: return 60
        }
    }

    /// Body text for the local notification.
    var notificationBody: String {
        switch self {
        case .eyes:    return "Time to rest your eyes — look 20 feet away for 20 seconds."
        case .stand:   return "Time to stand up — stretch your legs for a moment."
        case .water:   return "Time to drink some water — stay hydrated."
        case .stretch: return "Time to stretch — loosen up your neck and shoulders."
        }
    }
}
