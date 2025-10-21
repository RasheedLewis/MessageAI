import Combine
import XCTest
@testable import MessageAI

final class UserRepositoryTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []
    private var usersCollection: UsersCollectionMock!
    private var authSession: AuthSessionMock!
    private var repository: UserRepository!

    override func setUp() {
        super.setUp()
        usersCollection = UsersCollectionMock()
        authSession = AuthSessionMock()
        repository = UserRepository(usersCollection: usersCollection, authSession: authSession)
    }

    override func tearDown() {
        cancellables.removeAll()
        repository.stopListening()
        repository = nil
        authSession = nil
        usersCollection = nil
        super.tearDown()
    }

    func testCreateOrUpdateUserPersistsData() async throws {
        let user = User(
            id: "user-123",
            displayName: "Creator",
            email: "creator@example.com",
            photoURL: URL(string: "https://example.com/avatar.png"),
            isOnline: true,
            creatorProfile: CreatorProfile(bio: "Bio")
        )

        try await repository.createOrUpdateUser(user)

        let data = usersCollection.documentMocks[user.id]?.setDataPayload
        XCTAssertEqual(data?["displayName"] as? String, "Creator")
        XCTAssertEqual(data?["email"] as? String, "creator@example.com")
        XCTAssertEqual(data?["isOnline"] as? Bool, true)
    }

    func testUpdatePresenceRequiresAuthenticatedUser() async throws {
        authSession.currentUserID = "user-123"

        try await repository.updatePresence(isOnline: true)

        let payload = usersCollection.documentMocks["user-123"]?.setDataPayload
        XCTAssertEqual(payload?["isOnline"] as? Bool, true)
        XCTAssertNotNil(payload?["lastSeen"])
    }

    func testUpdatePresenceWithoutAuthenticationThrows() async {
        authSession.currentUserID = nil

        do {
            try await repository.updatePresence(isOnline: true)
            XCTFail("Expected missingAuthenticatedUser error")
        } catch let error as UserRepositoryError {
            XCTAssertEqual(error, .missingAuthenticatedUser)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUpdateCreatorProfilePersistsData() async throws {
        authSession.currentUserID = "user-456"
        let profile = CreatorProfile(
            bio: "Bio",
            faqTopics: ["topic"],
            voiceSamples: ["sample"],
            autoResponseEnabled: true,
            businessKeywords: ["brand"]
        )

        try await repository.updateCreatorProfile(profile)

        let data = usersCollection.documentMocks["user-456"]?.setDataPayload?["creatorProfile"] as? [String: Any]
        XCTAssertEqual(data?["bio"] as? String, "Bio")
        XCTAssertEqual(data?["autoResponseEnabled"] as? Bool, true)
    }

    func testCurrentUserPublisherEmitsUpdatesFromSnapshot() {
        let expectation = expectation(description: "Publisher emits second value")

        var received: [User?] = []
        repository.currentUserPublisher
            .sink { value in
                received.append(value)
                if received.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        repository.listenToCurrentUser(uid: "user-789")
        let document = usersCollection.documentMocks["user-789"]!
        document.simulateSnapshot(
            UserSnapshot(
                documentID: "user-789",
                data: [
                    "displayName": "Creator",
                    "isOnline": true
                ],
                exists: true
            )
        )

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(received.last??.displayName, "Creator")
        XCTAssertEqual(received.last??.id, "user-789")
    }
}

// MARK: - Test Doubles

private final class UsersCollectionMock: UsersCollectionProviding {
    var documentMocks: [String: UserDocumentReferenceMock] = [:]

    func document(_ documentID: String) -> UserDocumentReferenceProviding {
        if let mock = documentMocks[documentID] {
            return mock
        }
        let mock = UserDocumentReferenceMock(documentID: documentID)
        documentMocks[documentID] = mock
        return mock
    }
}

private final class UserDocumentReferenceMock: UserDocumentReferenceProviding {
    private let documentID: String
    private var listeners: [UUID: (Result<UserSnapshot, Error>) -> Void] = [:]
    var setDataPayload: [String: Any]?

    init(documentID: String) {
        self.documentID = documentID
    }

    @discardableResult
    func addSnapshotListener(_ listener: @escaping (Result<UserSnapshot, Error>) -> Void) -> ListenerToken {
        let token = UUID()
        listeners[token] = listener
        return ListenerRegistrationMock(token: token) { [weak self] token in
            self?.listeners.removeValue(forKey: token)
        }
    }

    func setData(_ data: [String: Any], merge: Bool) async throws {
        setDataPayload = data
    }

    // Helpers
    func simulateSnapshot(_ snapshot: UserSnapshot) {
        listeners.values.forEach { $0(.success(snapshot)) }
    }

    func simulateError(_ error: Error) {
        listeners.values.forEach { $0(.failure(error)) }
    }
}

private final class ListenerRegistrationMock: ListenerToken {
    private let token: UUID
    private let cancellationHandler: (UUID) -> Void

    init(token: UUID, cancel: @escaping (UUID) -> Void) {
        self.token = token
        cancellationHandler = cancel
    }

    func remove() {
        cancellationHandler(token)
    }
}

private final class AuthSessionMock: AuthSessionProviding {
    var currentUserID: String?
}

