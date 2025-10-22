import SwiftUI

struct ConversationRowView: View {
    let item: ConversationListViewModel.ConversationItem

    var body: some View {
        HStack(spacing: 16) {
            avatarView

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let category = item.aiCategory {
                        CategoryBadgeView(category: category)
                    }
                }

                Text(item.lastMessagePreview ?? "No messages yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                if let lastTime = item.lastMessageTime {
                    Text(lastTime, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if item.unreadCount > 0 {
                    Text("\(item.unreadCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor))
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 48, height: 48)

            Text(initials(from: item.title))
                .font(.headline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(item.isOnline ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color(.systemBackground), lineWidth: 2)
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

