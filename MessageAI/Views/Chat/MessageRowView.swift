import SwiftUI

struct MessageRowView: View {
    let message: ChatViewModel.ChatMessage
    let retryHandler: () async -> Void

    var body: some View {
        HStack {
            if message.isCurrentUser {
                Spacer(minLength: 48)
                bubble
            } else {
                bubble
                Spacer(minLength: 48)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var bubble: some View {
        VStack(alignment: message.isCurrentUser ? .trailing : .leading, spacing: 4) {
            if !message.isCurrentUser, let senderName = message.senderName {
                Text(senderName)
                    .font(.theme.captionMedium)
                    .foregroundStyle(Color.theme.textOnSurface.opacity(0.6))
            }

            if let mediaURL = message.mediaURL {
                ImageMessageView(url: mediaURL, isCurrentUser: message.isCurrentUser, status: message.status)
            }

            if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundColor(Color.theme.textOnPrimary)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: message.isCurrentUser ? Color.theme.secondary.opacity(0.35) : Color.theme.accent.opacity(0.45), radius: message.isCurrentUser ? 10 : 14, x: 0, y: 6)
            }

            HStack(spacing: 4) {
                Text(message.timestamp, style: .time)

                if message.status == .failed {
                    Button {
                        Task { await retryHandler() }
                    } label: {
                        ThemedIcon(systemName: "arrow.clockwise", state: .custom(Color.theme.error, glow: false), size: 12)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                } else if message.isCurrentUser {
                    ThemedIcon(systemName: iconName, state: .inactive, size: 10)
                }
            }
            .font(.theme.caption)
            .foregroundStyle(Color.theme.textOnPrimary.opacity(0.6))
            .padding(.horizontal, 4)
        }
    }

    private var bubbleBackground: some View {
        let gradient = LinearGradient(
            gradient: Gradient(colors: message.isCurrentUser ? [Color.theme.userBubbleStart, Color.theme.userBubbleEnd] : [Color.theme.aiBubbleStart, Color.theme.aiBubbleEnd]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(gradient)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(message.isCurrentUser ? 0.08 : 0.2), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.theme.accent.opacity(message.isCurrentUser ? 0.0 : 0.35), lineWidth: message.isCurrentUser ? 0 : 2)
                    .blur(radius: 8)
                    .opacity(message.isCurrentUser ? 0 : 1)
            )
    }

    private var iconName: String {
        switch message.status {
        case .sending:
            return "clock"
        case .sent:
            return "checkmark"
        case .delivered, .read:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
}
