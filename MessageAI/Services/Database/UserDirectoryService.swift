import FirebaseFirestore
import Foundation

protocol UserDirectoryServiceProtocol {
    func fetchUsers(withIDs ids: [String]) async throws -> [User]
}

final class UserDirectoryService: UserDirectoryServiceProtocol {
    private enum Collection: String {
        case users
    }

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func fetchUsers(withIDs ids: [String]) async throws -> [User] {
        let unique = Array(Set(ids))
        guard !unique.isEmpty else { return [] }

        var results: [User] = []
        for chunk in chunked(unique, size: 10) {
            let snapshot = try await db
                .collection(Collection.users.rawValue)
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            let users = snapshot.documents.compactMap { document in
                User(documentID: document.documentID, data: document.data())
            }
            results.append(contentsOf: users)
        }

        return results
    }

    private func chunked<T>(_ array: [T], size: Int) -> [[T]] {
        guard size > 0 else { return [array] }
        var chunks: [[T]] = []
        var index = 0
        while index < array.count {
            let end = Swift.min(index + size, array.count)
            chunks.append(Array(array[index..<end]))
            index = end
        }
        return chunks
    }
}


