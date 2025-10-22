import Foundation

public enum MessageServiceError: LocalizedError {
    case missingCurrentUser
    case conversationNotFound
    case localDataFailure(Error)
    case remoteFailure(Error)
    case emptyMessage

    public var errorDescription: String? {
        switch self {
        case .missingCurrentUser:
            return "The current user could not be determined."
        case .conversationNotFound:
            return "Unable to locate the conversation reference."
        case .localDataFailure(let error):
            return "Failed to update local data: \(error.localizedDescription)"
        case .remoteFailure(let error):
            return "Failed to sync message to Firestore: \(error.localizedDescription)"
        case .remoteFailure(let error):
            return "Failed to sync message to Firestore: \(error.localizedDescription)"
        case .emptyMessage:
            return "Messages must contain at least one visible character or attachment."
        }
    }
}

protocol MessageServiceProtocol {
    func sendTextMessage(
        _ content: String,
        conversationID: String,
        currentUserID: String
    ) async -> Result<Message, MessageServiceError>

    func sendMediaMessage(
        mediaURL: URL,
        conversationID: String,
        currentUserID: String,
        placeholderText: String
    ) async -> Result<Message, MessageServiceError>

    func retryPendingMessage(
        messageID: String,
        conversationID: String,
        currentUserID: String
    ) async -> Result<Message, MessageServiceError>
}

final class MessageService: MessageServiceProtocol {
    private struct Dependencies {
        let localDataManager: LocalDataManager
        let conversationRepository: ConversationRepositoryProtocol
        let messageRepository: MessageRepositoryProtocol
        let idGenerator: () -> String
        let clock: () -> Date
    }

    private let dependencies: Dependencies

init(
    localDataManager: LocalDataManager,
    conversationRepository: ConversationRepositoryProtocol,
    messageRepository: MessageRepositoryProtocol,
    idGenerator: @escaping () -> String = { UUID().uuidString },
    clock: @escaping () -> Date = Date.init
) {
        dependencies = Dependencies(
            localDataManager: localDataManager,
            conversationRepository: conversationRepository,
            messageRepository: messageRepository,
            idGenerator: idGenerator,
            clock: clock
        )
    }

    // MARK: - Public API

    public func sendTextMessage(
        _ content: String,
        conversationID: String,
        currentUserID: String
    ) async -> Result<Message, MessageServiceError> {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.emptyMessage)
        }

        let message = makeMessage(
            conversationID: conversationID,
            senderID: currentUserID,
            content: trimmed
        )

        return await send(message: message, conversationID: conversationID)
    }

    public func sendMediaMessage(
        mediaURL: URL,
        conversationID: String,
        currentUserID: String,
        placeholderText: String = ""
    ) async -> Result<Message, MessageServiceError> {
        let message = makeMessage(
            conversationID: conversationID,
            senderID: currentUserID,
            content: placeholderText,
            mediaURL: mediaURL
        )

        return await send(message: message, conversationID: conversationID)
    }

    public func retryPendingMessage(
        messageID: String,
        conversationID: String,
        currentUserID: String
    ) async -> Result<Message, MessageServiceError> {
        do {
            let localMessage = try dependencies.localDataManager.message(withID: messageID)
            let message = Message(
                id: localMessage.id,
                conversationId: localMessage.conversationID,
                senderId: localMessage.senderID,
                content: localMessage.content,
                mediaURL: localMessage.mediaURL,
                timestamp: localMessage.timestamp,
                status: .sending
            )

            try dependencies.localDataManager.updateMessageStatus(messageID: message.id, status: .sending)
            try dependencies.localDataManager.updateMessageSyncStatus(
                messageID: message.id,
                status: .pending,
                direction: .upload,
                syncedAt: nil
            )

            return await send(message: message, conversationID: conversationID, skipLocalInsert: true)
        } catch {
            return .failure(.localDataFailure(error))
        }
    }

    // MARK: - Private Helpers

    private func makeMessage(
        conversationID: String,
        senderID: String,
        content: String,
        mediaURL: URL? = nil
    ) -> Message {
        Message(
            id: dependencies.idGenerator(),
            conversationId: conversationID,
            senderId: senderID,
            content: content,
            mediaURL: mediaURL,
            timestamp: dependencies.clock(),
            status: .sending
        )
    }

    private func send(
        message: Message,
        conversationID: String,
        skipLocalInsert: Bool = false
    ) async -> Result<Message, MessageServiceError> {
        do {
            if !skipLocalInsert {
                try insertLocalMessage(message)
            }

            do {
                try await dependencies.messageRepository.createMessage(message)
                try await dependencies.conversationRepository.updateLastMessage(
                    conversationID: conversationID,
                    message: message,
                    lastMessageTime: message.timestamp
                )
                try await markMessageSynced(message)
                return .success(message)
            } catch {
                try markMessageFailed(message)
                return .failure(.remoteFailure(error))
            }
        } catch {
            return .failure(.localDataFailure(error))
        }
    }

    private func insertLocalMessage(_ message: Message) throws {
        let localMessage = LocalMessage(
            id: message.id,
            conversationID: message.conversationId,
            senderID: message.senderId,
            content: message.content,
            mediaURL: message.mediaURL,
            timestamp: message.timestamp,
            status: .sending,
            readBy: [:],
            aiCategory: nil,
            sentiment: nil,
            priority: nil,
            collaborationScore: nil,
            metadata: [:],
            syncStatus: .pending,
            syncDirection: .upload,
            syncAttemptCount: 0,
            lastSyncedAt: nil
        )

        try dependencies.localDataManager.addMessage(localMessage, toConversationID: message.conversationId)
    }

    private func markMessageSynced(_ message: Message) async throws {
        try dependencies.localDataManager.updateMessageStatus(messageID: message.id, status: .sent)
        try dependencies.localDataManager.updateMessageSyncStatus(
            messageID: message.id,
            status: .synced,
            direction: .upload,
            syncedAt: dependencies.clock()
        )
    }

    private func markMessageFailed(_ message: Message) throws {
        try dependencies.localDataManager.updateMessageStatus(messageID: message.id, status: .failed)
        try dependencies.localDataManager.updateMessageSyncStatus(
            messageID: message.id,
            status: .failed,
            direction: .upload,
            syncedAt: dependencies.clock()
        )
    }
}

