import AuthenticationServices
import Combine
import SwiftUI
import UIKit
import FirebaseMessaging

@MainActor
final class AuthenticationViewModel: ObservableObject {
    private static let defaultCreatorProfile = CreatorProfile()

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
    @Published var persona: String = AuthenticationViewModel.defaultCreatorProfile.persona
    @Published var defaultTone: String = AuthenticationViewModel.defaultCreatorProfile.defaultTone
    @Published var preferredFormat: String = AuthenticationViewModel.defaultCreatorProfile.preferredFormat
    @Published var includeSignature: Bool = AuthenticationViewModel.defaultCreatorProfile.includeSignature
    @Published var signature: String = AuthenticationViewModel.defaultCreatorProfile.signature
    @Published var voiceSamples: [String] = Array(repeating: "", count: 3)
    @Published var styleGuidelines: [String] = [""]

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

                    if let profile = user.creatorProfile {
                        persona = profile.persona
                        defaultTone = profile.defaultTone
                        preferredFormat = profile.preferredFormat
                        includeSignature = profile.includeSignature
                        signature = profile.signature

                        let sanitizedSamples = profile.voiceSamples
                        voiceSamples = sanitizedSamples.isEmpty ? Array(repeating: "", count: 3) : sanitizedSamples

                        let sanitizedGuidelines = profile.styleGuidelines
                        styleGuidelines = sanitizedGuidelines.isEmpty ? [""] : sanitizedGuidelines
                    } else {
                        resetCreatorVoiceDefaults()
                    }
                } else if authService.currentUser != nil {
                    state = .needsProfileSetup
                    resetCreatorVoiceDefaults()
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

            let existingProfile = userRepository.currentUser()?.creatorProfile
            let trimmedPersona = persona.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSignature = signature.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitizedVoiceSamples = voiceSamples
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let sanitizedGuidelines = styleGuidelines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let resolvedPersona = trimmedPersona.isEmpty ? AuthenticationViewModel.defaultCreatorProfile.persona : trimmedPersona
            let resolvedTone = defaultTone.isEmpty ? AuthenticationViewModel.defaultCreatorProfile.defaultTone : defaultTone
            let resolvedFormat = preferredFormat.isEmpty ? AuthenticationViewModel.defaultCreatorProfile.preferredFormat : preferredFormat
            let shouldIncludeSignature = includeSignature && !trimmedSignature.isEmpty

            let updatedCreatorProfile = CreatorProfile(
                bio: existingProfile?.bio ?? "",
                faqTopics: existingProfile?.faqTopics ?? [],
                voiceSamples: sanitizedVoiceSamples,
                persona: resolvedPersona,
                defaultTone: resolvedTone,
                styleGuidelines: sanitizedGuidelines,
                signature: trimmedSignature,
                includeSignature: shouldIncludeSignature,
                preferredFormat: resolvedFormat,
                autoResponseEnabled: existingProfile?.autoResponseEnabled ?? false,
                businessKeywords: existingProfile?.businessKeywords ?? []
            )

            updatedUser.creatorProfile = updatedCreatorProfile

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

    func addVoiceSampleField() {
        voiceSamples.append("")
    }

    func removeVoiceSample(at index: Int) {
        guard voiceSamples.indices.contains(index) else { return }
        voiceSamples.remove(at: index)
        if voiceSamples.isEmpty {
            voiceSamples.append("")
        }
    }

    func addStyleGuidelineField() {
        styleGuidelines.append("")
    }

    func removeStyleGuideline(at index: Int) {
        guard styleGuidelines.indices.contains(index) else { return }
        styleGuidelines.remove(at: index)
        if styleGuidelines.isEmpty {
            styleGuidelines.append("")
        }
    }

    private func resetCreatorVoiceDefaults() {
        persona = AuthenticationViewModel.defaultCreatorProfile.persona
        defaultTone = AuthenticationViewModel.defaultCreatorProfile.defaultTone
        preferredFormat = AuthenticationViewModel.defaultCreatorProfile.preferredFormat
        includeSignature = AuthenticationViewModel.defaultCreatorProfile.includeSignature
        signature = AuthenticationViewModel.defaultCreatorProfile.signature
        voiceSamples = Array(repeating: "", count: 3)
        styleGuidelines = [""]
    }
}

