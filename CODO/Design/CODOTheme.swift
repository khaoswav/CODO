import AppKit
import SwiftUI

enum CODOTheme {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor).opacity(0.82)
    static let elevated = Color(nsColor: .underPageBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.42)
    static let accent = Color(hex: 0x70E1FF)
    static let accentSecondary = Color(hex: 0x8B7CFF)
    static let accentSoft = accent.opacity(0.12)
    static let primaryText = Color(nsColor: .labelColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let mutedText = Color(nsColor: .tertiaryLabelColor)
    static let green = Color(nsColor: .systemGreen)
    static let orange = Color(nsColor: .systemOrange)
    static let red = Color(nsColor: .systemRed)
    static let cosmicGradient = LinearGradient(
        colors: [Color(hex: 0x111B32), Color(hex: 0x17172F), Color(hex: 0x101722)],
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
                        .foregroundStyle(CODOTheme.accent)
                }
            }
            content
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(CODOTheme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.88))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [CODOTheme.accent, Color(hex: 0xA3F0FF)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .shadow(color: CODOTheme.accent.opacity(configuration.isPressed ? 0.08 : 0.22), radius: 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

struct CosmicBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CODOTheme.background
                RadialGradient(
                    colors: [CODOTheme.accentSecondary.opacity(0.13), .clear],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: proxy.size.width * 0.72
                )
                RadialGradient(
                    colors: [CODOTheme.accent.opacity(0.09), .clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: proxy.size.width * 0.62
                )
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}
