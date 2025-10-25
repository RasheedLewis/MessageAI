import Foundation
import Combine
import FirebaseFunctions

enum AIServiceError: Error {
    case emptyResponse
    case decodingFailed
}

struct AIMessageAnalysis: Codable, Equatable {
    let category: String
    let sentiment: String
    let priority: Int
    let collaborationScore: Double
    let summary: String
    let extractedInfo: ExtractedInfo

    struct ExtractedInfo: Codable, Equatable {
        let keyFacts: [String]
        let requestedActions: [String]
        let mentionedBrands: [String]
    }
}

struct AIMessageAnalysisRequest: Codable, Equatable {
    let message: String
    let senderProfile: [String: String]?
    let creatorContext: [String: String]?
}

struct AIResponseGenerationResult: Codable, Equatable {
    let reply: String
    let tone: String
    let format: String
    let reasoning: String
    let followUpQuestions: [String]
    let suggestedNextActions: [String]
}

struct AIResponseGenerationRequest: Codable, Equatable {
    let message: String
    let conversationHistory: [ConversationEntry]
    let creatorProfile: CreatorProfile
    let responsePreferences: ResponsePreferences

    struct ConversationEntry: Codable, Equatable {
        let speaker: String
        let content: String
    }

    struct CreatorProfile: Codable, Equatable {
        let displayName: String?
        let persona: String?
        let defaultTone: String?
        let styleGuidelines: [String]?
        let voiceSamples: [String]?
        let signature: String?
        let includeSignature: Bool?
        let preferredFormat: String?
    }

    struct ResponsePreferences: Codable, Equatable {
        let tone: String?
        let format: String?
        let includeSignature: Bool?
        let notes: String?
    }
}

protocol AIServiceProtocol {
    func analyzeMessage(_ request: AIMessageAnalysisRequest) -> AnyPublisher<AIMessageAnalysis, Error>
    func generateResponse(_ request: AIResponseGenerationRequest) -> AnyPublisher<AIResponseGenerationResult, Error>
}

protocol CallableClient {
    func call(
        function name: String,
        payload: Any,
        completion: @escaping (Result<Any?, Error>) -> Void
    )
}

private final class FirebaseCallableClient: CallableClient {
    private let functions: Functions

    init(functions: Functions = Functions.functions()) {
        self.functions = functions
    }

    func call(
        function name: String,
        payload: Any,
        completion: @escaping (Result<Any?, Error>) -> Void
    ) {
        functions.httpsCallable(name).call(payload) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(result?.data))
        }
    }
}

private final class CacheBox<Value> {
    let value: Value
    init(_ value: Value) { self.value = value }
}

final class AIService: AIServiceProtocol {
    static let shared = AIService()

    private let callableClient: CallableClient
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let analysisCache = NSCache<NSString, CacheBox<AIMessageAnalysis>>()

    init(
        callableClient: CallableClient = FirebaseCallableClient(),
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.callableClient = callableClient
        self.encoder = encoder
        self.decoder = decoder
        encoder.outputFormatting = []
    }

    func analyzeMessage(_ request: AIMessageAnalysisRequest) -> AnyPublisher<AIMessageAnalysis, Error> {
        let cacheKey = cacheKeyForAnalysis(request)
        if let key = cacheKey, let cached = analysisCache.object(forKey: key)?.value {
            return Just(cached)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

        return call(
            function: "analyzeMessage",
            payload: request as AIMessageAnalysisRequest,
            decode: AIMessageAnalysis.self
        )
        .handleEvents(receiveOutput: { [weak self] result in
            guard let key = cacheKey else { return }
            self?.analysisCache.setObject(CacheBox(result), forKey: key)
        })
        .eraseToAnyPublisher()
    }

    func generateResponse(_ request: AIResponseGenerationRequest) -> AnyPublisher<AIResponseGenerationResult, Error> {
        call(
            function: "generateResponse",
            payload: request,
            decode: AIResponseGenerationResult.self
        )
    }

    private func call<T: Encodable, U: Decodable>(
        function name: String,
        payload: T,
        decode type: U.Type
    ) -> AnyPublisher<U, Error> {
        Future<U, Error> { [weak self] promise in
            guard let self = self else { return }

            do {
                let wrappedPayload = try self.wrap(payload)
                self.callableClient.call(function: name, payload: wrappedPayload) { result in
                    switch result {
                    case .failure(let error):
                        promise(.failure(error))
                    case .success(let data):
                        do {
                            let decoded = try self.decode(type, from: data)
                            promise(.success(decoded))
                        } catch {
                            promise(.failure(error))
                        }
                    }
                }
            } catch {
                promise(.failure(error))
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    private func wrap<T: Encodable>(_ payload: T) throws -> Any {
        let data = try encoder.encode(payload)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        return jsonObject
    }

    private func decode<U: Decodable>(_ type: U.Type, from data: Any?) throws -> U {
        guard let data = data else {
            throw AIServiceError.emptyResponse
        }

        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
        do {
            return try decoder.decode(type, from: jsonData)
        } catch {
            throw AIServiceError.decodingFailed
        }
    }

    private func cacheKeyForAnalysis(_ request: AIMessageAnalysisRequest) -> NSString? {
        guard let data = try? encoder.encode(request),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return NSString(string: string)
    }
}

#if DEBUG
final class AIServiceMock: AIServiceProtocol {
    var analyzeResult: Result<AIMessageAnalysis, Error> = .failure(AIServiceError.emptyResponse)
    var responseResult: Result<AIResponseGenerationResult, Error> = .failure(AIServiceError.emptyResponse)

    func analyzeMessage(_ request: AIMessageAnalysisRequest) -> AnyPublisher<AIMessageAnalysis, Error> {
        switch analyzeResult {
        case .success(let value):
            return Just(value).setFailureType(to: Error.self).eraseToAnyPublisher()
        case .failure(let error):
            return Fail(error: error).eraseToAnyPublisher()
        }
    }

    func generateResponse(_ request: AIResponseGenerationRequest) -> AnyPublisher<AIResponseGenerationResult, Error> {
        switch responseResult {
        case .success(let value):
            return Just(value).setFailureType(to: Error.self).eraseToAnyPublisher()
        case .failure(let error):
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
}
#endif

