import FirebaseStorage
import Foundation

protocol ProfilePhotoUploading {
    func uploadProfilePhoto(data: Data, for userID: String) async throws -> URL
}

final class ProfilePhotoService: ProfilePhotoUploading {
    static let shared = ProfilePhotoService()

    private let storage: Storage

    init(storage: Storage = Storage.storage()) {
        self.storage = storage
    }

    func uploadProfilePhoto(data: Data, for userID: String) async throws -> URL {
        let path = "profile_photos/\(userID)/avatar.jpg"
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL()
    }
}

