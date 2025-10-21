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

    @Relationship(deleteRule: .cascade, inverse: \LocalMessage.conversation)
    var messages: [LocalMessage] = []

    @Relationship(deleteRule: .nullify, inverse: \LocalUser.conversations)
    var participants: [LocalUser] = []

    init(
        id: String,
        title: String,
        type: LocalConversationType,
        lastMessageTimestamp: Date? = nil,
        lastMessagePreview: String? = nil,
        unreadCounts: [String: Int] = [:],
        aiCategory: LocalMessageCategory? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.lastMessageTimestamp = lastMessageTimestamp
        self.lastMessagePreview = lastMessagePreview
        self.unreadCounts = unreadCounts
        self.aiCategory = aiCategory
    }
}

