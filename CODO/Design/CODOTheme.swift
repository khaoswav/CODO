import AppKit
import SwiftUI

enum CODOTheme {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let elevated = Color(nsColor: .underPageBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.65)
    static let accent = Color(hex: 0x8B72E8)
    static let accentSoft = accent.opacity(0.13)
    static let primaryText = Color(nsColor: .labelColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let mutedText = Color(nsColor: .tertiaryLabelColor)
    static let green = Color(nsColor: .systemGreen)
    static let orange = Color(nsColor: .systemOrange)
    static let red = Color(nsColor: .systemRed)
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
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(CODOTheme.secondaryText)
                Spacer()
                if let accessory {
                    Text(accessory).font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CODOTheme.accent)
                }
            }
            content
        }
        .padding(20)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CODOTheme.border, lineWidth: 1))
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 15).padding(.vertical, 10)
            .background(CODOTheme.accent.opacity(configuration.isPressed ? 0.72 : 1),
                        in: RoundedRectangle(cornerRadius: 8))
    }
}
