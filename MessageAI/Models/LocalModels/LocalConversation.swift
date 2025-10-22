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
    var type: LocalConversationType

    var lastMessageTimestamp: Date?
    var lastMessagePreview: String?
    var unreadCounts: [String: Int]
    var aiCategory: LocalMessageCategory?
    var lastSyncedAt: Date?
    var pendingUploadCount: Int
    var pendingDownloadCount: Int

    init(
        id: String,
        title: String,
        type: LocalConversationType,
        lastMessageTimestamp: Date? = nil,
        lastMessagePreview: String? = nil,
        unreadCounts: [String: Int] = [:],
        aiCategory: LocalMessageCategory? = nil,
        lastSyncedAt: Date? = nil,
        pendingUploadCount: Int = 0,
        pendingDownloadCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.lastMessageTimestamp = lastMessageTimestamp
        self.lastMessagePreview = lastMessagePreview
        self.unreadCounts = unreadCounts
        self.aiCategory = aiCategory
        self.lastSyncedAt = lastSyncedAt
        self.pendingUploadCount = pendingUploadCount
        self.pendingDownloadCount = pendingDownloadCount
    }
}

