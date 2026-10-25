import SwiftUI
import UIKit

enum Theme {
    static let bg = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let text = Color.primary
    static let muted = Color.secondary
    static let accent = Color(red: 0.15, green: 0.60, blue: 0.55)
    static let accentSoft = Color(red: 0.15, green: 0.60, blue: 0.55).opacity(0.12)

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }

    private static let coverGradients: [(Color, Color)] = [
        (rgb(0.98, 0.72, 0.55), rgb(0.94, 0.54, 0.42)),
        (rgb(0.64, 0.82, 0.96), rgb(0.40, 0.65, 0.92)),
        (rgb(0.70, 0.88, 0.76), rgb(0.46, 0.76, 0.60)),
        (rgb(0.86, 0.75, 0.94), rgb(0.68, 0.52, 0.86)),
        (rgb(0.98, 0.85, 0.55), rgb(0.90, 0.70, 0.30)),
        (rgb(0.96, 0.73, 0.80), rgb(0.88, 0.50, 0.62)),
        (rgb(0.58, 0.78, 0.86), rgb(0.34, 0.58, 0.70)),
        (rgb(0.80, 0.74, 0.62), rgb(0.62, 0.54, 0.42))
    ]

    static func coverGradient(for key: String) -> LinearGradient {
        let g = coverGradients[Int(stableHash(key) % UInt64(coverGradients.count))]
        return LinearGradient(colors: [g.0, g.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func stableHash(_ s: String) -> UInt64 {
        var h: UInt64 = 14695981039346656037
        for b in s.utf8 {
            h ^= UInt64(b)
            h = h &* 1099511628211
        }
        return h
    }
}
