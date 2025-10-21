import Combine
import FirebaseAuth
import FirebaseFirestore

public protocol UserRepositoryType {
    var currentUserPublisher: AnyPublisher<User?, Never> { get }
    func currentUser() -> User?
    func listenToCurrentUser(uid: String)
    func stopListening()
    func createOrUpdateUser(_ user: User) async throws
    func updatePresence(isOnline: Bool) async throws
    func updateLastSeen(date: Date) async throws
    func updateCreatorProfile(_ profile: CreatorProfile) async throws
}

public protocol UsersCollectionProviding {
    func document(_ documentID: String) -> UserDocumentReferenceProviding
}

public protocol UserDocumentReferenceProviding {
    @discardableResult
    func addSnapshotListener(_ listener: @escaping (Result<UserSnapshot, Error>) -> Void) -> ListenerToken
    func setData(_ data: [String: Any], merge: Bool) async throws
}

public protocol ListenerToken {
    func remove()
}

public struct UserSnapshot {
    public let documentID: String
    public let data: [String: Any]?
    public let exists: Bool
}

public protocol AuthSessionProviding {
    var currentUserID: String? { get }
}

public final class UserRepository: UserRepositoryType {
    public static let shared = UserRepository()

    private let usersCollection: UsersCollectionProviding
    private let authSession: AuthSessionProviding
    private let userSubject = CurrentValueSubject<User?, Never>(nil)
    private var userListener: ListenerToken?

    public var currentUserPublisher: AnyPublisher<User?, Never> {
        userSubject.eraseToAnyPublisher()
    }

    public init(
        usersCollection: UsersCollectionProviding = FirestoreUsersCollection(),
        authSession: AuthSessionProviding = Auth.auth()
    ) {
        self.usersCollection = usersCollection
        self.authSession = authSession
    }

    public func currentUser() -> User? {
        userSubject.value
    }

    public func listenToCurrentUser(uid: String) {
        stopListening()
        userListener = usersCollection
            .document(uid)
            .addSnapshotListener { [weak self] result in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    print("[UserRepository] Failed to listen to user: \(error.localizedDescription)")
                case .success(let snapshot):
                    guard snapshot.exists,
                          let data = snapshot.data,
                          let user = User(documentID: snapshot.documentID, data: data) else {
                        self.userSubject.send(nil)
                        return
                    }
                    self.userSubject.send(user)
                }
            }
    }

    public func stopListening() {
        userListener?.remove()
        userListener = nil
    }

    public func createOrUpdateUser(_ user: User) async throws {
        let data = user.firestoreData()
        try await usersCollection
            .document(user.id)
            .setData(data, merge: true)
    }

    public func updatePresence(isOnline: Bool) async throws {
        guard let uid = authSession.currentUserID else {
            throw UserRepositoryError.missingAuthenticatedUser
        }

        let updates: [String: Any] = [
            "isOnline": isOnline,
            "lastSeen": FieldValue.serverTimestamp()
        ]

        try await usersCollection
            .document(uid)
            .setData(updates, merge: true)
    }

    public func updateLastSeen(date: Date = Date()) async throws {
        guard let uid = authSession.currentUserID else {
            throw UserRepositoryError.missingAuthenticatedUser
        }

        try await usersCollection
            .document(uid)
            .setData([
                "lastSeen": Timestamp(date: date)
            ], merge: true)
    }

    public func updateCreatorProfile(_ profile: CreatorProfile) async throws {
        guard let uid = authSession.currentUserID else {
            throw UserRepositoryError.missingAuthenticatedUser
        }

        try await usersCollection
            .document(uid)
            .setData([
                "creatorProfile": profile.firestoreData()
            ], merge: true)
    }
}

// MARK: - Supporting Types

public enum UserRepositoryError: LocalizedError {
    case missingAuthenticatedUser

    public var errorDescription: String? {
        switch self {
        case .missingAuthenticatedUser:
            return "No authenticated user ID is available. Ensure the user is signed in."
        }
    }
}

private enum Collection: String {
    case users = "users"
}

// MARK: - Firebase Backed Implementations

public struct FirestoreUsersCollection: UsersCollectionProviding {
    private let collection: CollectionReference

    public init(firestore: Firestore = Firestore.firestore()) {
        collection = firestore.collection(Collection.users.rawValue)
    }

    public func document(_ documentID: String) -> UserDocumentReferenceProviding {
        FirestoreUserDocumentReference(document: collection.document(documentID))
    }
}

public struct FirestoreUserDocumentReference: UserDocumentReferenceProviding {
    private let document: DocumentReference

    public init(document: DocumentReference) {
        self.document = document
    }

    @discardableResult
    public func addSnapshotListener(_ listener: @escaping (Result<UserSnapshot, Error>) -> Void) -> ListenerToken {
        FirestoreListenerToken(registration: document.addSnapshotListener { snapshot, error in
            if let error {
                listener(.failure(error))
            } else if let snapshot {
                listener(.success(UserSnapshot(
                    documentID: snapshot.documentID,
                    data: snapshot.data(),
                    exists: snapshot.exists
                )))
            }
        })
    }

    public func setData(_ data: [String: Any], merge: Bool) async throws {
        try await document.setData(data, merge: merge)
    }
}

extension Auth: AuthSessionProviding {
    public var currentUserID: String? {
        currentUser?.uid
    }
}

private struct FirestoreListenerToken: ListenerToken {
    private let registration: ListenerRegistration

    init(registration: ListenerRegistration) {
        self.registration = registration
    }

    func remove() {
        registration.remove()
    }
}

