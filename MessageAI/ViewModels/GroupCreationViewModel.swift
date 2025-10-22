import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class GroupCreationViewModel: ObservableObject {
    struct SearchResult: Identifiable, Equatable {
        let id: String
        let displayName: String
        let email: String?
        let photoURL: URL?
    }

    @Published var searchQuery: String = "" {
        didSet { searchTask?.cancel(); scheduleSearch() }
    }
    @Published private(set) var searchResults: [SearchResult] = []
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var selectedParticipants: [SearchResult] = []
    @Published var groupName: String = ""
    @Published var groupAvatarImage: UIImage?
    @Published private(set) var isSaving: Bool = false

    private let services: ServiceResolver
    private var searchTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var selectedParticipantIDs: Set<String> = []

    init(services: ServiceResolver) {
        self.services = services
    }

    func toggleSelection(_ result: SearchResult) {
        if selectedParticipantIDs.contains(result.id) {
            selectedParticipantIDs.remove(result.id)
            selectedParticipants.removeAll { $0.id == result.id }
        } else {
            selectedParticipantIDs.insert(result.id)
            selectedParticipants.append(result)
        }
    }

    func isSelected(_ result: SearchResult) -> Bool {
        selectedParticipantIDs.contains(result.id)
    }

    func removeParticipant(withID id: String) {
        guard selectedParticipantIDs.contains(id) else { return }
        selectedParticipantIDs.remove(id)
        selectedParticipants.removeAll { $0.id == id }
    }

    func searchUsersImmediately() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.executeSearch()
        }
    }

    func presentError(_ message: String) {
        errorMessage = message
    }

    func clearError() {
        errorMessage = nil
    }

    @discardableResult
    func createGroupConversation() async -> String? {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Group needs a name."
            return nil
        }

        guard selectedParticipants.count >= 2 else {
            errorMessage = "Add at least two people so the group isn’t empty."
            return nil
        }

        isSaving = true
        errorMessage = nil

        do {
            let conversationID = UUID().uuidString
            var avatarURL: URL?

            if let image = groupAvatarImage,
               let data = image.jpegData(compressionQuality: 0.7) {
                avatarURL = try await services.groupAvatarService.uploadGroupAvatar(
                    data: data,
                    conversationID: conversationID
                )
            }

            var participants = selectedParticipants.map { $0.id }
            participants.append(services.currentUserID)

            let conversation = Conversation(
                id: conversationID,
                participants: participants,
                type: .group,
                title: trimmedName,
                avatarURL: avatarURL,
                lastMessage: nil,
                lastMessageTime: nil,
                unreadCount: [:],
                aiCategory: nil,
                createdAt: Date(),
                updatedAt: Date()
            )

            try await services.conversationRepository.upsertConversation(conversation)
            try services.localDataManager.upsertConversation(
                LocalConversation(
                    id: conversation.id,
                    title: trimmedName,
                    avatarURL: avatarURL,
                    type: .group,
                    participantIDs: participants,
                    lastMessageTimestamp: nil,
                    lastMessagePreview: nil,
                    unreadCounts: [:],
                    aiCategory: nil,
                    lastSyncedAt: Date(),
                    createdAt: Date(),
                    updatedAt: Date()
                )
            )

            resetState()
            isSaving = false
            return conversation.id
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
        return nil
    }

    func resetState() {
        groupName = ""
        groupAvatarImage = nil
        selectedParticipants.removeAll()
        selectedParticipantIDs.removeAll()
        searchResults = []
        searchQuery = ""
    }

    private func scheduleSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.executeSearch()
        }
    }

    private func executeSearch() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            await MainActor.run { [weak self] in
                self?.searchResults = []
            }
            return
        }

        isSearching = true
        do {
            let excluding = selectedParticipantIDs.union([services.currentUserID])
            let users = try await services.userSearchService.searchUsers(
                matching: query,
                excludingUserIDs: excluding,
                limit: 25
            )

            await MainActor.run { [weak self] in
                self?.searchResults = users.map { user in
                    SearchResult(
                        id: user.id,
                        displayName: user.displayName,
                        email: user.email,
                        photoURL: user.photoURL
                    )
                }
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.errorMessage = error.localizedDescription
            }
        }

        isSearching = false
    }
}


