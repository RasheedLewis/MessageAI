import Foundation
import SwiftData

enum LocalDataManagerError: Error, CustomStringConvertible {
    case conversationNotFound(String)
    case messageNotFound(String)

    var description: String {
        switch self {
        case let .conversationNotFound(id):
            return "Conversation not found for id: \(id)"
        case let .messageNotFound(id):
            return "Message not found for id: \(id)"
        }
    }
}

@MainActor
final class LocalDataManager {
    let container: ModelContainer
    let context: ModelContext

    init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
    }

    init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(
            for: LocalUser.self,
            LocalConversation.self,
            LocalMessage.self,
            configurations: configuration
        )
        self.container = container
        self.context = container.mainContext
    }

    // MARK: - Conversations

    func upsertConversation(_ conversation: LocalConversation) throws {
        if conversation.modelContext == nil {
            context.insert(conversation)
        }
        try context.save()
    }

    func upsertConversation(
        id: String,
        createDefault: @autoclosure () -> LocalConversation,
        updates: (LocalConversation) -> Void
    ) throws {
        if let conversation = try conversation(withID: id) {
            updates(conversation)
            conversation.lastSyncedAt = Date()
            updateConversationSummary(for: conversation)
        } else {
            let conversation = createDefault()
            updates(conversation)
            conversation.lastSyncedAt = Date()
            conversation.createdAt = conversation.createdAt ?? Date()
            conversation.updatedAt = Date()
            updateConversationSummary(for: conversation)
            context.insert(conversation)
        }
        try context.save()
    }

    func conversation(withID id: String) throws -> LocalConversation? {
        var descriptor = FetchDescriptor<LocalConversation>(
            predicate: #Predicate<LocalConversation> { conversation in
                conversation.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetchConversations(limit: Int? = nil) throws -> [LocalConversation] {
        let descriptor = FetchDescriptor<LocalConversation>()
        let conversations = try context.fetch(descriptor)

        let sorted = conversations.sorted { lhs, rhs in
            let lhsDate = lhs.lastMessageTimestamp ?? .distantPast
            let rhsDate = rhs.lastMessageTimestamp ?? .distantPast

            if lhsDate == rhsDate {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

            return lhsDate > rhsDate
        }

        if let limit {
            return Array(sorted.prefix(limit))
        }

        return sorted
    }

    func deleteConversation(_ conversation: LocalConversation) throws {
        if let existing = try self.conversation(withID: conversation.id) {
            context.delete(existing)
            try context.save()
        }
    }

    // MARK: - Messages

    func addMessage(_ message: LocalMessage, toConversationID conversationID: String) throws {
        guard let conversation = try conversation(withID: conversationID) else {
            throw LocalDataManagerError.conversationNotFound(conversationID)
        }

        if message.modelContext == nil {
            message.conversation = conversation
            context.insert(message)
        }

        message.syncStatus = .pending
        message.syncDirection = .upload
        message.syncAttemptCount = 0
        if message.status == .sending {
            message.status = .sent
        }
        updateConversationSummary(for: conversation)
        try context.save()
    }

    func upsertMessage(
        id: String,
        createDefault: @autoclosure () -> LocalMessage,
        updates: (LocalMessage) -> Void
    ) throws {
        var descriptor = FetchDescriptor<LocalMessage>(
            predicate: #Predicate<LocalMessage> { message in
                message.id == id
            }
        )
        descriptor.fetchLimit = 1

        let target: LocalMessage
        if let existing = try context.fetch(descriptor).first {
            updates(existing)
            target = existing
        } else {
            let message = createDefault()
            updates(message)
            context.insert(message)
            target = message
        }

        if let conversation = target.conversation {
            updateConversationSummary(for: conversation)
        }
        try context.save()
    }

    func fetchMessages(
        forConversationID conversationID: String,
        limit: Int? = nil,
        includeFailed: Bool = true
    ) throws -> [LocalMessage] {
        let predicate = #Predicate<LocalMessage> { message in
            message.conversationID == conversationID
        }

        var descriptor = FetchDescriptor<LocalMessage>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\LocalMessage.timestamp)
            ]
        )

        if let limit {
            descriptor.fetchLimit = limit
        }

        var messages = try context.fetch(descriptor)

        if !includeFailed {
            messages.removeAll { $0.syncStatus == .failed }
        }

        return messages
    }

    func message(withID id: String) throws -> LocalMessage {
        var descriptor = FetchDescriptor<LocalMessage>(
            predicate: #Predicate<LocalMessage> { message in
                message.id == id
            }
        )
        descriptor.fetchLimit = 1

        guard let message = try context.fetch(descriptor).first else {
            throw LocalDataManagerError.messageNotFound(id)
        }

        return message
    }

    func updateMessageStatus(
        messageID: String,
        status: LocalMessageStatus
    ) throws {
        let message = try message(withID: messageID)
        message.status = status
        if let conversation = message.conversation {
            updateConversationSummary(for: conversation)
        }
        try context.save()
    }

    func updateMessageSyncStatus(
        messageID: String,
        status: LocalSyncStatus,
        direction: LocalSyncDirection,
        syncedAt: Date? = Date()
    ) throws {
        let message = try message(withID: messageID)
        message.syncStatus = status
        message.syncDirection = direction
        message.lastSyncedAt = syncedAt
        let effectiveDate = syncedAt ?? Date()

        switch status {
        case .failed:
            message.syncAttemptCount += 1
        case .pending:
            message.syncAttemptCount = 0
        case .syncing:
            break
        case .synced:
            message.syncAttemptCount = 0
        }

        if let conversation = message.conversation {
            switch (direction, status) {
            case (.upload, .pending):
                conversation.pendingUploadCount += 1
            case (.upload, .synced):
                conversation.pendingUploadCount = max(0, conversation.pendingUploadCount - 1)
                conversation.lastSyncedAt = effectiveDate
            case (.upload, .failed):
                conversation.pendingUploadCount = max(0, conversation.pendingUploadCount - 1)
            case (.download, .pending):
                conversation.pendingDownloadCount += 1
            case (.download, .synced):
                conversation.pendingDownloadCount = max(0, conversation.pendingDownloadCount - 1)
                conversation.lastSyncedAt = effectiveDate
            case (.download, .failed):
                conversation.pendingDownloadCount = max(0, conversation.pendingDownloadCount - 1)
            case (.upload, .syncing), (.download, .syncing):
                break
            }
            updateConversationSummary(for: conversation)
        }
        try context.save()
    }

    func deleteMessage(withID id: String) throws {
        let message = try message(withID: id)
        let conversation = message.conversation
        context.delete(message)
        if let conversation {
            updateConversationSummary(for: conversation)
        }
        try context.save()
    }

    // MARK: - Utilities

    func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    func resetStore() throws {
        try container.deleteAllData()
    }

    // MARK: - Helpers

    private func updateConversationSummary(for conversation: LocalConversation) {
        let messages = (try? fetchMessages(forConversationID: conversation.id)) ?? []

        if let latestMessage = messages.last {
            conversation.lastMessageTimestamp = latestMessage.timestamp

            var preview: String?
            if !latestMessage.content.isEmpty {
                preview = latestMessage.content
            } else if latestMessage.mediaURL != nil {
                preview = "Attachment"
            }

            if let displayName = latestMessage.senderDisplayName,
               conversation.type == .group,
               let preview,
               !displayName.isEmpty {
                conversation.lastMessagePreview = "\(displayName): \(preview)"
            } else {
                conversation.lastMessagePreview = preview
            }
        } else {
            conversation.lastMessageTimestamp = nil
            conversation.lastMessagePreview = nil
        }

        conversation.pendingUploadCount = messages.filter { message in
            message.syncDirection == .upload && message.syncStatus != .synced
        }.count

        conversation.pendingDownloadCount = messages.filter { message in
            message.syncDirection == .download && message.syncStatus != .synced
        }.count
    }
}

