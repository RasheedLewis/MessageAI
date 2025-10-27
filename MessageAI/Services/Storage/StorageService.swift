import Foundation
import FirebaseStorage
import UIKit

public protocol ChatMediaUploading {
    func uploadImage(_ image: UIImage, conversationID: String, messageID: String) async throws -> URL
}

public final class StorageService: ChatMediaUploading {
    private enum Constants {
        static let imageCompressionQuality: CGFloat = 0.75
        static let imagesPathPrefix = "message_media"
    }

    private let storage: Storage
    private let uuid: () -> String

    public init(storage: Storage = Storage.storage(), uuid: @escaping () -> String = { UUID().uuidString }) {
        self.storage = storage
        self.uuid = uuid
    }

    public func uploadImage(_ image: UIImage, conversationID: String, messageID: String) async throws -> URL {
        let data = try await compressImage(image)
        let reference = storage.reference(withPath: path(for: conversationID, messageID: messageID))
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await reference.downloadURL()
    }

    private func compressImage(_ image: UIImage) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let targetSize = CGSize(width: 1200, height: 1200)
                let scaled = image.scaledPreservingAspectRatio(targetSize: targetSize)
                guard let data = scaled.jpegData(compressionQuality: Constants.imageCompressionQuality) else {
                    continuation.resume(throwing: StorageServiceError.compressionFailed)
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    private func path(for conversationID: String, messageID: String) -> String {
        "\(Constants.imagesPathPrefix)/\(conversationID)/\(messageID).jpg"
    }
}

public enum StorageServiceError: LocalizedError {
    case compressionFailed

    public var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Unable to prepare image for upload."
        }
    }
}

private extension UIImage {
    func scaledPreservingAspectRatio(targetSize: CGSize) -> UIImage {
        let widthScale = targetSize.width / size.width
        let heightScale = targetSize.height / size.height
        let scaleFactor = min(widthScale, heightScale, 1.0)

        let scaledSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )

        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }
}
