import FirebaseFirestore
import Foundation

public protocol UserSearchServiceProtocol {
    func searchUsers(
        matching query: String,
        excludingUserIDs: Set<String>,
        limit: Int
    ) async throws -> [User]
}

public final class UserSearchService: UserSearchServiceProtocol {
    private enum Collection: String {
        case users
    }

    private let db: Firestore

    public init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    public func searchUsers(
        matching query: String,
        excludingUserIDs: Set<String>,
        limit: Int = 25
    ) async throws -> [User] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        let collection = db.collection(Collection.users.rawValue)
        let lowercaseQuery = trimmedQuery.lowercased()

        // Prioritize exact email matches when an email-like query is entered.
        var documents: [QueryDocumentSnapshot] = []
        if trimmedQuery.contains("@") {
            let exactEmailSnapshot = try await collection
                .whereField("email", isEqualTo: lowercaseQuery)
                .limit(to: limit)
                .getDocuments()
            documents = exactEmailSnapshot.documents
        }

        if documents.isEmpty {
            // Fallback to prefix search by display name via range query if the indexed field is available.
            do {
                let endRange = lowercaseQuery + "\u{f8ff}"
                let displayNameQuery = collection
                    .order(by: "displayName_lowercase")
                    .start(at: [lowercaseQuery])
                    .end(at: [endRange])
                    .limit(to: limit)

                let snapshot = try await displayNameQuery.getDocuments()
                documents = snapshot.documents
            } catch {
                documents = []
            }
        }

        var users = documents.compactMap { document in
            User(documentID: document.documentID, data: document.data())
        }

        if users.isEmpty {
            let snapshot = try await collection
                .order(by: "displayName")
                .limit(to: max(limit * 2, 25))
                .getDocuments()
            users = snapshot.documents.compactMap { User(documentID: $0.documentID, data: $0.data()) }
                .filter { user in
                    user.displayName.lowercased().contains(lowercaseQuery) ||
                    (user.email?.lowercased().contains(lowercaseQuery) ?? false)
                }
        }

        if !excludingUserIDs.isEmpty {
            users.removeAll { excludingUserIDs.contains($0.id) }
        }

        if users.count > limit {
            users = Array(users.prefix(limit))
        }

        return users
    }
}


