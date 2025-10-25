import SwiftUI

struct ThemedIcon: View {
    enum State {
        case active
        case inactive
        case custom(Color, glow: Bool = false)
    }

    let systemName: String
    var state: State = .active
    var size: CGFloat = 20
    var withContainer: Bool = false
    var showsBorder: Bool = true

    private var color: Color {
        switch state {
        case .active:
            return Color.theme.accent
        case .inactive:
            return Color.theme.disabled
        case .custom(let customColor, _):
            return customColor
        }
    }

    private var hasGlow: Bool {
        switch state {
        case .active:
            return true
        case .inactive:
            return false
        case .custom(_, let glow):
            return glow
        }
    }

    var body: some View {
        Image(systemName: systemName)
            .renderingMode(.original)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: size, weight: .medium, design: .rounded))
            .foregroundStyle(color)
            .padding(withContainer ? 6 : 0)
            .background(containerBackground)
            .overlay(containerStroke)
            .clipShape(RoundedRectangle(cornerRadius: withContainer ? 4 : 0, style: .continuous))
            .shadow(color: hasGlow ? color.opacity(0.6) : .clear, radius: hasGlow ? 6 : 0, x: 0, y: 0)
    }

    @ViewBuilder
    private var containerBackground: some View {
        if withContainer {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.theme.primaryVariant.opacity(0.12))
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var containerStroke: some View {
        if withContainer && showsBorder {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(color.opacity(0.7), lineWidth: 2)
        } else {
            EmptyView()
        }
    }
}


