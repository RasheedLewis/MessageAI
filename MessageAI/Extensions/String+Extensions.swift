import Foundation

extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Array where Element == String {
    func sanitizedStrings() -> [String]? {
        let sanitized = compactMap { $0.nonEmpty }
        return sanitized.isEmpty ? nil : sanitized
    }
}
