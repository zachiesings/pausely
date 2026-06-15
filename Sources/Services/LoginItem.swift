import ServiceManagement
import Foundation

/// "Launch at login" via SMAppService — App Store compliant: only active when
/// the user turns it on themselves (default off).
enum LoginItem {
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("Pausely LoginItem error: \(error.localizedDescription)")
            return false
        }
    }
}
