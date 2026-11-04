import AppKit
import SwiftUI

enum CODOTheme {
    // Plasma Fusion: Axor-inspired neon glass on a deep obsidian canvas.
    static let background = Color(hex: 0x0B0814)
    static let surface = Color(hex: 0x20102B).opacity(0.84)
    static let elevated = Color(hex: 0x281438).opacity(0.94)
    static let border = Color(hex: 0xB56CFF).opacity(0.22)
    static let accent = Color(hex: 0x8B35FF)
    static let accentSecondary = Color(hex: 0xF044B8)
    static let accentSoft = accent.opacity(0.16)
    static let glow = Color(hex: 0xF044B8)
    static let highlight = Color(hex: 0xFF9BCE)
    static let primaryText = Color(hex: 0xFFF7FF)
    static let secondaryText = Color(hex: 0xC6B6D1)
    static let mutedText = Color(hex: 0x8D7B9B)
    static let green = Color(hex: 0x5CE6AE)
    static let orange = Color(hex: 0xFFBD70)
    static let red = Color(hex: 0xFF668A)
    static let cosmicGradient = LinearGradient(
        colors: [Color(hex: 0x160D22), Color(hex: 0x0B0814), Color(hex: 0x1A0C20)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

struct Panel<Content: View>: View {
    let title: String
    let accessory: String?
    let content: Content

    init(_ title: String, accessory: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accessory = accessory
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(CODOTheme.primaryText)
                Spacer()
                if let accessory {
                    Text(accessory.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(CODOTheme.highlight)
                }
            }
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CODOTheme.surface)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(colors: [CODOTheme.highlight.opacity(0.34), CODOTheme.accent.opacity(0.12), CODOTheme.glow.opacity(0.28)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        }
        .shadow(color: CODOTheme.accent.opacity(0.10), radius: 22, y: 9)
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [CODOTheme.accent, CODOTheme.accentSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: CODOTheme.glow.opacity(configuration.isPressed ? 0.12 : 0.34), radius: configuration.isPressed ? 7 : 16, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

struct CosmicBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CODOTheme.cosmicGradient
                RadialGradient(
                    colors: [CODOTheme.accent.opacity(0.25), .clear],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: proxy.size.width * 0.66
                )
                RadialGradient(
                    colors: [CODOTheme.glow.opacity(0.17), .clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: proxy.size.width * 0.58
                )
                RadialGradient(
                    colors: [CODOTheme.highlight.opacity(0.07), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: proxy.size.width * 0.8
                )
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}
