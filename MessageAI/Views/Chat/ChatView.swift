import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @Namespace private var bottomID

    init(conversationID: String, services: ServiceResolver) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationID: conversationID, services: services))
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesList
            Divider()
            inputBar
        }
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .top) {
            if let errorMessage = viewModel.errorMessage {
                ErrorBanner(message: errorMessage)
            }
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageRowView(message: message)
                            .id(message.id)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(.systemBackground))
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $viewModel.draftText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...6)

            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20, weight: .semibold))
            }
            .disabled(viewModel.isSending || viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Material.thin)
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
            .font(.footnote.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.85))
            .foregroundColor(.white)
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
            Text(message.content)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(message.isCurrentUser ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundColor(message.isCurrentUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 4) {
                Text(message.timestamp, style: .time)
                if message.isCurrentUser {
                    Image(systemName: iconName)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        }
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
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
}

#Preview {
    let services = ServiceResolver.previewResolver
    ChatView(conversationID: "preview", services: services)
}

