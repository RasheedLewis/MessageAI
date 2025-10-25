import SwiftUI

struct ConversationRowView: View {
    let item: ConversationListViewModel.ConversationItem

    var body: some View {
        HStack(spacing: 16) {
            avatarView

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.theme.subhead)
                        .foregroundStyle(Color.theme.textOnPrimary)
                        .lineLimit(1)

                    if let category = item.aiCategory {
                        CategoryBadgeView(category: category)
                    }
                }

                Text(item.lastMessagePreview ?? "No messages yet")
                    .font(.theme.body)
                    .foregroundStyle(Color.theme.textOnPrimary.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                if let lastTime = item.lastMessageTime {
                    Text(lastTime, style: .time)
                        .font(.theme.caption)
                        .foregroundStyle(Color.theme.textOnPrimary.opacity(0.6))
                }

                if item.unreadCount > 0 {
                    Text("\(item.unreadCount)")
                        .font(.theme.captionMedium)
                        .foregroundStyle(Color.theme.textOnPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.theme.accent))
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color.theme.surface.opacity(0.9))
                .frame(width: 48, height: 48)

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
            participantIDs: []
        )
    )
    .padding()
}

