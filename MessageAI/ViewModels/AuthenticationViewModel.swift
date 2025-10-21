import AuthenticationServices
import Combine
import SwiftUI
import UIKit

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

    init(
        authService: AuthenticationService = .shared,
        userRepository: UserRepositoryType = UserRepository.shared
    ) {
        self.authService = authService
        self.userRepository = userRepository

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
        } catch {
            state = .idle
            self.error = error.localizedDescription
        }
    }

    func signInWithApple(authorization: ASAuthorization) async {
        state = .loading
        do {
            _ = try await authService.signInWithApple(authorization: authorization)
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

        var updatedUser = User(
            id: user.uid,
            displayName: displayName.isEmpty ? (user.displayName ?? "") : displayName,
            email: user.email,
            photoURL: photoURL
        )

        do {
            try await userRepository.createOrUpdateUser(updatedUser)
            state = .authenticated
        } catch {
            state = .needsProfileSetup
            self.error = error.localizedDescription
        }
    }
}

