import Combine
import FirebaseFirestore
import Foundation

public protocol ConversationRepositoryProtocol {
    func upsertConversation(_ conversation: Conversation) async throws
    func updateLastMessage(
        conversationID: String,
        message: Message,
        lastMessageTime: Date
    ) async throws

    func incrementUnreadCount(
        conversationID: String,
        userID: String,
        by amount: Int
    ) async throws

    func resetUnreadCount(
        conversationID: String,
        userID: String
    ) async throws

    func conversationDocumentReference(_ conversationID: String) -> DocumentReference
}

public final class ConversationRepository: ConversationRepositoryProtocol {
    private enum Field {
        static let conversations = "conversations"
        static let lastMessage = "lastMessage"
        static let lastMessageTime = "lastMessageTime"
        static let updatedAt = "updatedAt"
        static let unreadCount = "unreadCount"
    }

    private let db: Firestore

    public init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    public func upsertConversation(_ conversation: Conversation) async throws {
        let reference = conversationDocumentReference(conversation.id)
        var data = conversation.firestoreData()
        data["updatedAt"] = Timestamp(date: conversation.updatedAt ?? Date())
        try await reference.setData(data, merge: true)
    }

    public func updateLastMessage(
        conversationID: String,
        message: Message,
        lastMessageTime: Date
    ) async throws {
        let reference = conversationDocumentReference(conversationID)
        var lastMessageData = message.firestoreData()
        lastMessageData["id"] = message.id

        let updates: [String: Any] = [
            Field.lastMessage: lastMessageData,
            Field.lastMessageTime: Timestamp(date: lastMessageTime),
            Field.updatedAt: Timestamp(date: Date())
        ]

        try await reference.setData(updates, merge: true)
    }

    public func incrementUnreadCount(
        conversationID: String,
        userID: String,
        by amount: Int
    ) async throws {
        let reference = conversationDocumentReference(conversationID)
        try await reference.updateData([
            "unreadCount.\(userID)": FieldValue.increment(Int64(amount)),
            Field.updatedAt: Timestamp(date: Date())
        ])
    }

    public func resetUnreadCount(
        conversationID: String,
        userID: String
    ) async throws {
        let reference = conversationDocumentReference(conversationID)
        try await reference.updateData([
            "unreadCount.\(userID)": 0,
            Field.updatedAt: Timestamp(date: Date())
        ])
    }

    public func conversationDocumentReference(_ conversationID: String) -> DocumentReference {
        db.collection(Field.conversations).document(conversationID)
    }
}

