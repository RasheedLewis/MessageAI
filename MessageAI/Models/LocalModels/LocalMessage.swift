import Foundation
import SwiftData

enum LocalMessageStatus: String, Codable, CaseIterable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

enum LocalSyncStatus: String, Codable, CaseIterable {
    case pending
    case syncing
    case synced
    case failed
}

enum LocalSyncDirection: String, Codable, CaseIterable {
    case upload
    case download
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
    var aiFeedback: [AISuggestionFeedback]?
    var syncStatus: LocalSyncStatus
    var syncDirection: LocalSyncDirection
    var syncAttemptCount: Int
    var lastSyncedAt: Date?
    var senderDisplayName: String?

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
        metadata: [String: String] = [:],
        aiFeedback: [AISuggestionFeedback]? = nil,
        syncStatus: LocalSyncStatus = .pending,
        syncDirection: LocalSyncDirection = .upload,
        syncAttemptCount: Int = 0,
        lastSyncedAt: Date? = nil,
        senderDisplayName: String? = nil
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
        self.aiFeedback = aiFeedback
        self.syncStatus = syncStatus
        self.syncDirection = syncDirection
        self.syncAttemptCount = syncAttemptCount
        self.lastSyncedAt = lastSyncedAt
        self.senderDisplayName = senderDisplayName
    }
}

