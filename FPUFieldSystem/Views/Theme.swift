import SwiftUI

enum Theme {
    static let bgDark = Color(red: 0x07 / 255, green: 0x0a / 255, blue: 0x13 / 255)
    static let cardBg = Color(red: 0x11 / 255, green: 0x16 / 255, blue: 0x25 / 255)
    static let borderStroke = Color(red: 0x1e / 255, green: 0x25 / 255, blue: 0x38 / 255)
    static let accentGreen = Color(red: 0x10 / 255, green: 0xb9 / 255, blue: 0x81 / 255)
    static let accentBlue = Color(red: 0x38 / 255, green: 0xbd / 255, blue: 0xf8 / 255)
    static let accentOrange = Color(red: 0xfb / 255, green: 0x92 / 255, blue: 0x3c / 255)
    static let rose = Color(red: 0xfb / 255, green: 0x71 / 255, blue: 0x85 / 255)
    static let amber = Color(red: 0xfb / 255, green: 0xbf / 255, blue: 0x24 / 255)
}

extension LinkCategory {
    var accentColor: Color {
        switch self {
        case .main: return Theme.accentBlue
        case .relay: return Theme.accentOrange
        case .opt: return Theme.accentGreen
        }
    }

    var label: String {
        switch self {
        case .main: return "本線系統 (main)"
        case .relay: return "リレー系統 (relay)"
        case .opt: return "光回線系統 (opt)"
        }
    }
}
