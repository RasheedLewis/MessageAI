import Combine
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    struct ChatMessage: Identifiable, Equatable {
        let id: String
        let content: String
        let senderID: String
        let timestamp: Date
        let isCurrentUser: Bool
        let status: LocalMessageStatus
    }

    @Published private(set) var messages: [ChatMessage] = []
    @Published var draftText: String = ""
    @Published private(set) var isSending: Bool = false
    @Published private(set) var errorMessage: String?

    private let conversationID: String
    private let localDataManager: LocalDataManager
    private let messageService: MessageServiceProtocol
    private let listenerService: MessageListenerServiceProtocol
    private let currentUserID: String
    private var cancellables: Set<AnyCancellable> = []

    init(
        conversationID: String,
        services: ServiceResolver
    ) {
        self.conversationID = conversationID
        self.localDataManager = services.localDataManager
        self.messageService = services.messageService
        self.listenerService = services.messageListenerService
        self.currentUserID = services.currentUserID
        observeMessageUpdates()
    }

    func onAppear() {
        reloadMessages()
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
            }
            .store(in: &cancellables)
    }

    private func reloadMessages() {
        let localMessages = (try? localDataManager.fetchMessages(forConversationID: conversationID)) ?? []
        messages = localMessages.map { makeChatMessage(from: $0) }
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
            timestamp: local.timestamp,
            isCurrentUser: local.senderID == currentUserID,
            status: local.status
        )
    }
}

