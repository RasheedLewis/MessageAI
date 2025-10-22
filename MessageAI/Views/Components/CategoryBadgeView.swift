import SwiftUI

struct CategoryBadgeView: View {
    let category: MessageCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)
            Text(categoryTitle)
                .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor.opacity(0.2))
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
            return "heart.fill"
        case .business:
            return "briefcase.fill"
        case .spam:
            return "exclamationmark.triangle.fill"
        case .urgent:
            return "bolt.fill"
        case .general:
            return "bubble.left.fill"
        }
    }

    private var backgroundColor: Color {
        switch category {
        case .fan:
            return .green
        case .business:
            return .blue
        case .spam:
            return .gray
        case .urgent:
            return .red
        case .general:
            return .purple
        }
    }
}

#Preview {
    CategoryBadgeView(category: .business)
}

