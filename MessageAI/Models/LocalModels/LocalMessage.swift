import Foundation
import SwiftData

enum LocalMessageStatus: String, Codable, CaseIterable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

@Model
final class LocalMessage {
    @Attribute(.unique) var id: String
    var conversationID: String
    var senderID: String

    var content: String
    var mediaURL: URL?
    var timestamp: Date
    var status: LocalMessageStatus
    var readBy: [String: Date]

    var aiCategory: LocalMessageCategory?
    var sentiment: String?
    var priority: Int?
    var collaborationScore: Double?
    var metadata: [String: String]

    var conversation: LocalConversation?

    var sender: LocalUser?

    init(
        id: String,
        conversationID: String,
        senderID: String,
        content: String,
        mediaURL: URL? = nil,
        timestamp: Date = Date(),
        status: LocalMessageStatus = .sending,
        readBy: [String: Date] = [:],
        aiCategory: LocalMessageCategory? = nil,
        sentiment: String? = nil,
        priority: Int? = nil,
        collaborationScore: Double? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.content = content
        self.mediaURL = mediaURL
        self.timestamp = timestamp
        self.status = status
        self.readBy = readBy
        self.aiCategory = aiCategory
        self.sentiment = sentiment
        self.priority = priority
        self.collaborationScore = collaborationScore
        self.metadata = metadata
    }
}

