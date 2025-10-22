import Foundation
import SwiftData

@Model
final class LocalUser {
    @Attribute(.unique) var id: String
    var displayName: String
    var email: String?
    var photoURL: URL?
    var isOnline: Bool
    var lastSeen: Date?
    var isCurrentUser: Bool
    var lastSyncedAt: Date?

    init(
        id: String,
        displayName: String,
        email: String? = nil,
        photoURL: URL? = nil,
        isOnline: Bool = false,
        lastSeen: Date? = nil,
        isCurrentUser: Bool = false,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.isCurrentUser = isCurrentUser
        self.lastSyncedAt = lastSyncedAt
    }
}

