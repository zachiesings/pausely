import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case aurora, sunset, mint, mono

    var id: String { rawValue }

    var name: String {
        switch self {
        case .aurora: return "Aurora"
        case .sunset: return "Sunset"
        case .mint:   return "Mint"
        case .mono:   return "Mono"
        }
    }

    var accent: Color {
        switch self {
        case .aurora: return Color(red: 0.36, green: 0.49, blue: 0.98)
        case .sunset: return Color(red: 0.98, green: 0.45, blue: 0.42)
        case .mint:   return Color(red: 0.16, green: 0.78, blue: 0.62)
        case .mono:   return Color(red: 0.52, green: 0.53, blue: 0.60)
        }
    }

    var gradient: [Color] {
        switch self {
        case .aurora: return [Color(red: 0.36, green: 0.49, blue: 0.98), Color(red: 0.62, green: 0.31, blue: 0.87)]
        case .sunset: return [Color(red: 0.98, green: 0.45, blue: 0.42), Color(red: 0.96, green: 0.62, blue: 0.30)]
        case .mint:   return [Color(red: 0.16, green: 0.78, blue: 0.62), Color(red: 0.20, green: 0.60, blue: 0.86)]
        case .mono:   return [Color(red: 0.42, green: 0.42, blue: 0.47), Color(red: 0.22, green: 0.22, blue: 0.27)]
        }
    }
}
