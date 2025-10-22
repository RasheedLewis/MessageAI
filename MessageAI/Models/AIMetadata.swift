import Foundation
import FirebaseFirestore

public struct AIMetadata: Codable, Equatable {
    public var category: MessageCategory?
    public var sentiment: String?
    public var extractedInfo: [String: String]
    public var suggestedResponse: String?
    public var collaborationScore: Double?
    public var priority: Int?

    public init(
        category: MessageCategory? = nil,
        sentiment: String? = nil,
        extractedInfo: [String: String] = [:],
        suggestedResponse: String? = nil,
        collaborationScore: Double? = nil,
        priority: Int? = nil
    ) {
        self.category = category
        self.sentiment = sentiment
        self.extractedInfo = extractedInfo
        self.suggestedResponse = suggestedResponse
        self.collaborationScore = collaborationScore
        self.priority = priority
    }
}

// MARK: - Firestore DTOs

extension AIMetadata {
    public init?(data: [String: Any]) {
        let category: MessageCategory?
        if let rawCategory = data["category"] as? String {
            category = MessageCategory(rawValue: rawCategory)
        } else {
            category = nil
        }

        let sentiment = data["sentiment"] as? String
        var extractedInfo: [String: String] = [:]
        if let info = data["extractedInfo"] as? [String: Any] {
            for (key, value) in info {
                if let stringValue = value as? String {
                    extractedInfo[key] = stringValue
                } else if let numberValue = value as? NSNumber {
                    extractedInfo[key] = numberValue.stringValue
                } else if let boolValue = value as? Bool {
                    extractedInfo[key] = boolValue ? "true" : "false"
                }
            }
        }
        let suggestedResponse = data["suggestedResponse"] as? String
        let collaborationScore = data["collaborationScore"] as? Double

        let priority: Int?
        if let priorityValue = data["priority"] as? Int {
            priority = priorityValue
        } else if let priorityString = data["priority"] as? String, let value = Int(priorityString) {
            priority = value
        } else {
            priority = nil
        }

        self.init(
            category: category,
            sentiment: sentiment,
            extractedInfo: extractedInfo,
            suggestedResponse: suggestedResponse,
            collaborationScore: collaborationScore,
            priority: priority
        )
    }

    public func firestoreData() -> [String: Any] {
        var data: [String: Any] = [:]

        if let category {
            data["category"] = category.rawValue
        }

        if let sentiment {
            data["sentiment"] = sentiment
        }

        if !extractedInfo.isEmpty {
            data["extractedInfo"] = extractedInfo
        }

        if let suggestedResponse {
            data["suggestedResponse"] = suggestedResponse
        }

        if let collaborationScore {
            data["collaborationScore"] = collaborationScore
        }

        if let priority {
            data["priority"] = priority
        }

        return data
    }
}

