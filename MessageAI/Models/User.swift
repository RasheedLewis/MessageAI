import Foundation
import FirebaseFirestore

public struct CreatorProfile: Codable, Equatable {
    public var bio: String
    public var faqTopics: [String]
    public var voiceSamples: [String]
    public var autoResponseEnabled: Bool
    public var businessKeywords: [String]

    public init(
        bio: String = "",
        faqTopics: [String] = [],
        voiceSamples: [String] = [],
        autoResponseEnabled: Bool = false,
        businessKeywords: [String] = []
    ) {
        self.bio = bio
        self.faqTopics = faqTopics
        self.voiceSamples = voiceSamples
        self.autoResponseEnabled = autoResponseEnabled
        self.businessKeywords = businessKeywords
    }
}

public struct User: Identifiable, Codable, Equatable {
    public var id: String
    public var displayName: String
    public var email: String?
    public var photoURL: URL?
    public var isOnline: Bool
    public var lastSeen: Date?
    public var creatorProfile: CreatorProfile?

    public init(
        id: String,
        displayName: String,
        email: String? = nil,
        photoURL: URL? = nil,
        isOnline: Bool = false,
        lastSeen: Date? = nil,
        creatorProfile: CreatorProfile? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.creatorProfile = creatorProfile
    }
}

// MARK: - Firestore DTOs

extension User {
    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case email
        case photoURL
        case isOnline
        case lastSeen
        case creatorProfile
    }

    public init?(documentID: String, data: [String: Any]) {
        guard let displayName = data["displayName"] as? String else {
            return nil
        }

        let email = data["email"] as? String
        let photoURL: URL?
        if let photoURLString = data["photoURL"] as? String {
            photoURL = URL(string: photoURLString)
        } else {
            photoURL = nil
        }

        let isOnline = data["isOnline"] as? Bool ?? false
        let lastSeen: Date?
        if let timestamp = data["lastSeen"] as? Timestamp {
            lastSeen = timestamp.dateValue()
        } else if let seconds = data["lastSeen"] as? TimeInterval {
            lastSeen = Date(timeIntervalSince1970: seconds)
        } else {
            lastSeen = nil
        }

        var creatorProfile: CreatorProfile?
        if let profileData = data["creatorProfile"] as? [String: Any] {
            creatorProfile = CreatorProfile(data: profileData)
        }

        self.init(
            id: documentID,
            displayName: displayName,
            email: email,
            photoURL: photoURL,
            isOnline: isOnline,
            lastSeen: lastSeen,
            creatorProfile: creatorProfile
        )
    }

    public func firestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "displayName": displayName,
            "isOnline": isOnline
        ]

        data["email"] = email
        data["photoURL"] = photoURL?.absoluteString
        data["lastSeen"] = lastSeen?.timeIntervalSince1970
        data["creatorProfile"] = creatorProfile?.firestoreData()
        return data
    }
}

extension CreatorProfile {
    enum CodingKeys: String, CodingKey {
        case bio
        case faqTopics
        case voiceSamples
        case autoResponseEnabled
        case businessKeywords
    }

    init?(data: [String: Any]) {
        guard let bio = data["bio"] as? String else {
            return nil
        }

        let faqTopics = data["faqTopics"] as? [String] ?? []
        let voiceSamples = data["voiceSamples"] as? [String] ?? []
        let autoResponseEnabled = data["autoResponseEnabled"] as? Bool ?? false
        let businessKeywords = data["businessKeywords"] as? [String] ?? []

        self.init(
            bio: bio,
            faqTopics: faqTopics,
            voiceSamples: voiceSamples,
            autoResponseEnabled: autoResponseEnabled,
            businessKeywords: businessKeywords
        )
    }

    func firestoreData() -> [String: Any] {
        [
            "bio": bio,
            "faqTopics": faqTopics,
            "voiceSamples": voiceSamples,
            "autoResponseEnabled": autoResponseEnabled,
            "businessKeywords": businessKeywords
        ]
    }
}

