import Combine
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    struct ChatMessage: Identifiable, Equatable {
        let id: String
        let content: String
        let senderID: String
        let senderName: String?
        let timestamp: Date
        let isCurrentUser: Bool
        let status: LocalMessageStatus
    }

    struct Participant: Identifiable, Equatable {
        let id: String
        let displayName: String
    }

    @Published private(set) var messages: [ChatMessage] = []
    @Published var draftText: String = ""
    @Published private(set) var isSending: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var conversationTitle: String = "Conversation"
    @Published private(set) var participantSummary: String = ""
    @Published private(set) var isGroupConversation: Bool = false
    @Published private(set) var participants: [Participant] = []
    @Published var isTypingAI: Bool = false
    @Published private(set) var isGeneratingSuggestion: Bool = false
    @Published private(set) var suggestionError: String?
    @Published private(set) var currentSuggestion: AISuggestion?
    @Published private(set) var suggestionPreview: String = ""

    struct AISuggestion: Equatable {
        let reply: String
        let tone: String
        let format: String
        let reasoning: String
        let followUpQuestions: [String]
        let suggestedNextActions: [String]
        let generatedAt: Date
        let iteration: Int
    }

    enum SuggestionFeedbackVerdict {
        case positive
        case negative

        var modelValue: AISuggestionFeedback.Verdict {
            switch self {
            case .positive: return .positive
            case .negative: return .negative
            }
        }
    }

    private let conversationID: String
    private let localDataManager: LocalDataManager
    private let messageService: MessageServiceProtocol
    private let listenerService: MessageListenerServiceProtocol
    private let userDirectoryService: UserDirectoryServiceProtocol
    private let aiService: AIServiceProtocol
    private let messageRepository: MessageRepositoryProtocol
    private let userRepository: UserRepositoryType
    private let currentUserID: String
    private var cancellables: Set<AnyCancellable> = []
    private var participantNames: [String: String] = [:]
    private var suggestionIteration: Int = 0
    private var suggestionTask: Task<Void, Never>?
    private var latestRemoteMessages: [LocalMessage] = []
    private var typingPreviewCancellable: AnyCancellable?
    private var lastSuggestionMessageID: String?

    init(
        conversationID: String,
        services: ServiceResolver,
        prefilledSuggestion: String? = nil
    ) {
        self.conversationID = conversationID
        self.localDataManager = services.localDataManager
        self.messageService = services.messageService
        self.listenerService = services.messageListenerService
        self.userDirectoryService = services.userDirectoryService
        self.aiService = services.aiService
        self.messageRepository = services.messageRepository
        self.userRepository = services.userRepository
        self.currentUserID = services.currentUserID
        self.suggestionPreview = prefilledSuggestion ?? ""
        observeMessageUpdates()
        observeDraftChanges()
    }

    func onAppear() {
        Task {
            await loadParticipantNames()
            await MainActor.run { self.reloadMessages() }
        }
        listenerService.startMessagesListener(
            for: conversationID,
            currentUserID: currentUserID
        ) { [weak self] error in
            self?.handleError(error)
        }
    }

    func onDisappear() {
        listenerService.stopMessagesListener(for: conversationID)
        suggestionTask?.cancel()
    }

    func sendMessage() async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        draftText = ""
        isSending = true
        let result = await messageService.sendTextMessage(
            text,
            conversationID: conversationID,
            currentUserID: currentUserID
        )

        if case .failure(let error) = result {
            handleError(error)
        } else {
            errorMessage = nil
        }

        reloadMessages()
        isSending = false
        resetSuggestionState()
    }

    private func observeMessageUpdates() {
        listenerService.messageUpdatesPublisher
            .filter { [weak self] conversationID in
                conversationID == self?.conversationID
            }
            .sink { [weak self] _ in
                self?.reloadMessages()
                self?.updateConversationInfo()
            }
            .store(in: &cancellables)
    }

    private func reloadMessages() {
        let localMessages = (try? localDataManager.fetchMessages(forConversationID: conversationID)) ?? []
        messages = localMessages.map { makeChatMessage(from: $0) }
        latestRemoteMessages = localMessages
        updateConversationInfo()
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        print("[ChatViewModel] Error: \(error.localizedDescription)")
    }

    private func makeChatMessage(from local: LocalMessage) -> ChatMessage {
        ChatMessage(
            id: local.id,
            content: local.content,
            senderID: local.senderID,
            senderName: participantNames[local.senderID],
            timestamp: local.timestamp,
            isCurrentUser: local.senderID == currentUserID,
            status: local.status
        )
    }

    private func loadParticipantNames() async {
        guard let conversation = try? localDataManager.conversation(withID: conversationID) else {
            await MainActor.run {
                participantNames = [:]
                participants = []
                conversationTitle = "Conversation"
                participantSummary = ""
                isGroupConversation = false
            }
            return
        }

        let missingIDs = conversation.participantIDs.filter { participantNames[$0] == nil && $0 != currentUserID }
        if !missingIDs.isEmpty {
            do {
                let users = try await userDirectoryService.fetchUsers(withIDs: missingIDs)
                var updated = participantNames
                users.forEach { updated[$0.id] = $0.displayName }
                await MainActor.run { participantNames = updated }
            } catch {
                // Ignore errors; UI will fall back to default labeling.
            }
        }

        await MainActor.run {
            updateConversationInfo()
        }
    }

    private func updateConversationInfo() {
        guard let conversation = try? localDataManager.conversation(withID: conversationID) else {
            conversationTitle = "Conversation"
            participantSummary = ""
            isGroupConversation = false
            participants = []
            return
        }

        isGroupConversation = conversation.type == .group
        conversationTitle = conversation.title

        let participantIDs = conversation.participantIDs
        let mappedParticipants: [Participant] = participantIDs.compactMap { id in
            let displayName: String
            if id == currentUserID {
                displayName = "You"
            } else if let cached = participantNames[id] {
                displayName = cached
            } else {
                displayName = "Unknown"
            }
            return Participant(id: id, displayName: displayName)
        }
        participants = mappedParticipants

        if isGroupConversation {
            let otherParticipants = mappedParticipants.filter { $0.id != currentUserID }
            switch otherParticipants.count {
            case 0:
                participantSummary = "Only you"
            case 1:
                participantSummary = otherParticipants[0].displayName
            case 2:
                participantSummary = otherParticipants.map { $0.displayName }.joined(separator: ", ")
            default:
                let firstTwo = otherParticipants.prefix(2).map { $0.displayName }.joined(separator: ", ")
                participantSummary = "\(firstTwo) +\(otherParticipants.count - 2) more"
            }
        } else {
            participantSummary = ""
        }
    }

    // MARK: - AI Suggestions

    func generateSuggestion() {
        guard !isGeneratingSuggestion else { return }
        suggestionTask?.cancel()

        suggestionIteration += 1
        let iteration = suggestionIteration

        isGeneratingSuggestion = true
        suggestionError = nil
        suggestionPreview = ""

        let history = buildConversationHistory()
        let lastIncomingMessage = latestRemoteMessages.reversed().first { $0.senderID != currentUserID }
        let fallbackMessage = draftText
        let baseMessage = lastIncomingMessage?.content ?? fallbackMessage
        let sanitizedMessage = baseMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitizedMessage.isEmpty else {
            finishSuggestion(suggestion: nil, errorMessage: "No recent message to respond to.")
            return
        }

        suggestionPreview = previewText(for: sanitizedMessage)

        let contextualInfo = buildConversationContext(from: lastIncomingMessage)
        let creatorContext = currentCreatorProfile()

        suggestionTask = Task { [weak self] in
            guard let self else { return }

            do {
                let request = AIResponseGenerationRequest(
                    message: sanitizedMessage,
                    conversationHistory: history,
                    creatorDisplayName: creatorContext?.displayName,
                    profile: creatorContext?.profile,
                    conversationContext: contextualInfo
                )

                let result = try await aiService.generateResponse(request).asyncValue()

                let suggestion = AISuggestion(
                    reply: result.reply,
                    tone: result.tone,
                    format: result.format,
                    reasoning: result.reasoning,
                    followUpQuestions: result.followUpQuestions,
                    suggestedNextActions: result.suggestedNextActions,
                    generatedAt: Date(),
                    iteration: iteration
                )

                await MainActor.run {
                    self.finishSuggestion(suggestion: suggestion, errorMessage: nil)
                    self.lastSuggestionMessageID = lastIncomingMessage?.id
                }
            } catch {
                await MainActor.run {
                    self.finishSuggestion(suggestion: nil, errorMessage: "Failed to generate suggestion. Please try again.")
                }
            }
        }
    }

    func applySuggestionToDraft() {
        guard let suggestion = currentSuggestion else { return }
        draftText = suggestion.reply
        resetSuggestionState()
    }

    func regenerateSuggestion() {
        generateSuggestion()
    }

    func dismissSuggestion() {
        resetSuggestionState()
    }

    func recordFeedback(verdict: SuggestionFeedbackVerdict) {
        guard let suggestion = currentSuggestion else { return }
        guard let user = userRepository.currentUser() else { return }
        guard let targetMessageID = suggestionMessageID() else { return }

        Task { [weak self] in
            guard let self else { return }

            do {
                let metadata: [String: String] = [
                    "tone": suggestion.tone,
                    "format": suggestion.format,
                    "iteration": String(suggestion.iteration)
                ]

                let feedback = AISuggestionFeedback(
                    verdict: verdict.modelValue,
                    comment: nil,
                    userId: user.id,
                    suggestionMetadata: metadata
                )

                try await messageRepository.appendAISuggestionFeedback(
                    conversationID: conversationID,
                    messageID: targetMessageID,
                    feedback: feedback
                )

                try await MainActor.run {
                    try self.localDataManager.appendAISuggestionFeedback(
                        conversationID: conversationID,
                        messageID: targetMessageID,
                        feedback: feedback
                    )
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func finishSuggestion(suggestion: AISuggestion?, errorMessage: String?) {
        currentSuggestion = suggestion
        suggestionError = errorMessage
        suggestionPreview = suggestion.map { previewText(for: $0.reply) } ?? ""
        isGeneratingSuggestion = false
    }

    private func resetSuggestionState() {
        suggestionTask?.cancel()
        suggestionTask = nil
        isGeneratingSuggestion = false
        suggestionError = nil
        currentSuggestion = nil
        suggestionPreview = ""
    }

    private func buildConversationHistory() -> [AIResponseGenerationRequest.ConversationEntry] {
        let recentMessages = latestRemoteMessages.suffix(8)
        return recentMessages.map { message in
            let speaker: String
            if message.senderID == currentUserID {
                speaker = "You"
            } else if let name = participantNames[message.senderID], !name.isEmpty {
                speaker = name
            } else {
                speaker = "Participant"
            }

            let content = message.content.isEmpty && message.mediaURL != nil
                ? "[Attachment]"
                : message.content

            return AIResponseGenerationRequest.ConversationEntry(
                speaker: speaker,
                content: content
            )
        }
    }

    private func buildConversationContext(from lastIncoming: LocalMessage?) -> AIResponseGenerationRequest.ConversationContext {
        let localConversation = try? localDataManager.conversation(withID: conversationID)
        let conversationCategory = localConversation?.aiCategory
        let category = conversationCategory.flatMap { MessageCategory(rawValue: $0.rawValue) }?.rawValue
        let sentiment = localConversation?.aiSentiment
        let priority = localConversation?.aiPriority

        let latestIncomingTimestamp = lastIncoming?.timestamp
        let lastResponseTimestamp = latestRemoteMessages
            .reversed()
            .first { $0.senderID == currentUserID }?
            .timestamp

        return AIResponseGenerationRequest.ConversationContext(
            category: category,
            sentiment: sentiment,
            priority: priority,
            latestIncomingTimestamp: latestIncomingTimestamp,
            lastResponseTimestamp: lastResponseTimestamp,
            participantCount: participants.count
        )
    }

    private func currentCreatorProfile() -> (displayName: String?, profile: CreatorProfile?)? {
        guard let user = userRepository.currentUser() else { return nil }
        return (user.displayName, user.creatorProfile)
    }

    private func previewText(for reply: String) -> String {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 140 else { return trimmed }
        let prefix = trimmed.prefix(140)
        return prefix + "…"
    }

    func primeSuggestionPreview(with text: String?) {
        suggestionPreview = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func observeDraftChanges() {
        typingPreviewCancellable = $draftText
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self else { return }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    self.suggestionPreview = ""
                } else {
                    self.suggestionPreview = self.previewText(for: trimmed)
                }
            }
    }

    private func suggestionMessageID() -> String? {
        if let lastSuggestionMessageID {
            return lastSuggestionMessageID
        }

        // Fall back to most recent incoming message
        return latestRemoteMessages.reversed().first { $0.senderID != currentUserID }?.id
    }
}

private extension AnyPublisher {
    func asyncValue() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = first()
                .sink { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                } receiveValue: { value in
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                }
        }
    }
}

