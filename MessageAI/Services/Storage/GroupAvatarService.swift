import FirebaseStorage
import Foundation

public protocol GroupAvatarUploading {
    func uploadStagedAvatar(
        data: Data,
        userID: String,
        progress: ((Double) -> Void)?
    ) async throws -> URL

    func promoteStagedAvatar(
        stagedURL: URL,
        conversationID: String
    ) async throws -> URL
}

public final class GroupAvatarService: GroupAvatarUploading {
    private let storage: Storage

    public init(storage: Storage = Storage.storage()) {
        self.storage = storage
    }

    public func uploadStagedAvatar(
        data: Data,
        userID: String,
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let reference = storage.reference(withPath: stagedPath(for: userID))
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        if let progress {
            return try await uploadWithProgress(reference: reference, data: data, metadata: metadata, progress: progress)
        } else {
            _ = try await reference.putDataAsync(data, metadata: metadata)
            return try await reference.downloadURL()
        }
    }

    public func promoteStagedAvatar(
        stagedURL: URL,
        conversationID: String
    ) async throws -> URL {
        let stagedRef = storage.reference(forURL: stagedURL.absoluteString)
        let data = try await stagedRef.data(maxSize: 5 * 1024 * 1024)
        let finalRef = storage.reference(withPath: finalPath(for: conversationID))
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await finalRef.putDataAsync(data, metadata: metadata)
        return try await finalRef.downloadURL()
    }

    private func uploadWithProgress(
        reference: StorageReference,
        data: Data,
        metadata: StorageMetadata,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            var task: StorageUploadTask?
            var finished = false

            func finish(_ result: Result<URL, Error>) {
                guard !finished else { return }
                finished = true
                task?.removeAllObservers()
                continuation.resume(with: result)
            }

            task = reference.putData(data, metadata: metadata) { _, error in
                if let error {
                    finish(.failure(error))
                    return
                }

                reference.downloadURL { url, error in
                    if let error {
                        finish(.failure(error))
                    } else if let url {
                        finish(.success(url))
                    } else {
                        finish(.failure(StorageServiceError.unknown))
                    }
                }
            }

            task?.observe(.progress) { snapshot in
                if let fraction = snapshot.progress?.fractionCompleted {
                    progress(max(0, min(1, fraction)))
                }
            }

            task?.observe(.failure) { snapshot in
                let error = snapshot.error ?? StorageServiceError.unknown
                finish(.failure(error))
            }
        }
    }

    private func stagedPath(for userID: String) -> String {
        "group_avatars/staged/\(userID)/avatar.jpg"
    }

    private func finalPath(for conversationID: String) -> String {
        "group_avatars/\(conversationID)/thumbnail.jpg"
    }
}



