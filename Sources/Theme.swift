import SwiftUI
import UIKit

enum Theme {
    static let bg = Color.black
    static let text = Color.white
    static let muted = Color.white.opacity(0.58)

    static let accent = Color(red: 1.00, green: 0.20, blue: 0.36)
    static let accent2 = Color(red: 1.00, green: 0.42, blue: 0.32)
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let onDark = Color.white
    static let onDarkMuted = Color.white.opacity(0.70)

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }

    private static let coverGradients: [(Color, Color)] = [
        (rgb(0.98, 0.68, 0.50), rgb(0.93, 0.45, 0.42)),
        (rgb(0.62, 0.80, 0.98), rgb(0.36, 0.60, 0.94)),
        (rgb(0.66, 0.90, 0.78), rgb(0.36, 0.74, 0.56)),
        (rgb(0.88, 0.74, 0.98), rgb(0.66, 0.46, 0.92)),
        (rgb(0.99, 0.84, 0.50), rgb(0.95, 0.66, 0.22)),
        (rgb(0.98, 0.70, 0.80), rgb(0.92, 0.42, 0.60)),
        (rgb(0.55, 0.80, 0.90), rgb(0.30, 0.58, 0.72)),
        (rgb(0.82, 0.76, 0.64), rgb(0.62, 0.52, 0.40)),
        (rgb(0.72, 0.62, 0.98), rgb(0.46, 0.36, 0.90)),
        (rgb(0.62, 0.88, 0.86), rgb(0.28, 0.66, 0.66))
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

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
