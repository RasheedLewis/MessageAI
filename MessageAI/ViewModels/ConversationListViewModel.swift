import Combine
import Foundation

@MainActor
final class ConversationListViewModel: ObservableObject {
    struct ConversationItem: Identifiable, Equatable {
        let id: String
        let title: String
        let lastMessagePreview: String?
        let lastMessageTime: Date?
        let unreadCount: Int
        let isOnline: Bool
        let aiCategory: MessageCategory?
        let participantIDs: [String]
    }

    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)

        static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loaded, .loaded):
                return true
            case let (.failed(lhsError), .failed(rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }

    @Published private(set) var conversations: [ConversationItem] = []
    @Published private(set) var loadingState: LoadingState = .idle
    @Published var selectedFilter: MessageCategory? = nil {
        didSet { applyFilter() }
    }
    @Published private(set) var filterCounts: [MessageCategory?: Int] = [:]
    @Published private(set) var uncategorizedCount: Int = 0

    private var localDataManager: LocalDataManager { services.localDataManager }
    private var listenerService: MessageListenerServiceProtocol { services.messageListenerService }
    private var currentUserID: String { services.currentUserID }

    let services: ServiceResolver
    private var cancellables: Set<AnyCancellable> = []

    init(services: ServiceResolver) {
        self.services = services
        setupBindings()
    }

    private var allConversations: [ConversationItem] = []

    func onAppear() {
        guard loadingState == .idle else { return }
        loadingState = .loading
        fetchLocalConversations()
        listenerService.startConversationListener(for: currentUserID) { [weak self] error in
            Task { @MainActor in
                self?.loadingState = .failed(error.localizedDescription)
            }
        }
    }

    func onDisappear() {
        listenerService.stopConversationListener()
        listenerService.stopAllMessageListeners()
    }

    func refresh() {
        fetchLocalConversations()
    }

    private func setupBindings() {
        listenerService.conversationUpdatesPublisher
            .sink { [weak self] in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    private func fetchLocalConversations() {
        do {
            let localConversations = try localDataManager.fetchConversations()
            let items = localConversations.map { local -> ConversationItem in
                let unreadCount = local.unreadCounts[currentUserID] ?? 0
                let preview = normalizedPreview(for: local)
                return ConversationItem(
                    id: local.id,
                    title: local.title,
                    lastMessagePreview: preview,
                    lastMessageTime: local.lastMessageTimestamp,
                    unreadCount: unreadCount,
                    isOnline: false,
                    aiCategory: local.aiCategory.flatMap { MessageCategory(rawValue: $0.rawValue) },
                    participantIDs: local.participantIDs
                )
            }
            self.allConversations = items.sorted(by: compareConversations)
            updateCounts()
            applyFilter()
            loadingState = .loaded
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    private func updateCounts() {
        var counts: [MessageCategory?: Int] = [:]
        counts[nil] = allConversations.count
        for category in MessageCategory.allCases {
            counts[category] = allConversations.filter { $0.aiCategory == category }.count
        }
        let pendingCount = allConversations.filter { $0.aiCategory == nil }.count
        filterCounts = counts
        uncategorizedCount = pendingCount
    }

    private func applyFilter() {
        if let selectedFilter {
            conversations = allConversations.filter { $0.aiCategory == selectedFilter }
        } else {
            conversations = allConversations
        }
    }

    private func compareConversations(_ lhs: ConversationItem, _ rhs: ConversationItem) -> Bool {
        switch (lhs.lastMessageTime, rhs.lastMessageTime) {
        case let (lhs?, rhs?):
            if lhs != rhs { return lhs > rhs }
        case (let lhs?, nil):
            return true
        case (nil, let rhs?):
            return false
        case (nil, nil):
            break
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func normalizedPreview(for conversation: LocalConversation) -> String? {
        if let preview = conversation.lastMessagePreview,
           !preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return preview
        }

        guard let lastMessage = try? localDataManager
            .fetchMessages(forConversationID: conversation.id, limit: 1)
            .last else {
            return nil
        }

        let trimmedContent = lastMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContent.isEmpty {
            return trimmedContent
        }

        if lastMessage.mediaURL != nil {
            return "Attachment"
        }

        return nil
    }

}

