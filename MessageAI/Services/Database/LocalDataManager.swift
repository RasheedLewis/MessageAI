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
    static let shared: LocalDataManager = {
        do {
            return try LocalDataManager()
        } catch {
            fatalError("Failed to initialize LocalDataManager: \(error)")
        }
    }()

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
        let existing = try conversation(withID: id)
        if let conversation = existing {
            updates(conversation)
        } else {
            let conversation = createDefault()
            updates(conversation)
            context.insert(conversation)
        }
        try context.save()
    }

    func conversation(withID id: String) throws -> LocalConversation? {
        let descriptor = FetchDescriptor<LocalConversation>(
            predicate: #Predicate { conversation in
                conversation.id == id
            },
            fetchLimit: 1
        )
        return try context.fetch(descriptor).first
    }

    func fetchConversations(limit: Int? = nil) throws -> [LocalConversation] {
        var descriptor = FetchDescriptor<LocalConversation>(
            sortBy: [
                SortDescriptor(
                    \LocalConversation.lastMessageTimestamp,
                    order: .reverse
                ),
                SortDescriptor(\LocalConversation.title)
            ]
        )

        if let limit {
            descriptor.fetchLimit = limit
        }

        return try context.fetch(descriptor)
    }

    func deleteConversation(_ conversation: LocalConversation) throws {
        if let existing = try conversation(withID: conversation.id) {
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
            conversation.messages.append(message)
            message.conversation = conversation
            context.insert(message)
        }

        try context.save()
    }

    func upsertMessage(
        id: String,
        createDefault: @autoclosure () -> LocalMessage,
        updates: (LocalMessage) -> Void
    ) throws {
        let descriptor = FetchDescriptor<LocalMessage>(
            predicate: #Predicate { $0.id == id },
            fetchLimit: 1
        )

        if let existing = try context.fetch(descriptor).first {
            updates(existing)
        } else {
            let message = createDefault()
            updates(message)
            context.insert(message)
        }

        try context.save()
    }

    func fetchMessages(
        forConversationID conversationID: String,
        limit: Int? = nil
    ) throws -> [LocalMessage] {
        var descriptor = FetchDescriptor<LocalMessage>(
            predicate: #Predicate { message in
                message.conversationID == conversationID
            },
            sortBy: [
                SortDescriptor(\LocalMessage.timestamp)
            ]
        )

        if let limit {
            descriptor.fetchLimit = limit
        }

        return try context.fetch(descriptor)
    }

    func message(withID id: String) throws -> LocalMessage {
        let descriptor = FetchDescriptor<LocalMessage>(
            predicate: #Predicate { $0.id == id },
            fetchLimit: 1
        )

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
        try context.save()
    }

    func deleteMessage(withID id: String) throws {
        let message = try message(withID: id)
        context.delete(message)
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
}

