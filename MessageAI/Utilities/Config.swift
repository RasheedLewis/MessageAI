import Foundation

enum Config {
    /// Base URL for backend services. Override via Info.plist or build settings.
    static var apiBaseURL: URL? {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String else {
            return nil
        }
        return URL(string: urlString)
    }
}


