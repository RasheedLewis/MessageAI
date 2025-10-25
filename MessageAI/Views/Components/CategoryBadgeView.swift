import SwiftUI

struct CategoryBadgeView: View {
    let category: MessageCategory

    var body: some View {
        HStack(spacing: 4) {
            ThemedIcon(
                systemName: iconName,
                state: .custom(backgroundColor, glow: false),
                size: 10
            )
            Text(categoryTitle)
                .font(.theme.captionMedium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor.opacity(0.18))
        .foregroundStyle(backgroundColor)
        .clipShape(Capsule())
    }

    private var categoryTitle: String {
        switch category {
        case .fan:
            return "Fan"
        case .business:
            return "Business"
        case .spam:
            return "Spam"
        case .urgent:
            return "Urgent"
        case .general:
            return "General"
        }
    }

    private var iconName: String {
        switch category {
        case .fan:
            return "heart"
        case .business:
            return "briefcase"
        case .spam:
            return "exclamationmark.triangle"
        case .urgent:
            return "bolt"
        case .general:
            return "bubble.left"
        }
    }

    private var backgroundColor: Color {
        switch category {
        case .fan:
            return Color.theme.accent
        case .business:
            return Color.theme.secondary
        case .spam:
            return Color.theme.disabled
        case .urgent:
            return Color.theme.error
        case .general:
            return Color.theme.primary
        }
    }
}

#Preview {
    CategoryBadgeView(category: .business)
}

