import Foundation

public enum MessageCategory: String, Codable, CaseIterable {
    case fan
    case business
    case spam
    case urgent
    case general
}

