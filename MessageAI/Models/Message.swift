import Foundation
import FirebaseFirestore

public struct Message: Identifiable, Codable, Equatable {
    public var id: String
    public var conversationId: String
    public var senderId: String
    public var content: String
    public var mediaURL: URL?
    public var timestamp: Date
    public var status: MessageStatus
    public var readBy: [String: Date]
    public var aiMetadata: AIMetadata?

    public init(
        id: String,
        conversationId: String,
        senderId: String,
        content: String,
        mediaURL: URL? = nil,
        timestamp: Date = Date(),
        status: MessageStatus = .sending,
        readBy: [String: Date] = [:],
        aiMetadata: AIMetadata? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.content = content
        self.mediaURL = mediaURL
        self.timestamp = timestamp
        self.status = status
        self.readBy = readBy
        self.aiMetadata = aiMetadata
    }
}

// MARK: - Firestore DTOs

extension Message {
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId
        case senderId
        case content
        case mediaURL
        case timestamp
        case status
        case readBy
        case aiMetadata
    }

    public init?(documentID: String, data: [String: Any]) {
        guard let conversationId = data["conversationId"] as? String else {
            return nil
        }

        guard let senderId = data["senderId"] as? String else {
            return nil
        }

        let content = data["content"] as? String ?? ""

        let mediaURL: URL?
        if let mediaURLString = data["mediaURL"] as? String {
            mediaURL = URL(string: mediaURLString)
        } else {
            mediaURL = nil
        }

        let timestamp: Date
        if let firestoreTimestamp = data["timestamp"] as? Timestamp {
            timestamp = firestoreTimestamp.dateValue()
        } else if let seconds = data["timestamp"] as? TimeInterval {
            timestamp = Date(timeIntervalSince1970: seconds)
        } else {
            return nil
        }

        let status: MessageStatus
        if let rawStatus = data["status"] as? String, let messageStatus = MessageStatus(rawValue: rawStatus) {
            status = messageStatus
        } else {
            status = .sent
        }

        var readBy: [String: Date] = [:]
        if let readByData = data["readBy"] as? [String: Any] {
            for (userID, value) in readByData {
                if let timestamp = value as? Timestamp {
                    readBy[userID] = timestamp.dateValue()
                } else if let seconds = value as? TimeInterval {
                    readBy[userID] = Date(timeIntervalSince1970: seconds)
                }
            }
        }

        var aiMetadata: AIMetadata?
        if let aiData = data["aiMetadata"] as? [String: Any] {
            aiMetadata = AIMetadata(data: aiData)
        }

        self.init(
            id: documentID,
            conversationId: conversationId,
            senderId: senderId,
            content: content,
            mediaURL: mediaURL,
            timestamp: timestamp,
            status: status,
            readBy: readBy,
            aiMetadata: aiMetadata
        )
    }

    public func firestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "conversationId": conversationId,
            "senderId": senderId,
            "content": content,
            "timestamp": Timestamp(date: timestamp),
            "status": status.rawValue
        ]

        if let mediaURL {
            data["mediaURL"] = mediaURL.absoluteString
        }

        if !readBy.isEmpty {
            data["readBy"] = readBy.reduce(into: [String: Timestamp]()) { partialResult, entry in
                partialResult[entry.key] = Timestamp(date: entry.value)
            }
        }

        if let aiMetadata {
            data["aiMetadata"] = aiMetadata.firestoreData()
        }

        return data
    }
}

