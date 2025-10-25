import Combine
import Foundation

final class ServiceResolver: ObservableObject {
    @Published var localDataManager: LocalDataManager
    @Published var messageService: MessageServiceProtocol
    @Published var conversationRepository: ConversationRepositoryProtocol
    @Published var messageRepository: MessageRepositoryProtocol
    @Published var messageListenerService: MessageListenerServiceProtocol
    @Published var userSearchService: UserSearchServiceProtocol
    @Published var userDirectoryService: UserDirectoryServiceProtocol
    @Published var groupAvatarService: GroupAvatarUploading
    @Published var aiService: AIServiceProtocol
    @Published var categorizationCoordinator: MessageCategorizationCoordinating
    @Published var currentUserID: String

    init(
        localDataManager: LocalDataManager,
        listenerService: MessageListenerServiceProtocol,
        messageService: MessageServiceProtocol,
        conversationRepository: ConversationRepositoryProtocol,
        messageRepository: MessageRepositoryProtocol,
        userSearchService: UserSearchServiceProtocol,
        userDirectoryService: UserDirectoryServiceProtocol,
        groupAvatarService: GroupAvatarUploading,
        aiService: AIServiceProtocol,
        categorizationCoordinator: MessageCategorizationCoordinating,
        currentUserID: String
    ) {
        self.localDataManager = localDataManager
        self.messageListenerService = listenerService
        self.messageService = messageService
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
        self.userSearchService = userSearchService
        self.userDirectoryService = userDirectoryService
        self.groupAvatarService = groupAvatarService
        self.aiService = aiService
        self.categorizationCoordinator = categorizationCoordinator
        self.currentUserID = currentUserID
    }

    static var previewResolver: ServiceResolver {
        let localDataManager = (try? LocalDataManager(inMemory: true)) ?? (try! LocalDataManager(inMemory: true))
        let conversationRepository = ConversationRepository()
        let messageRepository = MessageRepository()
        let listener = MessageListenerService(localDataManager: localDataManager)
        let userDirectoryService = UserDirectoryService()
        let messageService = MessageService(
            localDataManager: localDataManager,
            conversationRepository: conversationRepository,
            messageRepository: messageRepository,
            userDirectoryService: userDirectoryService
        )

        return ServiceResolver(
            localDataManager: localDataManager,
            listenerService: listener,
            messageService: messageService,
            conversationRepository: conversationRepository,
            messageRepository: messageRepository,
            userSearchService: UserSearchService(),
            userDirectoryService: userDirectoryService,
            groupAvatarService: GroupAvatarService(),
            aiService: AIServiceMock(),
            categorizationCoordinator: MessageCategorizationCoordinator.mock,
            currentUserID: "demo"
        )
    }
}

