import Combine
import FirebaseFirestore
import Foundation

protocol MessageListenerServiceProtocol: AnyObject {
    var conversationUpdatesPublisher: AnyPublisher<Void, Never> { get }
    var messageUpdatesPublisher: AnyPublisher<String, Never> { get }
    func startConversationListener(
        for userID: String,
        onError: ((Error) -> Void)?
    )

    func stopConversationListener()

    func startMessagesListener(
        for conversationID: String,
        currentUserID: String,
        onError: ((Error) -> Void)?
    )

    func stopMessagesListener(for conversationID: String)

    func stopAllMessageListeners()
}

final class MessageListenerService: MessageListenerServiceProtocol {
    private let conversationUpdatesSubject = PassthroughSubject<Void, Never>()
    private let messageUpdatesSubject = PassthroughSubject<String, Never>()

    private enum FirestoreKey {
        static let conversationsCollection = "conversations"
        static let messagesCollection = "messages"
        static let participants = "participants"
        static let lastMessageTime = "lastMessageTime"
        static let timestamp = "timestamp"
    }

    private let db: Firestore
    private let localDataManager: LocalDataManager
    private let clock: () -> Date

    private var conversationListener: ListenerRegistration?
    private var messageListeners: [String: ListenerRegistration] = [:]

    var conversationUpdatesPublisher: AnyPublisher<Void, Never> {
        conversationUpdatesSubject.eraseToAnyPublisher()
    }

    var messageUpdatesPublisher: AnyPublisher<String, Never> {
        messageUpdatesSubject.eraseToAnyPublisher()
    }

