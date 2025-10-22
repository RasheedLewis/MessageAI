import Foundation
import FirebaseFirestore

public enum ConversationType: String, Codable, CaseIterable {
    case oneOnOne
    case group
}

public struct Conversation: Identifiable, Codable, Equatable {
    public var id: String
    public var participants: [String]
    public var type: ConversationType
    public var title: String?
    public var lastMessage: Message?
    public var lastMessageTime: Date?
    public var unreadCount: [String: Int]
    public var aiCategory: MessageCategory?
    public var createdAt: Date?
    public var updatedAt: Date?

    public init(
        id: String,
        participants: [String],
        type: ConversationType,
        title: String? = nil,
        lastMessage: Message? = nil,
        lastMessageTime: Date? = nil,
        unreadCount: [String: Int] = [:],
        aiCategory: MessageCategory? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.participants = participants
        self.type = type
        self.title = title
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
        self.aiCategory = aiCategory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Firestore DTOs

extension Conversation {
    enum CodingKeys: String, CodingKey {
        case id
        case participants
        case type
        case title
        case lastMessage
        case lastMessageTime
        case unreadCount
        case aiCategory
        case createdAt
        case updatedAt
    }

    public init?(documentID: String, data: [String: Any]) {
        guard let participantIDs = data["participants"] as? [String], !participantIDs.isEmpty else {
            return nil
        }

        guard let rawType = data["type"] as? String, let type = ConversationType(rawValue: rawType) else {
            return nil
        }

        let title = data["title"] as? String

        var lastMessage: Message?
        if let lastMessageData = data["lastMessage"] as? [String: Any] {
            let lastMessageID = lastMessageData["id"] as? String ?? UUID().uuidString
            lastMessage = Message(documentID: lastMessageID, data: lastMessageData)
        }

        let lastMessageTime: Date?
        if let timestamp = data["lastMessageTime"] as? Timestamp {
            lastMessageTime = timestamp.dateValue()
        } else if let seconds = data["lastMessageTime"] as? TimeInterval {
            lastMessageTime = Date(timeIntervalSince1970: seconds)
        } else {
            lastMessageTime = nil
        }

        let unreadCount = data["unreadCount"] as? [String: Int] ?? [:]

        let aiCategory: MessageCategory?
        if let rawCategory = data["aiCategory"] as? String {
            aiCategory = MessageCategory(rawValue: rawCategory)
        } else {
            aiCategory = nil
        }

        let createdAt: Date?
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else if let seconds = data["createdAt"] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: seconds)
        } else {
            createdAt = nil
        }

        let updatedAt: Date?
        if let timestamp = data["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue()
        } else if let seconds = data["updatedAt"] as? TimeInterval {
            updatedAt = Date(timeIntervalSince1970: seconds)
        } else {
            updatedAt = nil
        }

        self.init(
            id: documentID,
            participants: participantIDs,
            type: type,
            title: title,
            lastMessage: lastMessage,
            lastMessageTime: lastMessageTime,
            unreadCount: unreadCount,
            aiCategory: aiCategory,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public func firestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "participants": participants,
            "type": type.rawValue,
            "unreadCount": unreadCount
        ]

        if let title {
            data["title"] = title
        }

        if let lastMessage {
            var lastMessageData = lastMessage.firestoreData()
            lastMessageData["id"] = lastMessage.id
            data["lastMessage"] = lastMessageData
        }

        if let lastMessageTime {
            data["lastMessageTime"] = Timestamp(date: lastMessageTime)
        }

        if let aiCategory {
            data["aiCategory"] = aiCategory.rawValue
        }

        if let createdAt {
            data["createdAt"] = Timestamp(date: createdAt)
        }

        if let updatedAt {
            data["updatedAt"] = Timestamp(date: updatedAt)
        }

        return data
    }
}

