import Foundation

public enum MessageStatus: String, Codable, CaseIterable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

