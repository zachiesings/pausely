import SwiftUI

/// Lightweight, observable user preferences backed by `UserDefaults`.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var themeID: String {
        didSet { d.set(themeID, forKey: "pausely.theme") }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            d.set(launchAtLogin, forKey: "pausely.launchAtLogin")
            LoginItem.setEnabled(launchAtLogin)
        }
    }
    /// Whether break notifications play a sound. Pro controls this; free always
    /// uses the default sound (this value defaults to true).
    @Published var playSound: Bool {
        didSet { d.set(playSound, forKey: "pausely.playSound") }
    }

    var theme: AppTheme { AppTheme(rawValue: themeID) ?? .aurora }

    private init() {
        themeID = d.string(forKey: "pausely.theme") ?? AppTheme.aurora.rawValue
        launchAtLogin = LoginItem.isEnabled
        playSound = d.object(forKey: "pausely.playSound") as? Bool ?? true
    }
}
