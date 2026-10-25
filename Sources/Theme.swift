import SwiftUI

enum Theme {
    static let ink = Color(red: 0.05, green: 0.07, blue: 0.10)
    static let inkSoft = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let surface = Color(red: 0.11, green: 0.14, blue: 0.19)
    static let gold = Color(red: 0.84, green: 0.70, blue: 0.42)
    static let goldSoft = Color(red: 0.95, green: 0.87, blue: 0.68)
    static let text = Color(red: 0.95, green: 0.92, blue: 0.86)
    static let muted = Color(red: 0.62, green: 0.58, blue: 0.52)

    static var background: LinearGradient {
        LinearGradient(
            colors: [ink, Color(red: 0.09, green: 0.11, blue: 0.16)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var coverFallback: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.16, green: 0.20, blue: 0.28), Color(red: 0.10, green: 0.12, blue: 0.17)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
