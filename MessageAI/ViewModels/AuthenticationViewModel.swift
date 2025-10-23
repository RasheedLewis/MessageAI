import AuthenticationServices
import Combine
import SwiftUI
import UIKit
import FirebaseMessaging

@MainActor
final class AuthenticationViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case loading
        case authenticated
        case needsProfileSetup
    }

    @Published var state: ViewState = .idle
    @Published var error: String?
    @Published var displayName: String = ""
    @Published var photoURL: URL?

    private var cancellables: Set<AnyCancellable> = []
    private let authService: AuthenticationService
    private let userRepository: UserRepositoryType
    private let profilePhotoService: ProfilePhotoUploading

    init(
        authService: AuthenticationService = .shared,
        userRepository: UserRepositoryType = UserRepository.shared,
        profilePhotoService: ProfilePhotoUploading = ProfilePhotoService.shared
    ) {
        self.authService = authService
        self.userRepository = userRepository
        self.profilePhotoService = profilePhotoService

        authService.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self else { return }
                if let user {
                    userRepository.listenToCurrentUser(uid: user.uid)
                } else {
                    userRepository.stopListening()
                    state = .idle
                }
            }
            .store(in: &cancellables)

        userRepository.currentUserPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self else { return }

                if let user {
                    displayName = user.displayName
                    photoURL = user.photoURL

                    if user.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        state = .needsProfileSetup
                    } else {
                        state = .authenticated
                    }
                } else if authService.currentUser != nil {
                    state = .needsProfileSetup
                }
            }
            .store(in: &cancellables)
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    func signInWithGoogle(presenting controller: UIViewController) async {
        state = .loading
        do {
            _ = try await authService.signInWithGoogle(presenting: controller)
            try await syncFCMToken()
        } catch {
            state = .idle
            self.error = error.localizedDescription
        }
    }

    func signInWithApple(authorization: ASAuthorization) async {
        state = .loading
        do {
            _ = try await authService.signInWithApple(authorization: authorization)
            try await syncFCMToken()
        } catch {
            state = .idle
            self.error = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try authService.signOut()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func completeProfileSetup(selectedImageData: Data?) async {
        guard let user = authService.currentUser else {
            error = "No authenticated user found."
            return
        }

        state = .loading

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        var updatedUser = User(
            id: user.uid,
            displayName: trimmedName.isEmpty ? (user.displayName ?? "") : trimmedName,
            email: user.email,
            photoURL: photoURL
        )

        do {
            if let imageData = selectedImageData {
                let uploadedURL = try await profilePhotoService.uploadProfilePhoto(data: imageData, for: user.uid)
                updatedUser.photoURL = uploadedURL
            }

            try await userRepository.createOrUpdateUser(updatedUser)
            state = .authenticated
        } catch {
            state = .needsProfileSetup
            self.error = error.localizedDescription
        }
    }

    private func syncFCMToken() async throws {
        guard let token = Messaging.messaging().fcmToken else { return }
        try await userRepository.updateFCMToken(token)
    }
}