    init(
        localDataManager: LocalDataManager,
        db: Firestore = Firestore.firestore(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.localDataManager = localDataManager
        self.db = db
        self.clock = clock
    }

    deinit {
        stopConversationListener()
        stopAllMessageListeners()
    }

    // MARK: - Conversation Listener

    func startConversationListener(
        for userID: String,
        onError: ((Error) -> Void)? = nil
    ) {
        stopConversationListener()

        let query = db.collection(FirestoreKey.conversationsCollection)
            .whereField(FirestoreKey.participants, arrayContains: userID)
            .order(by: FirestoreKey.lastMessageTime, descending: true)

        conversationListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                onError?(error)
                return
            }

            guard let snapshot else {
                return
            }

            snapshot.documentChanges.forEach { change in
                let document = change.document
                let data = document.data()

                guard let conversation = Conversation(documentID: document.documentID, data: data) else {
                    return
                }

                switch change.type {
                case .added, .modified:
                    self.handleConversationUpsert(conversation)
                case .removed:
                    self.handleConversationRemoval(conversationID: conversation.id)
                }
            }
        }
    }

    func stopConversationListener() {
        conversationListener?.remove()
        conversationListener = nil
    }

    // MARK: - Messages Listener

    func startMessagesListener(
        for conversationID: String,
        currentUserID: String,
        onError: ((Error) -> Void)? = nil
    ) {
        stopMessagesListener(for: conversationID)

        let query = db.collection(FirestoreKey.conversationsCollection)
            .document(conversationID)
            .collection(FirestoreKey.messagesCollection)
            .order(by: FirestoreKey.timestamp)

        let registration = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                onError?(error)
                return
            }

            guard let snapshot else {
                return
            }

            snapshot.documentChanges.forEach { change in
                let document = change.document
                let data = document.data()

                guard let message = Message(documentID: document.documentID, data: data) else {
                    return
                }

                switch change.type {
                case .added, .modified:
                    self.handleMessageUpsert(
                        message,
                        conversationID: conversationID,
                        currentUserID: currentUserID
                    )
                case .removed:
                    self.handleMessageRemoval(messageID: message.id, conversationID: conversationID)
                }
            }
        }

        messageListeners[conversationID] = registration
    }

    func stopMessagesListener(for conversationID: String) {
        messageListeners[conversationID]?.remove()
        messageListeners.removeValue(forKey: conversationID)
    }

    func stopAllMessageListeners() {
        messageListeners.values.forEach { $0.remove() }
        messageListeners.removeAll()
    }

    // MARK: - Conversation Handling

    private func handleConversationUpsert(_ conversation: Conversation) {
        do {
            try localDataManager.upsertConversation(
                id: conversation.id,
                createDefault: makeLocalConversation(from: conversation)
            ) { local in
                local.title = conversation.title ?? local.title
                if let mappedType = LocalConversationType(rawValue: conversation.type.rawValue) {
                    local.type = mappedType
                }
                local.participantIDs = conversation.participants
                local.lastMessageTimestamp = conversation.lastMessageTime
                local.lastMessagePreview = makeLastMessagePreview(conversation.lastMessage)
                local.unreadCounts = conversation.unreadCount
                if let aiCategory = conversation.aiCategory,
                   let mapped = LocalMessageCategory(rawValue: aiCategory.rawValue) {
                    local.aiCategory = mapped
                }
                local.lastSyncedAt = clock()
            }
        } catch {
            #if DEBUG
            print("[MessageListenerService] Failed to upsert local conversation: \(error)")
            #endif
        }
        conversationUpdatesSubject.send()
    }

    private func handleConversationRemoval(conversationID: String) {
        do {
            if let conversation = try localDataManager.conversation(withID: conversationID) {
                try localDataManager.deleteConversation(conversation)
            }
        } catch {
            #if DEBUG
            print("[MessageListenerService] Failed to delete local conversation: \(error)")
            #endif
        }
        conversationUpdatesSubject.send()
    }

    private func makeLocalConversation(from conversation: Conversation) -> LocalConversation {
        LocalConversation(
            id: conversation.id,
            title: conversation.title ?? "Conversation",
            avatarURL: conversation.avatarURL,
            type: LocalConversationType(rawValue: conversation.type.rawValue) ?? .oneOnOne,
            participantIDs: conversation.participants,
            lastMessageTimestamp: conversation.lastMessageTime,
            lastMessagePreview: makeLastMessagePreview(conversation.lastMessage),
            unreadCounts: conversation.unreadCount,
            aiCategory: conversation.aiCategory.flatMap { LocalMessageCategory(rawValue: $0.rawValue) },
            lastSyncedAt: clock(),
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt
        )
    }

    private func makeLastMessagePreview(_ message: Message?) -> String? {
        guard let message else { return nil }
        if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message.content
        }
        if message.mediaURL != nil {
            return "Attachment"
        }
        return nil
    }

    // MARK: - Message Handling

    private func handleMessageUpsert(
        _ message: Message,
        conversationID: String,
        currentUserID: String
    ) {
        do {
            try localDataManager.upsertMessage(
                id: message.id,
                createDefault: makeLocalMessage(from: message, currentUserID: currentUserID)
            ) { local in
                updateLocalMessage(local, with: message, currentUserID: currentUserID)
            }
            try localDataManager.updateMessageSyncStatus(
                messageID: message.id,
                status: .synced,
                direction: .download,
                syncedAt: clock()
            )
            try localDataManager.updateMessageStatus(
                messageID: message.id,
                status: LocalMessageStatus(rawValue: message.status.rawValue) ?? .delivered
            )
        } catch {
            #if DEBUG
            print("[MessageListenerService] Failed to upsert local message: \(error)")
            #endif
        }
        conversationUpdatesSubject.send()
        messageUpdatesSubject.send(conversationID)
    }

    private func handleMessageRemoval(messageID: String, conversationID: String) {
        do {
            try localDataManager.deleteMessage(withID: messageID)
        } catch {
            #if DEBUG
            print("[MessageListenerService] Failed to delete local message: \(error)")
            #endif
        }
        conversationUpdatesSubject.send()
        messageUpdatesSubject.send(conversationID)
    }

    private func makeLocalMessage(
        from message: Message,
        currentUserID: String
    ) -> LocalMessage {
        let status = LocalMessageStatus(rawValue: message.status.rawValue) ?? defaultStatus(for: message, currentUserID: currentUserID)

        return LocalMessage(
            id: message.id,
            conversationID: message.conversationId,
            senderID: message.senderId,
            content: message.content,
            mediaURL: message.mediaURL,
            timestamp: message.timestamp,
            status: status,
            readBy: message.readBy,
            aiCategory: message.aiMetadata?.category.flatMap { LocalMessageCategory(rawValue: $0.rawValue) },
            sentiment: message.aiMetadata?.sentiment,
            priority: message.aiMetadata?.priority,
            collaborationScore: message.aiMetadata?.collaborationScore,
            metadata: message.aiMetadata?.extractedInfo ?? [:],
            syncStatus: .synced,
            syncDirection: .download,
            syncAttemptCount: 0,
            lastSyncedAt: clock()
        )
    }

    private func updateLocalMessage(
        _ local: LocalMessage,
        with message: Message,
        currentUserID: String
    ) {
        local.content = message.content
        local.mediaURL = message.mediaURL
        local.timestamp = message.timestamp
        local.status = LocalMessageStatus(rawValue: message.status.rawValue) ?? defaultStatus(for: message, currentUserID: currentUserID)
        local.readBy = message.readBy
        local.aiCategory = message.aiMetadata?.category.flatMap { LocalMessageCategory(rawValue: $0.rawValue) }
        local.sentiment = message.aiMetadata?.sentiment
        local.priority = message.aiMetadata?.priority
        local.collaborationScore = message.aiMetadata?.collaborationScore
        local.metadata = message.aiMetadata?.extractedInfo ?? [:]
        local.syncStatus = .synced
        local.syncDirection = .download
        local.syncAttemptCount = 0
        local.lastSyncedAt = clock()
    }

    private func defaultStatus(for message: Message, currentUserID: String) -> LocalMessageStatus {
        message.senderId == currentUserID ? .sent : .delivered
    }
}

