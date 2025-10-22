import Combine
import Foundation

final class ServiceResolver: ObservableObject {
    @Published var localDataManager: LocalDataManager
    @Published var messageListenerService: MessageListenerServiceProtocol
    @Published var messageService: MessageServiceProtocol
    @Published var conversationRepository: ConversationRepositoryProtocol
    @Published var messageRepository: MessageRepositoryProtocol
    @Published var userSearchService: UserSearchServiceProtocol
    @Published var groupAvatarService: GroupAvatarUploading
    @Published var currentUserID: String

    init(
        localDataManager: LocalDataManager,
        listenerService: MessageListenerServiceProtocol,
        messageService: MessageServiceProtocol,
        conversationRepository: ConversationRepositoryProtocol,
        messageRepository: MessageRepositoryProtocol,
        userSearchService: UserSearchServiceProtocol,
        groupAvatarService: GroupAvatarUploading,
        currentUserID: String
    ) {
        self.localDataManager = localDataManager
        self.messageListenerService = listenerService
        self.messageService = messageService
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
        self.userSearchService = userSearchService
        self.groupAvatarService = groupAvatarService
        self.currentUserID = currentUserID
    }

    static var previewResolver: ServiceResolver {
        let localDataManager = (try? LocalDataManager(inMemory: true)) ?? (try! LocalDataManager(inMemory: true))
        let conversationRepository = ConversationRepository()
        let messageRepository = MessageRepository()
        let listener = MessageListenerService(localDataManager: localDataManager)
        let messageService = MessageService(
            localDataManager: localDataManager,
            conversationRepository: conversationRepository,
            messageRepository: messageRepository
        )

        return ServiceResolver(
            localDataManager: localDataManager,
            listenerService: listener,
            messageService: messageService,
            conversationRepository: conversationRepository,
            messageRepository: messageRepository,
            userSearchService: UserSearchService(),
            groupAvatarService: GroupAvatarService(),
            currentUserID: "demo"
        )
    }
}

