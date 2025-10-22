import FirebaseStorage
import Foundation

public protocol GroupAvatarUploading {
    func uploadGroupAvatar(data: Data, conversationID: String) async throws -> URL
}

public final class GroupAvatarService: GroupAvatarUploading {
    private let storage: Storage

    public init(storage: Storage = Storage.storage()) {
        self.storage = storage
    }

    public func uploadGroupAvatar(data: Data, conversationID: String) async throws -> URL {
        let reference = storage.reference(withPath: path(for: conversationID))
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await reference.downloadURL()
    }

    private func path(for conversationID: String) -> String {
        "group_avatars/\(conversationID)/thumbnail.jpg"
    }
}



