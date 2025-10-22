import Combine
import Foundation

final class ServiceResolver: ObservableObject {
    @Published var localDataManager: LocalDataManager
    @Published var messageListenerService: MessageListenerServiceProtocol
    @Published var messageService: MessageServiceProtocol
    @Published var currentUserID: String

    init(
        localDataManager: LocalDataManager,
        listenerService: MessageListenerServiceProtocol,
        messageService: MessageServiceProtocol,
        currentUserID: String
    ) {
        self.localDataManager = localDataManager
        self.messageListenerService = listenerService
        self.messageService = messageService
        self.currentUserID = currentUserID
    }

    static var previewResolver: ServiceResolver {
        let localDataManager = try? LocalDataManager(inMemory: true)
        let resolvedManager = localDataManager ?? (try? LocalDataManager(inMemory: true))
        let listener = resolvedManager.map { MessageListenerService(localDataManager: $0) }
        let messageService = resolvedManager.map {
            MessageService(
                localDataManager: $0,
                conversationRepository: ConversationRepository(),
                messageRepository: MessageRepository()
            )
        }

        return ServiceResolver(
            localDataManager: resolvedManager ?? (try! LocalDataManager(inMemory: true)),
            listenerService: listener ?? MessageListenerService(localDataManager: try! LocalDataManager(inMemory: true)),
            messageService: messageService ?? MessageService(
                localDataManager: try! LocalDataManager(inMemory: true),
                conversationRepository: ConversationRepository(),
                messageRepository: MessageRepository()
            ),
            currentUserID: "demo"
        )
    }
}

