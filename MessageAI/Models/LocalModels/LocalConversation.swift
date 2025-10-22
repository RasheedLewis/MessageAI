import Foundation
import SwiftData

enum LocalConversationType: String, Codable, CaseIterable {
    case oneOnOne
    case group
}

enum LocalMessageCategory: String, Codable, CaseIterable {
    case fan
    case business
    case spam
    case urgent
    case general
}

@Model
final class LocalConversation {
    @Attribute(.unique) var id: String
    var title: String
    var avatarURL: URL?
    var type: LocalConversationType
    var participantIDs: [String]

    var lastMessageTimestamp: Date?
    var lastMessagePreview: String?
    var unreadCounts: [String: Int]
    var aiCategory: LocalMessageCategory?
    var lastSyncedAt: Date?
    var pendingUploadCount: Int
    var pendingDownloadCount: Int
    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: String,
        title: String,
        avatarURL: URL? = nil,
        type: LocalConversationType,
        participantIDs: [String] = [],
        lastMessageTimestamp: Date? = nil,
        lastMessagePreview: String? = nil,
        unreadCounts: [String: Int] = [:],
        aiCategory: LocalMessageCategory? = nil,
        lastSyncedAt: Date? = nil,
        pendingUploadCount: Int = 0,
        pendingDownloadCount: Int = 0,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.avatarURL = avatarURL
        self.type = type
        self.participantIDs = participantIDs
        self.lastMessageTimestamp = lastMessageTimestamp
        self.lastMessagePreview = lastMessagePreview
        self.unreadCounts = unreadCounts
        self.aiCategory = aiCategory
        self.lastSyncedAt = lastSyncedAt
        self.pendingUploadCount = pendingUploadCount
        self.pendingDownloadCount = pendingDownloadCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

