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

    private let conversationID: String
    private let localDataManager: LocalDataManager
    private let messageService: MessageServiceProtocol
    private let listenerService: MessageListenerServiceProtocol
    private let userDirectoryService: UserDirectoryServiceProtocol
    private let currentUserID: String
    private var cancellables: Set<AnyCancellable> = []
    private var participantNames: [String: String] = [:]

    init(
        conversationID: String,
        services: ServiceResolver
    ) {
        self.conversationID = conversationID
        self.localDataManager = services.localDataManager
        self.messageService = services.messageService
        self.listenerService = services.messageListenerService
        self.userDirectoryService = services.userDirectoryService
        self.currentUserID = services.currentUserID
        observeMessageUpdates()
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
}

