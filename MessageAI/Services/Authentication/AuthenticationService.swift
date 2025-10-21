import AuthenticationServices
import Combine
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Security
import UIKit

/// A lightweight representation of the authenticated Firebase user that the app can persist and observe.
public struct AuthenticatedUser: Equatable {
    public let uid: String
    public let email: String?
    public let displayName: String?
    public let photoURL: URL?

    init(firebaseUser: FirebaseAuth.User) {
        uid = firebaseUser.uid
        email = firebaseUser.email
        displayName = firebaseUser.displayName
        photoURL = firebaseUser.photoURL
    }

    public init(
        uid: String,
        email: String? = nil,
        displayName: String? = nil,
        photoURL: URL? = nil
    ) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
    }
}

/// Errors that can be surfaced by the authentication service.
public enum AuthenticationError: LocalizedError {
    case missingClientID
    case missingIDToken
    case missingNonce
    case invalidCredential
    case underlying(Error)

    public var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Unable to locate a Firebase client ID. Ensure FirebaseApp.configure() has run."
        case .missingIDToken:
            return "Missing identity token from the authentication provider."
        case .missingNonce:
            return "Missing nonce when attempting to sign in with Apple."
        case .invalidCredential:
            return "The returned credential was invalid."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

/// Handles Firebase authentication flows and exposes auth state updates via Combine.
public protocol FirebaseAppConfiguring {
    func configureIfNeeded()
}

protocol FirebaseAuthProviding: AnyObject {
    var currentUser: AuthenticatedUser? { get }
    func addStateDidChangeListener(_ listener: @escaping (AuthenticatedUser?) -> Void) -> AuthStateDidChangeListenerHandle
    func removeStateDidChangeListener(_ handle: AuthStateDidChangeListenerHandle)
    func signIn(with credential: AuthCredential) async throws -> AuthenticatedUser
    func signOut() throws
}

protocol GoogleSignInHandling: AnyObject {
    var configuration: GIDConfiguration? { get set }
    func signIn(withPresenting viewController: UIViewController) async throws -> GIDSignInResult
    func signOut()
}

public final class AuthenticationService: NSObject {
    public static let shared = AuthenticationService()

    private let authProvider: FirebaseAuthProviding
    private let firebaseConfigurator: FirebaseAppConfiguring
    private let googleSignIn: GoogleSignInHandling
    private var authStateDidChangeHandle: AuthStateDidChangeListenerHandle?
    private let authStateSubject: CurrentValueSubject<AuthenticatedUser?, Never>
    private var currentNonce: String?

    public var currentUser: AuthenticatedUser? {
        authStateSubject.value
    }

    public var authStatePublisher: AnyPublisher<AuthenticatedUser?, Never> {
        authStateSubject.eraseToAnyPublisher()
    }

    public override convenience init() {
        self.init(
            authProvider: FirebaseAuthWrapper(),
            firebaseConfigurator: FirebaseAppConfiguration(),
            googleSignIn: GoogleSignInWrapper.shared,
            initialUser: nil
        )
    }

    init(
        authProvider: FirebaseAuthProviding,
        firebaseConfigurator: FirebaseAppConfiguring,
        googleSignIn: GoogleSignInHandling,
        initialUser: AuthenticatedUser? = nil
    ) {
        self.authProvider = authProvider
        self.firebaseConfigurator = firebaseConfigurator
        self.googleSignIn = googleSignIn
        firebaseConfigurator.configureIfNeeded()
        let startingUser = initialUser ?? authProvider.currentUser
        authStateSubject = CurrentValueSubject(startingUser)
        super.init()
        authStateDidChangeHandle = authProvider.addStateDidChangeListener { [weak self] user in
            guard let self else { return }
            self.authStateSubject.send(user)
        }
    }

    deinit {
        if let handle = authStateDidChangeHandle {
            authProvider.removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Google Sign-In

    @MainActor
    public func signInWithGoogle(presenting viewController: UIViewController) async throws -> AuthenticatedUser {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthenticationError.missingClientID
        }

        let configuration = GIDConfiguration(clientID: clientID)
        googleSignIn.configuration = configuration

        do {
            let result = try await googleSignIn.signIn(withPresenting: viewController)
            guard let idTokenString = result.user.idToken?.tokenString else {
                throw AuthenticationError.missingIDToken
            }

            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idTokenString, accessToken: accessToken)
            return try await signIn(with: credential)
        } catch let error as AuthenticationError {
            throw error
        } catch {
            throw AuthenticationError.underlying(error)
        }
    }

    // MARK: - Apple Sign-In

    /// Creates a configured Apple ID request that includes the required nonce for Firebase authentication.
    public func makeAppleIDRequest() -> ASAuthorizationAppleIDRequest {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
        return request
    }

    /// Handles the result from `ASAuthorizationController` and signs the user into Firebase.
    public func signInWithApple(authorization: ASAuthorization) async throws -> AuthenticatedUser {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthenticationError.invalidCredential
        }

        guard let nonce = currentNonce else {
            throw AuthenticationError.missingNonce
        }

        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthenticationError.missingIDToken
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        do {
            let user = try await signIn(with: firebaseCredential)
            currentNonce = nil
            return user
        } catch {
            throw AuthenticationError.underlying(error)
        }
    }

    // MARK: - Session Management

    public func signOut() throws {
        do {
            try authProvider.signOut()
            googleSignIn.signOut()
        } catch {
            throw AuthenticationError.underlying(error)
        }
    }

    // MARK: - Private Helpers

    private func signIn(with credential: AuthCredential) async throws -> AuthenticatedUser {
        do {
            let authenticatedUser = try await authProvider.signIn(with: credential)
            authStateSubject.send(authenticatedUser)
            return authenticatedUser
        } catch {
            throw AuthenticationError.underlying(error)
        }
    }

    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with status \(status)")
            }

            if random >= charset.count {
                continue
            }

            result.append(charset[Int(random)])
            remainingLength -= 1
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Dependency Implementations

struct FirebaseAppConfiguration: FirebaseAppConfiguring {
    func configureIfNeeded() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
}

final class FirebaseAuthWrapper: FirebaseAuthProviding {
    private let auth: Auth

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    var currentUser: AuthenticatedUser? {
        auth.currentUser.map(AuthenticatedUser.init)
    }

    func addStateDidChangeListener(_ listener: @escaping (AuthenticatedUser?) -> Void) -> AuthStateDidChangeListenerHandle {
        auth.addStateDidChangeListener { _, user in
            listener(user.map(AuthenticatedUser.init))
        }
    }

    func removeStateDidChangeListener(_ handle: AuthStateDidChangeListenerHandle) {
        auth.removeStateDidChangeListener(handle)
    }

    func signIn(with credential: AuthCredential) async throws -> AuthenticatedUser {
        let result = try await auth.signIn(with: credential)
        return AuthenticatedUser(firebaseUser: result.user)
    }

    func signOut() throws {
        try auth.signOut()
    }
}

final class GoogleSignInWrapper: GoogleSignInHandling {
    static let shared = GoogleSignInWrapper()
    private init() {}

    private var instance: GIDSignIn { GIDSignIn.sharedInstance }

    var configuration: GIDConfiguration? {
        get { instance.configuration }
        set { instance.configuration = newValue }
    }

    func signIn(withPresenting viewController: UIViewController) async throws -> GIDSignInResult {
        try await instance.signIn(withPresenting: viewController)
    }

    func signOut() {
        instance.signOut()
    }
}

