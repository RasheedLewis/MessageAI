import SwiftUI

struct ThemedButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case tertiary
        case disabled
    }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.theme.button)
            .foregroundStyle(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(background)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 1.03 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private var textColor: Color {
        switch kind {
        case .primary:
            return Color.theme.textOnPrimary
        case .disabled:
            return Color.theme.textOnSurface.opacity(0.6)
        case .secondary:
            return Color.theme.secondary
        case .tertiary:
            return Color.theme.accent
        }
    }

    @ViewBuilder
    private var background: some View {
        switch kind {
        case .primary:
            Color.theme.secondary
        case .disabled:
            Color.theme.disabled.opacity(0.3)
        case .secondary, .tertiary:
            Color.clear
        }
    }

    @ViewBuilder
    private var border: some View {
        switch kind {
        case .primary, .tertiary, .disabled:
            EmptyView()
        case .secondary:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.theme.secondary, lineWidth: 1)
        }
    }
}

extension ButtonStyle where Self == ThemedButtonStyle {
    static var primaryThemed: ThemedButtonStyle { .init(kind: .primary) }
    static var primaryDisabledThemed: ThemedButtonStyle { .init(kind: .disabled) }
    static var secondaryThemed: ThemedButtonStyle { .init(kind: .secondary) }
    static var tertiaryThemed: ThemedButtonStyle { .init(kind: .tertiary) }
}

extension View {
    func glowOverlay(color: Color, radius: CGFloat = 12) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.0), lineWidth: 0)
                .shadow(color: color.opacity(0.35), radius: radius, x: 0, y: 0)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
    }
}


