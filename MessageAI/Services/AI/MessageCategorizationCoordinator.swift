import Combine
import Foundation

protocol MessageCategorizationCoordinating: AnyObject {
    func start()
    func stop()
}

final class MessageCategorizationCoordinator: MessageCategorizationCoordinating {
    struct PendingMessage: Equatable {
        let id: String
        let conversationID: String
        let senderID: String
        let content: String
        let timestamp: Date
    }

    private let aiService: AIServiceProtocol
    private let localDataManager: LocalDataManager
    private let messageRepository: MessageRepositoryProtocol
    private let conversationRepository: ConversationRepositoryProtocol
    private let listenerService: MessageListenerServiceProtocol
    private let currentUserID: String

    private var cancellables: Set<AnyCancellable> = []
    private let workQueue = DispatchQueue(label: "com.messageai.categorization", qos: .utility)
    private var pendingConversationQueue: [String] = []
    private var pendingConversationSet: Set<String> = []
    private var isProcessing = false
    private var isStarted = false

    init(
        aiService: AIServiceProtocol,
        localDataManager: LocalDataManager,
        messageRepository: MessageRepositoryProtocol,
        conversationRepository: ConversationRepositoryProtocol,
        listenerService: MessageListenerServiceProtocol,
        currentUserID: String
    ) {
        self.aiService = aiService
        self.localDataManager = localDataManager
        self.messageRepository = messageRepository
        self.conversationRepository = conversationRepository
        self.listenerService = listenerService
        self.currentUserID = currentUserID
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        listenerService.messageUpdatesPublisher
            .sink { [weak self] conversationID in
                self?.enqueue(conversationID: conversationID)
            }
            .store(in: &cancellables)

        listenerService.conversationEventPublisher
            .map { $0.id }
            .sink { [weak self] conversationID in
                self?.enqueue(conversationID: conversationID)
            }
            .store(in: &cancellables)

        Task { [weak self] in
            guard let self else { return }
            let conversationIDs = await self.fetchAllConversationIDs()
            guard !conversationIDs.isEmpty else { return }
            conversationIDs.forEach { self.enqueue(conversationID: $0) }
        }
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        workQueue.async { [weak self] in
            self?.pendingConversationQueue.removeAll()
            self?.pendingConversationSet.removeAll()
            self?.isProcessing = false
        }
    }

    private func enqueue(conversationID: String) {
        workQueue.async { [weak self] in
            guard let self else { return }
            guard !pendingConversationSet.contains(conversationID) else { return }
            pendingConversationSet.insert(conversationID)
            pendingConversationQueue.append(conversationID)
            if !isProcessing {
                processNextOnQueue()
            }
        }
    }

    private func processNextOnQueue() {
        guard isStarted else { return }
        guard !isProcessing else { return }
        guard !pendingConversationQueue.isEmpty else { return }

        let conversationID = pendingConversationQueue.removeFirst()
        pendingConversationSet.remove(conversationID)
        isProcessing = true

        Task { [weak self] in
            guard let self else { return }
            await self.processConversation(conversationID)
            self.workQueue.async { [weak self] in
                guard let self else { return }
                self.isProcessing = false
                self.processNextOnQueue()
            }
        }
    }

    private func fetchAllConversationIDs() async -> [String] {
        await MainActor.run {
            (try? localDataManager.fetchConversations().map { $0.id }) ?? []
        }
    }

    private func pendingMessages(for conversationID: String) async -> [PendingMessage] {
        await MainActor.run {
            guard let messages = try? localDataManager.fetchMessages(forConversationID: conversationID) else {
                return []
            }

            return messages.compactMap { localMessage in
                guard localMessage.senderID != currentUserID else { return nil }
                guard localMessage.aiCategory == nil else { return nil }
                let trimmed = localMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return PendingMessage(
                    id: localMessage.id,
                    conversationID: localMessage.conversationID,
                    senderID: localMessage.senderID,
                    content: trimmed,
                    timestamp: localMessage.timestamp
                )
            }
        }
    }

    private func processConversation(_ conversationID: String) async {
        let messages = await pendingMessages(for: conversationID)
        guard !messages.isEmpty else { return }

        for message in messages {
            do {
                let analysis = try await analyze(message: message)
                guard let category = MessageCategory(rawValue: analysis.category) else {
                    continue
                }

                let metadata = AIMetadata(
                    category: category,
                    sentiment: analysis.sentiment,
                    extractedInfo: makeExtractedInfo(from: analysis),
                    suggestedResponse: nil,
                    collaborationScore: analysis.collaborationScore,
                    priority: analysis.priority
                )

                try await messageRepository.updateAIMetadata(
                    conversationID: message.conversationID,
                    messageID: message.id,
                    metadata: metadata
                )

                try await conversationRepository.updateAICategory(
                    conversationID: message.conversationID,
                    category: category
                )

                let localCategory = LocalMessageCategory(rawValue: category.rawValue)

                try await MainActor.run {
                    try localDataManager.updateMessageAIData(
                        messageID: message.id,
                        category: localCategory,
                        sentiment: analysis.sentiment,
                        priority: analysis.priority,
                        collaborationScore: analysis.collaborationScore,
                        metadata: makeExtractedInfo(from: analysis)
                    )

                    try localDataManager.updateConversationCategory(
                        conversationID: message.conversationID,
                        category: localCategory
                    )

                    listenerService.notifyMessageUpdated(conversationID: message.conversationID)
                    listenerService.notifyConversationUpdated()
                }
            } catch {
                #if DEBUG
                print("[Categorization] Failed to process message \(message.id): \(error.localizedDescription)")
                #endif
                continue
            }
        }
    }

    private func analyze(message: PendingMessage) async throws -> AIMessageAnalysis {
        let request = AIMessageAnalysisRequest(
            message: message.content,
            senderProfile: nil,
            creatorContext: nil
        )

        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = aiService
                .analyzeMessage(request)
                .sink { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                } receiveValue: { analysis in
                    continuation.resume(returning: analysis)
                    cancellable?.cancel()
                }
        }
    }

    private func makeExtractedInfo(from analysis: AIMessageAnalysis) -> [String: String] {
        var info: [String: String] = [:]
        if !analysis.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            info["summary"] = analysis.summary
        }
        if !analysis.extractedInfo.keyFacts.isEmpty {
            info["keyFacts"] = analysis.extractedInfo.keyFacts.joined(separator: "\n")
        }
        if !analysis.extractedInfo.requestedActions.isEmpty {
            info["requestedActions"] = analysis.extractedInfo.requestedActions.joined(separator: "\n")
        }
        if !analysis.extractedInfo.mentionedBrands.isEmpty {
            info["mentionedBrands"] = analysis.extractedInfo.mentionedBrands.joined(separator: "\n")
        }
        return info
    }
}

#if DEBUG
extension MessageCategorizationCoordinator {
    static var mock: MessageCategorizationCoordinating {
        class MockCoordinator: MessageCategorizationCoordinating {
            func start() {}
            func stop() {}
        }
        return MockCoordinator()
    }
}
#endif

