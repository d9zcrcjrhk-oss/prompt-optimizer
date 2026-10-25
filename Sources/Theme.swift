import SwiftUI
import UIKit

enum Theme {
    static let accent = Color(red: 0.49, green: 0.30, blue: 0.90)
    static let accent2 = Color(red: 0.93, green: 0.28, blue: 0.60)
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let onDark = Color.white
    static let onDarkMuted = Color.white.opacity(0.72)
    static let text = Color.primary
    static let muted = Color.secondary

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func aurora(_ scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.07, blue: 0.22),
                    Color(red: 0.24, green: 0.06, blue: 0.30),
                    Color(red: 0.04, green: 0.10, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.92, blue: 1.00),
                Color(red: 1.00, green: 0.90, blue: 0.93),
                Color(red: 0.88, green: 0.95, blue: 1.00)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

struct AuroraBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Theme.aurora(scheme)

            Circle()
                .fill(Theme.accent.opacity(scheme == .dark ? 0.34 : 0.20))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -120, y: -240)

            Circle()
                .fill(Theme.accent2.opacity(scheme == .dark ? 0.30 : 0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 140, y: 250)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(scheme == .dark ? 0.32 : 0.80),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.10), radius: 16, y: 8)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
