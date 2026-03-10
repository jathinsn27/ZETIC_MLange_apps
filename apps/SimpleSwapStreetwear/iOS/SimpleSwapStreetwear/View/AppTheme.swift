import SwiftUI

enum AppTheme {
    // Streetwear-inspired palette
    static let primary = Color(hex: "FF3CAC")
    static let secondary = Color(hex: "784BA0")
    static let accent = Color(hex: "2B86C5")
    static let backgroundDark = Color(hex: "0D0D0D")
    static let backgroundLight = Color(hex: "F5F5F7")
    static let surfaceDark = Color(hex: "1A1A2E")
    static let surfaceLight = Color(hex: "FFFFFF")
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    static let gradient = LinearGradient(
        colors: [primary, secondary, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [surfaceDark, Color(hex: "16213E")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let swapColors: [(name: String, color: Color, rgb: (CGFloat, CGFloat, CGFloat))] = [
        ("Crimson", Color(hex: "DC143C"), (0.863, 0.078, 0.235)),
        ("Electric Blue", Color(hex: "007BFF"), (0.0, 0.482, 1.0)),
        ("Emerald", Color(hex: "50C878"), (0.314, 0.784, 0.471)),
        ("Sunset Orange", Color(hex: "FF6B35"), (1.0, 0.420, 0.208)),
        ("Royal Purple", Color(hex: "7851A9"), (0.471, 0.318, 0.663)),
        ("Midnight Black", Color(hex: "1C1C1C"), (0.110, 0.110, 0.110)),
        ("Cloud White", Color(hex: "F0F0F0"), (0.941, 0.941, 0.941)),
        ("Neon Pink", Color(hex: "FF10F0"), (1.0, 0.063, 0.941)),
        ("Gold", Color(hex: "FFD700"), (1.0, 0.843, 0.0)),
        ("Olive", Color(hex: "808000"), (0.502, 0.502, 0.0)),
        ("Teal", Color(hex: "008080"), (0.0, 0.502, 0.502)),
        ("Coral", Color(hex: "FF7F50"), (1.0, 0.498, 0.314)),
    ]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

