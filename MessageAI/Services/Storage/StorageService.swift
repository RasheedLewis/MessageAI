import Foundation
import FirebaseStorage
#if canImport(UIKit)
import UIKit
#endif

public protocol ChatMediaUploading {
    #if canImport(UIKit)
    func uploadImage(_ image: UIImage, conversationID: String) async throws -> URL
    #endif
}

public final class StorageService: ChatMediaUploading {
    private enum Constants {
        static let imageCompressionQuality: CGFloat = 0.75
        static let maxDimension: CGFloat = 1200
        static let imagesPathPrefix = "message_media"
    }

    private let storage: Storage
    private let uuid: () -> String

    public init(storage: Storage = Storage.storage(), uuid: @escaping () -> String = { UUID().uuidString }) {
        self.storage = storage
        self.uuid = uuid
    }

    #if canImport(UIKit)
    public func uploadImage(_ image: UIImage, conversationID: String) async throws -> URL {
        let data = try await compressImage(image)
        let reference = storage.reference(withPath: path(for: conversationID))
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await reference.downloadURL()
    }
    #endif

    #if canImport(UIKit)
    private func compressImage(_ image: UIImage) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let scaled = image.scaledPreservingAspectRatio(targetDimension: Constants.maxDimension)
                guard let data = scaled.jpegData(compressionQuality: Constants.imageCompressionQuality) else {
                    continuation.resume(throwing: StorageServiceError.compressionFailed)
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }
    #endif

    private func path(for conversationID: String) -> String {
        "\(Constants.imagesPathPrefix)/\(conversationID)/\(uuid()).jpg"
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

#if canImport(UIKit)
private extension UIImage {
    func scaledPreservingAspectRatio(targetDimension: CGFloat) -> UIImage {
        let maxDimension = max(size.width, size.height)
        guard maxDimension > targetDimension else { return self }

        let scaleFactor = targetDimension / maxDimension
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
#endif
