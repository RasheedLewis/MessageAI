import FirebaseFirestore
import Foundation

public protocol MessageRepositoryProtocol {
    func createMessage(_ message: Message) async throws
    func updateMessageStatus(
        conversationID: String,
        messageID: String,
        status: MessageStatus
    ) async throws
    func updateMessageReadBy(
        conversationID: String,
        messageID: String,
        readBy: [String: Date]
    ) async throws
    func messageDocumentReference(
        conversationID: String,
        messageID: String
    ) -> DocumentReference
}

public final class MessageRepository: MessageRepositoryProtocol {
    private enum Field {
        static let conversations = "conversations"
        static let messages = "messages"
        static let status = "status"
        static let readBy = "readBy"
        static let timestamp = "timestamp"
    }

    private let db: Firestore

    public init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    public func createMessage(_ message: Message) async throws {
        let reference = messageDocumentReference(
            conversationID: message.conversationId,
            messageID: message.id
        )

        var data = message.firestoreData()
        data["createdAt"] = Timestamp(date: message.timestamp)
        try await reference.setData(data)
    }

    public func updateMessageStatus(
        conversationID: String,
        messageID: String,
        status: MessageStatus
    ) async throws {
        let reference = messageDocumentReference(conversationID: conversationID, messageID: messageID)
        try await reference.updateData([
            Field.status: status.rawValue
        ])
    }

    public func updateMessageReadBy(
        conversationID: String,
        messageID: String,
        readBy: [String: Date]
    ) async throws {
        let reference = messageDocumentReference(conversationID: conversationID, messageID: messageID)
        let readByData = readBy.reduce(into: [String: Timestamp]()) { partialResult, entry in
            partialResult[entry.key] = Timestamp(date: entry.value)
        }

        try await reference.updateData([
            Field.readBy: readByData
        ])
    }

    public func messageDocumentReference(
        conversationID: String,
        messageID: String
    ) -> DocumentReference {
        db.collection(Field.conversations)
            .document(conversationID)
            .collection(Field.messages)
            .document(messageID)
    }
}

