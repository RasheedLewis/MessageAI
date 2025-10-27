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
        let aiSentiment: String?
        let aiPriority: Int?
        let participantIDs: [String]
        let avatarURL: URL?
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
    @Published var overrideError: String? = nil

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

    func overrideCategory(for conversationID: String, to category: MessageCategory) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await services.conversationRepository.updateAICategory(
                    conversationID: conversationID,
                    category: category
                )

                if let localCategory = LocalMessageCategory(rawValue: category.rawValue) {
                    try await MainActor.run {
                        try self.localDataManager.updateConversationCategory(
                            conversationID: conversationID,
                            category: localCategory
                        )
                    }
                }

                await MainActor.run {
                    self.applyOverrideLocally(conversationID: conversationID, category: category)
                    self.listenerService.notifyConversationUpdated()
                }
            } catch {
                await MainActor.run {
                    self.overrideError = error.localizedDescription
                }
            }
        }
    }

    func clearOverride(for conversationID: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await services.conversationRepository.updateAICategory(
                    conversationID: conversationID,
                    category: .general
                )

                try await MainActor.run {
                    try self.localDataManager.updateConversationCategory(
                        conversationID: conversationID,
                        category: nil
                    )
                }

                await MainActor.run {
                    self.applyOverrideLocally(conversationID: conversationID, category: .general)
                    self.listenerService.notifyConversationUpdated()
                }
            } catch {
                await MainActor.run {
                    self.overrideError = error.localizedDescription
                }
            }
        }
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
                    aiSentiment: local.aiSentiment,
                    aiPriority: local.aiPriority,
                    participantIDs: local.participantIDs,
                    avatarURL: local.avatarURL
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
        let pendingCount = allConversations.filter {
            $0.aiCategory == nil && $0.lastMessageTime != nil
        }.count
        filterCounts = counts
        uncategorizedCount = pendingCount
    }

    private func applyFilter() {
        conversations = allConversations
            .filter { item in
                guard let selectedFilter else { return true }
                return item.aiCategory == selectedFilter
            }
            .sorted(by: prioritySort)
    }

    @MainActor
    private func applyOverrideLocally(
        conversationID: String,
        category: MessageCategory?
    ) {
        if let index = allConversations.firstIndex(where: { $0.id == conversationID }) {
            let item = allConversations[index]
            let updated = ConversationItem(
                id: item.id,
                title: item.title,
                lastMessagePreview: item.lastMessagePreview,
                lastMessageTime: item.lastMessageTime,
                unreadCount: item.unreadCount,
                isOnline: item.isOnline,
                aiCategory: category,
                aiSentiment: item.aiSentiment,
                aiPriority: item.aiPriority,
                participantIDs: item.participantIDs,
                avatarURL: item.avatarURL
            )
            allConversations[index] = updated
        }

        updateCounts()
        applyFilter()
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

    private func prioritySort(_ lhs: ConversationItem, _ rhs: ConversationItem) -> Bool {
        switch (lhs.aiPriority, rhs.aiPriority) {
        case let (lhsPriority?, rhsPriority?) where lhsPriority != rhsPriority:
            return lhsPriority > rhsPriority
        case let (lhsPriority?, nil):
            return lhsPriority > 0
        case let (nil, rhsPriority?):
            return rhsPriority <= 0
        default:
            break
        }
        return compareConversations(lhs, rhs)
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

