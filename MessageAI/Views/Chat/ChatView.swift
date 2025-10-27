import SwiftUI
import PhotosUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @Namespace private var bottomID
    @State private var selectedMediaItem: PhotosPickerItem?

    init(conversationID: String, services: ServiceResolver) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationID: conversationID, services: services))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messagesList
            Divider()
            suggestionToolbar
            MessageInputView(
                text: $viewModel.draftText,
                isSending: viewModel.isSending,
                onSend: send,
                mediaSelection: $selectedMediaItem
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
        .onChange(of: selectedMediaItem) { newValue in
            guard let newValue else { return }
            Task {
                await handleAttachmentSelection(newValue)
                await MainActor.run { selectedMediaItem = nil }
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

    private var suggestionToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Label("AI Assist", systemImage: "sparkles")
                    .font(.theme.captionMedium)
                    .foregroundStyle(Color.theme.accent)

                Spacer()

                if viewModel.currentSuggestion == nil {
                    Button(action: viewModel.generateSuggestion) {
                        HStack(spacing: 6) {
                            ZStack {
                                Image(systemName: "wand.and.stars")
                                    .opacity(viewModel.isGeneratingSuggestion ? 0 : 1)
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(Color.theme.accent)
                                    .scaleEffect(0.75)
                                    .opacity(viewModel.isGeneratingSuggestion ? 1 : 0)
                            }
                            Text(viewModel.isGeneratingSuggestion ? "Drafting…" : "Suggest Reply")
                                .font(.theme.bodyMedium)
                        }
                        .foregroundStyle(Color.theme.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.theme.accent.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isGeneratingSuggestion)
                }
            }

            VStack(spacing: 12) {
                if let suggestion = viewModel.currentSuggestion {
                    AISuggestionCard(
                        suggestion: suggestion,
                        onInsert: viewModel.applySuggestionToDraft,
                        onRegenerate: viewModel.regenerateSuggestion,
                        onDismiss: viewModel.dismissSuggestion,
                        hasSubmittedFeedback: viewModel.hasSubmittedFeedback,
                        feedbackSelection: viewModel.feedbackSelection,
                        onFeedback: { verdict in viewModel.recordFeedback(verdict: verdict) }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let errorMessage = viewModel.suggestionError {
                    Text(errorMessage)
                        .font(.theme.caption)
                        .foregroundStyle(Color.theme.error)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.currentSuggestion)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.theme.primaryVariant.opacity(0.9))
        )
        .padding(.horizontal)
        .padding(.top, 12)
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
                .padding(
                    .vertical,
                    12
                )
            }
            .background(Color.theme.primaryVariant)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }

    private func send() {
        Task {
            await viewModel.sendMessage()
        }
    }

    private func handleAttachmentSelection(_ item: PhotosPickerItem) async {
        // Placeholder to be implemented in Storage/Image message subtasks.
    }
}

private struct AISuggestionCard: View {
    let suggestion: ChatViewModel.AISuggestion
    let onInsert: () -> Void
    let onRegenerate: () -> Void
    let onDismiss: () -> Void
    let hasSubmittedFeedback: Bool
    let feedbackSelection: ChatViewModel.SuggestionFeedbackVerdict?
    let onFeedback: (ChatViewModel.SuggestionFeedbackVerdict) -> Void

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Suggestion", systemImage: "sparkles")
                    .font(.theme.captionMedium)
                    .foregroundStyle(Color.theme.accent)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.theme.captionMedium)
                        .foregroundStyle(Color.theme.textOnPrimary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            Text(suggestion.reply)
                .font(.theme.body)
                .foregroundStyle(Color.theme.textOnPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)

            if hasDetails {
                DisclosureGroup(isExpanded: $isExpanded) {
                    suggestionDetails
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Hide details" : "Show details")
                            .font(.theme.caption)
                            .foregroundStyle(Color.theme.accent)
                        Image(systemName: "chevron.right")
                            .font(.theme.caption)
                            .foregroundStyle(Color.theme.accent)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .disclosureGroupStyle(.automatic)
                .onAppear { isExpanded = false }
            }

            HStack(spacing: 12) {
                Button(action: onInsert) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc")
                            .foregroundStyle(Color.theme.accent)
                        Text("Use Reply")
                            .foregroundStyle(Color.theme.accent)
                            .font(.theme.bodyMedium)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.theme.accent.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.theme.accent.opacity(0.35), lineWidth: 1)
                )

                Button(action: onRegenerate) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.theme.textOnPrimary.opacity(0.85))
                        Text("Regenerate")
                            .foregroundStyle(Color.theme.textOnPrimary.opacity(0.85))
                            .font(.theme.bodyMedium)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.theme.textOnPrimary.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.theme.textOnPrimary.opacity(0.2), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            feedbackButtons
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.theme.primary)
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.theme.accent.opacity(0.4), lineWidth: 1)
        )
    }

    private var suggestionDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            followUpSection
            actionsSection
            reasoningSection
        }
        .padding(.top, 4)
    }

    private var followUpSection: some View {
        Group {
            if !suggestion.followUpQuestions.isEmpty {
                Text("Follow-ups:")
                    .font(.theme.captionMedium)
                    .foregroundStyle(Color.theme.textOnPrimary.opacity(0.85))
                ForEach(suggestion.followUpQuestions, id: \.self) { question in
                    Text("• " + question)
                        .font(.theme.caption)
                        .foregroundStyle(Color.theme.textOnPrimary.opacity(0.9))
                }
            }
        }
    }

    private var actionsSection: some View {
        Group {
            if !suggestion.suggestedNextActions.isEmpty {
                Text("Next actions:")
                    .font(.theme.captionMedium)
                    .foregroundStyle(Color.theme.textOnPrimary.opacity(0.85))
                ForEach(suggestion.suggestedNextActions, id: \.self) { action in
                    Text("• " + action)
                        .font(.theme.caption)
                        .foregroundStyle(Color.theme.textOnPrimary.opacity(0.9))
                }
            }
        }
    }

    private var reasoningSection: some View {
        Text("Reasoning: " + suggestion.reasoning)
            .font(.theme.caption)
            .foregroundStyle(Color.theme.textOnPrimary.opacity(0.7))
    }

    private var feedbackButtons: some View {
        HStack(spacing: 12) {
            Button {
                guard !hasSubmittedFeedback else { return }
                onFeedback(.positive)
            } label: {
                Label(
                    hasSubmittedFeedback && feedbackSelection == .positive ? "Thanks" : "Helpful",
                    systemImage: (hasSubmittedFeedback && feedbackSelection == .positive) ? "hand.thumbsup.fill" : "hand.thumbsup"
                )
                    .font(.theme.captionMedium)
            }
            .buttonStyle(.tertiaryThemed)
            .disabled(hasSubmittedFeedback)

            Button {
                guard !hasSubmittedFeedback else { return }
                onFeedback(.negative)
            } label: {
                Label(
                    hasSubmittedFeedback && feedbackSelection == .negative ? "Logged" : "Not Quite",
                    systemImage: (hasSubmittedFeedback && feedbackSelection == .negative) ? "hand.thumbsdown.fill" : "hand.thumbsdown"
                )
                    .font(.theme.captionMedium)
            }
            .buttonStyle(.tertiaryThemed)
            .disabled(hasSubmittedFeedback)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var hasDetails: Bool {
        !suggestion.reasoning.isEmpty || !suggestion.followUpQuestions.isEmpty || !suggestion.suggestedNextActions.isEmpty
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

