import AuthenticationServices
import Combine
import FirebaseAuth
import GoogleSignIn
import XCTest
@testable import MessageAI

final class AuthenticationServiceTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []
    private var authProvider: AuthProviderMock!
    private var firebaseConfigurator: FirebaseConfiguratorMock!
    private var googleSignIn: GoogleSignInMock!
    private var service: AuthenticationService!

    override func setUp() {
        super.setUp()
        authProvider = AuthProviderMock()
        firebaseConfigurator = FirebaseConfiguratorMock()
        googleSignIn = GoogleSignInMock()
        service = AuthenticationService(
            authProvider: authProvider,
            firebaseConfigurator: firebaseConfigurator,
            googleSignIn: googleSignIn
        )
    }

    override func tearDown() {
        cancellables.removeAll()
        service = nil
        googleSignIn = nil
        firebaseConfigurator = nil
        authProvider = nil
        super.tearDown()
    }

    func testInitializationConfiguresFirebaseApp() {
        XCTAssertTrue(firebaseConfigurator.configureCalled)
    }

    func testAuthStatePublisherEmitsInitialUser() {
        let expectation = expectation(description: "Initial auth state emitted")
        authProvider.currentUserStub = AuthenticatedUser(uid: "initial-user")

        service = AuthenticationService(
            authProvider: authProvider,
            firebaseConfigurator: firebaseConfigurator,
            googleSignIn: googleSignIn
        )

        service.authStatePublisher
            .sink { user in
                XCTAssertEqual(user?.uid, "initial-user")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testAuthStatePublisherUpdatesAfterChange() {
        let expectation = expectation(description: "Auth state updates after listener fires")

        service.authStatePublisher
            .dropFirst()
            .sink { user in
                XCTAssertEqual(user?.uid, "updated-user")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        authProvider.triggerAuthChange(uid: "updated-user")

        wait(for: [expectation], timeout: 1.0)
    }

    func testSignOutInvokesProviders() throws {
        try service.signOut()
        XCTAssertTrue(authProvider.didSignOut)
        XCTAssertTrue(googleSignIn.didSignOut)
    }

    func testRandomNonceReturnsRequestedLength() {
        let nonce = service.randomNonceString(length: 24)
        XCTAssertEqual(nonce.count, 24)
        XCTAssertTrue(nonce.allSatisfy { $0.isASCII })
    }

    func testMakeAppleIDRequestGeneratesNonce() {
        let request = service.makeAppleIDRequest()
        XCTAssertNotNil(request.nonce)
        XCTAssertFalse(request.nonce?.isEmpty ?? true)
    }
}

// MARK: - Test Doubles

private final class FirebaseConfiguratorMock: FirebaseAppConfiguring {
    private(set) var configureCalled = false

    func configureIfNeeded() {
        configureCalled = true
    }
}

private final class GoogleSignInMock: GoogleSignInHandling {
    var configuration: GIDConfiguration?
    private(set) var didSignOut = false

    func signIn(withPresenting viewController: UIViewController) async throws -> GIDSignInResult {
        throw NSError(domain: "signIn not implemented", code: -1)
    }

    func signOut() {
        didSignOut = true
    }
}

private final class AuthProviderMock: FirebaseAuthProviding {
    private final class ListenerBox: NSObject {
        let callback: (AuthenticatedUser?) -> Void

        init(callback: @escaping (AuthenticatedUser?) -> Void) {
            self.callback = callback
        }
    }

    private var listeners: [ListenerBox] = []

    var currentUserStub: AuthenticatedUser?
    private(set) var didSignOut = false

    var currentUser: AuthenticatedUser? {
        currentUserStub
    }

    func addStateDidChangeListener(_ listener: @escaping (AuthenticatedUser?) -> Void) -> AuthStateDidChangeListenerHandle {
        let box = ListenerBox(callback: listener)
        listeners.append(box)
        return box
    }

    func removeStateDidChangeListener(_ handle: AuthStateDidChangeListenerHandle) {
        guard let box = handle as? ListenerBox else { return }
        listeners.removeAll { $0 === box }
    }

    func signIn(with credential: AuthCredential) async throws -> AuthenticatedUser {
        let user = AuthenticatedUser(uid: "signed-in" + credential.provider)
        currentUserStub = user
        listeners.forEach { $0.callback(user) }
        return user
    }

    func signOut() throws {
        didSignOut = true
        currentUserStub = nil
        listeners.forEach { $0.callback(nil) }
    }

    func triggerAuthChange(uid: String) {
        let user = AuthenticatedUser(uid: uid)
        currentUserStub = user
        listeners.forEach { $0.callback(user) }
    }
}


