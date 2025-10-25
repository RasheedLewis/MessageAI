import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @Namespace private var bottomID

    init(conversationID: String, services: ServiceResolver) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationID: conversationID, services: services))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messagesList
            Divider()
            MessageInputView(
                text: $viewModel.draftText,
                isSending: viewModel.isSending,
                onSend: send,
                onAttachment: nil
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .background(chatBackground)
        .overlay(alignment: .top) {
            if let errorMessage = viewModel.errorMessage {
                ErrorBanner(message: errorMessage)
            }
        }
    }

    private var chatBackground: some View {
        Color.theme.chatBackground
            .overlay(
                RadialGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)]),
                    center: .center,
                    startRadius: 120,
                    endRadius: 500
                )
            )
            .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.conversationTitle)
                        .font(.theme.subhead)
                        .foregroundStyle(Color.theme.textOnPrimary)

                    if !viewModel.participantSummary.isEmpty {
                        Text(viewModel.participantSummary)
                            .font(.theme.caption)
                            .foregroundStyle(Color.theme.textOnPrimary.opacity(0.6))
                    }
                }

                Spacer()

                if viewModel.isGroupConversation {
                    NavigationLink {
                        GroupInfoView(participants: viewModel.participants)
                    } label: {
                        ThemedIcon(systemName: "person.3", state: .active, size: 18)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .background(Color.theme.primaryVariant)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageRowView(message: message)
                            .id(message.id)
                    }

                    if viewModel.isTypingAI {
                        TypingIndicatorView()
                            .padding(.top, 8)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color.theme.primaryVariant)
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }

    private func send() {
        Task {
            await viewModel.sendMessage()
        }
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.theme.captionMedium)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.theme.error)
            .foregroundColor(Color.theme.textOnPrimary)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

private struct MessageRowView: View {
    let message: ChatViewModel.ChatMessage

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

    private var bubble: some View {
        VStack(alignment: message.isCurrentUser ? .trailing : .leading, spacing: 4) {
            if !message.isCurrentUser, let senderName = message.senderName {
                Text(senderName)
                        .font(.theme.captionMedium)
                    .foregroundStyle(Color.theme.textOnSurface.opacity(0.6))
            }

            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundColor(Color.theme.textOnPrimary)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: message.isCurrentUser ? Color.theme.secondary.opacity(0.35) : Color.theme.accent.opacity(0.45), radius: message.isCurrentUser ? 10 : 14, x: 0, y: 6)

            HStack(spacing: 4) {
                Text(message.timestamp, style: .time)
                if message.isCurrentUser {
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
        case .delivered:
            return "checkmark.circle"
        case .read:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
}

private struct GroupInfoView: View {
    let participants: [ChatViewModel.Participant]

    var body: some View {
        List(participants) { participant in
            HStack {
                Circle()
                    .fill(Color.theme.primaryVariant.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(initials(for: participant.displayName))
                            .font(.theme.captionMedium)
                            .foregroundStyle(Color.theme.textOnSurface.opacity(0.6))
                    )
                Text(participant.displayName)
                    .font(.theme.body)
            }
        }
        .navigationTitle("Group Info")
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).map { $0.prefix(1).uppercased() }.joined()
    }
}

#Preview {
    let services = ServiceResolver.previewResolver
    ChatView(conversationID: "preview", services: services)
        .environmentObject(NotificationCoordinator())
}

