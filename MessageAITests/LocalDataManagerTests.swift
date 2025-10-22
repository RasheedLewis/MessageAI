import XCTest
@testable import MessageAI

@MainActor
final class LocalDataManagerTests: XCTestCase {
    private var manager: LocalDataManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        manager = try LocalDataManager(inMemory: true)
    }

    override func tearDownWithError() throws {
        manager = nil
        try super.tearDownWithError()
    }

    func testUpsertConversationCreatesAndFetches() throws {
        let conversationID = "conversation-1"

        try manager.upsertConversation(
            id: conversationID,
            createDefault: LocalConversation(
                id: conversationID,
                title: "Chat",
                avatarURL: nil,
                type: .oneOnOne
            )
        ) { conversation in
            conversation.title = "Updated Chat"
        }

        let storedConversation = try XCTUnwrap(manager.conversation(withID: conversationID))
        XCTAssertEqual(storedConversation.title, "Updated Chat")
        XCTAssertNotNil(storedConversation.lastSyncedAt)
    }

    func testAddMessageSetsSyncStatusAndUpdatesConversation() throws {
        let conversationID = "conversation-2"
        try manager.upsertConversation(
            id: conversationID,
            createDefault: LocalConversation(
                id: conversationID,
                title: "Messages",
                avatarURL: nil,
                type: .oneOnOne
            )
        ) { _ in }

        let message = LocalMessage(
            id: "message-1",
            conversationID: conversationID,
            senderID: "user-1",
            content: "Hello"
        )

        try manager.addMessage(message, toConversationID: conversationID)

        let storedMessages = try manager.fetchMessages(forConversationID: conversationID)
        XCTAssertEqual(storedMessages.count, 1)

        let storedConversation = try XCTUnwrap(manager.conversation(withID: conversationID))
        XCTAssertEqual(storedConversation.lastMessagePreview, "Hello")
        XCTAssertEqual(storedConversation.pendingUploadCount, 1)

        let storedMessage = try XCTUnwrap(storedMessages.first)
        XCTAssertEqual(storedMessage.syncStatus, .pending)
        XCTAssertEqual(storedMessage.status, .sent)
    }

    func testFetchMessagesRespectsLimitAndFailedFilter() throws {
        let conversationID = "conversation-3"
        try manager.upsertConversation(
            id: conversationID,
            createDefault: LocalConversation(
                id: conversationID,
                title: "History",
                avatarURL: nil,
                type: .oneOnOne
            )
        ) { _ in }

        for index in 0..<5 {
            let message = LocalMessage(
                id: "msg-\(index)",
                conversationID: conversationID,
                senderID: "user-\(index)",
                content: "Message \(index)",
                timestamp: Date().addingTimeInterval(TimeInterval(index))
            )
            try manager.addMessage(message, toConversationID: conversationID)
            if index.isMultiple(of: 2) {
                try manager.updateMessageSyncStatus(
                    messageID: message.id,
                    status: .failed,
                    direction: .upload,
                    syncedAt: nil
                )
            }
        }

        let limitedMessages = try manager.fetchMessages(
            forConversationID: conversationID,
            limit: 3
        )
        XCTAssertEqual(limitedMessages.count, 3)

        let filteredMessages = try manager.fetchMessages(
            forConversationID: conversationID,
            includeFailed: false
        )
        XCTAssertTrue(filteredMessages.allSatisfy { $0.syncStatus != .failed })
    }

    func testUpdateMessageSyncStatusAdjustsCounters() throws {
        let conversationID = "conversation-4"
        try manager.upsertConversation(
            id: conversationID,
            createDefault: LocalConversation(
                id: conversationID,
                title: "Sync",
                avatarURL: nil,
                type: .oneOnOne
            )
        ) { _ in }

        let message = LocalMessage(
            id: "message-sync",
            conversationID: conversationID,
            senderID: "user-sync",
            content: "Sync message"
        )
        try manager.addMessage(message, toConversationID: conversationID)

        try manager.updateMessageSyncStatus(
            messageID: message.id,
            status: .synced,
            direction: .upload,
            syncedAt: Date()
        )

        let storedConversation = try XCTUnwrap(manager.conversation(withID: conversationID))
        XCTAssertEqual(storedConversation.pendingUploadCount, 0)
        XCTAssertNotNil(storedConversation.lastSyncedAt)
    }

    func testDeleteMessageUpdatesConversationSummary() throws {
        let conversationID = "conversation-5"
        try manager.upsertConversation(
            id: conversationID,
            createDefault: LocalConversation(
                id: conversationID,
                title: "Delete",
                avatarURL: nil,
                type: .oneOnOne
            )
        ) { _ in }

        let messageIDs = ["m1", "m2", "m3"]
        for id in messageIDs {
            let message = LocalMessage(
                id: id,
                conversationID: conversationID,
                senderID: "sender-\(id)",
                content: "Content \(id)",
                timestamp: Date().addingTimeInterval(TimeInterval(messageIDs.firstIndex(of: id) ?? 0))
            )
            try manager.addMessage(message, toConversationID: conversationID)
        }

        try manager.deleteMessage(withID: "m3")

        let storedConversation = try XCTUnwrap(manager.conversation(withID: conversationID))
        let remainingMessages = try manager.fetchMessages(forConversationID: conversationID)
        XCTAssertEqual(remainingMessages.count, 2)
        XCTAssertEqual(storedConversation.lastMessagePreview, "Content m2")
    }
}

