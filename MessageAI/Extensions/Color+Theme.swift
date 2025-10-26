import SwiftUI

extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: cleaned).scanHexInt64(&int)

        let red, green, blue: UInt64
        switch cleaned.count {
        case 3:
            red = ((int >> 8) & 0xF) * 17
            green = ((int >> 4) & 0xF) * 17
            blue = (int & 0xF) * 17
        case 6:
            red = (int >> 16) & 0xFF
            green = (int >> 8) & 0xFF
            blue = int & 0xFF
        default:
            red = 0
            green = 0
            blue = 0
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: opacity
        )
    }
}

extension Color {
    static let theme = AppColorTheme()
}

struct AppColorTheme {
    let primary = Color(hex: "#2B2E4A")
    let primaryVariant = Color(hex: "#1D203A")
    let secondary = Color(hex: "#E94F37")
    let accent = Color(hex: "#B29BFF")
    let surfaceVariant = Color(hex: "#FFFFFF", opacity: 0.08)
    let surface = Color(hex: "#F8F6F3")
    let textOnPrimary = Color(hex: "#FFFFFF")
    let textOnSurface = Color(hex: "#121212")
    let disabled = Color(hex: "#777B90")
    let error = Color(hex: "#FF6B6B")
    let chatBackground = Color(hex: "#1D203A")
    let inputBar = Color(hex: "#2B2E4A")
    let inputBorder = Color(hex: "#393D5A")
    let userBubbleStart = Color(hex: "#E94F37")
    let userBubbleEnd = Color(hex: "#FF6B6B").opacity(0.8)
    let aiBubbleStart = Color(hex: "#7F63FF")
    let aiBubbleEnd = Color(hex: "#B29BFF")
}


