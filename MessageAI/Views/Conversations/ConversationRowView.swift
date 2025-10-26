import SwiftUI

struct ConversationRowView: View {
    let item: ConversationListViewModel.ConversationItem
    let onOverrideCategory: (MessageCategory) -> Void
    let onClearOverride: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            avatarView

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.theme.headline17)
                    .tracking(1)
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                Text(item.lastMessagePreview ?? "No messages yet")
                    .font(.theme.subtitle14)
                    .foregroundStyle(AppColors.subtitle)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                if let category = item.aiCategory, category != .general {
                    CategoryBadgeView(category: category)
                }

                if let lastTime = item.lastMessageTime {
                    Text(lastTime, style: .time)
                        .font(.theme.timestamp13)
                        .foregroundStyle(AppColors.timestamp)
                }

                if item.unreadCount > 0 {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.unreadGlow.opacity(0.8))
                            .frame(width: 8, height: 8)
                            .shadow(color: AppColors.unreadGlow.opacity(0.7), radius: 6)

                        Text("\(item.unreadCount)")
                            .font(.theme.captionMedium)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppColors.unreadBadge))
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(AppColors.conversationBackground)
        .overlay(
            Rectangle()
                .fill(LinearGradient(
                    colors: [AppColors.separator.opacity(0.0), AppColors.separator.opacity(0.8), AppColors.separator.opacity(0.0)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 1)
                .offset(y: 40),
            alignment: .bottom
        )
        .contextMenu {
            ForEach(MessageCategory.allCases, id: \.self) { category in
                Button {
                    onOverrideCategory(category)
                } label: {
                    Label(categoryTitle(for: category), systemImage: categoryIcon(for: category))
                }
            }

            Button(role: .destructive) {
                onClearOverride()
            } label: {
                Label(categoryTitle(for: nil), systemImage: "arrow.uturn.backward")
            }
        }
    }

    private var avatarView: some View {
        let badgeColor = item.aiCategory.map(categoryColor) ?? Color.theme.secondary

        return ZStack {
            Circle()
                .fill(Color.theme.surface.opacity(0.9))
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .stroke(badgeColor.opacity(0.8), lineWidth: 2)
                )
                .shadow(color: badgeColor.opacity(0.45), radius: 8, x: 0, y: 0)

            Text(initials(from: item.title))
                .font(.theme.captionMedium)
                .foregroundStyle(Color.theme.textOnSurface.opacity(0.6))
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(item.isOnline ? Color.theme.secondary : Color.theme.disabled)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.theme.surface, lineWidth: 2)
                )
                .offset(x: 4, y: 4)
        }
    }

    private func initials(from name: String) -> String {
        let components = name.split(separator: " ")
        let initials = components.prefix(2).map { $0.prefix(1).uppercased() }
        return initials.joined()
    }

    private func categoryTitle(for category: MessageCategory?) -> String {
        switch category {
        case .some(.fan):
            return "Fan"
        case .some(.business):
            return "Business"
        case .some(.spam):
            return "Spam"
        case .some(.urgent):
            return "Urgent"
        case .some(.general):
            return "General"
        case .none:
            return "Reset Category"
        }
    }

    private func categoryIcon(for category: MessageCategory) -> String {
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

    private func categoryColor(for category: MessageCategory) -> Color {
        switch category {
        case .fan:
            return Color(red: 0.28, green: 0.78, blue: 0.46)
        case .business:
            return Color(red: 0.29, green: 0.54, blue: 0.96)
        case .spam:
            return Color(red: 0.58, green: 0.63, blue: 0.70)
        case .urgent:
            return Color(red: 0.95, green: 0.33, blue: 0.31)
        case .general:
            return Color.theme.primary
        }
    }
}

#Preview {
    ConversationRowView(
        item: .init(
            id: "1",
            title: "Creator Collective",
            lastMessagePreview: "Can't wait for the next collab!",
            lastMessageTime: Date(),
            unreadCount: 2,
            isOnline: true,
            aiCategory: .business,
            aiSentiment: "positive",
            aiPriority: 80,
            participantIDs: []
        ),
        onOverrideCategory: { _ in },
        onClearOverride: {}
    )
    .padding()
}

