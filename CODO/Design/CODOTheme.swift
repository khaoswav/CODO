import SwiftUI

enum CODOTheme {
    static let background = Color(hex: 0x101014)
    static let surface = Color(hex: 0x18181F)
    static let elevated = Color(hex: 0x20202A)
    static let border = Color.white.opacity(0.075)
    static let accent = Color(hex: 0x9B83F6)
    static let accentSoft = Color(hex: 0x9B83F6).opacity(0.14)
    static let primaryText = Color(hex: 0xF2F0F8)
    static let secondaryText = Color(hex: 0x92909F)
    static let mutedText = Color(hex: 0x62616D)
    static let green = Color(hex: 0x65C99A)
    static let orange = Color(hex: 0xE6B477)
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
    @ViewBuilder var content: Content

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
