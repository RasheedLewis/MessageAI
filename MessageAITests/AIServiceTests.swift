import XCTest
import Combine
@testable import MessageAI

final class AIServiceTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testAnalyzeMessageCachesResults() {
        let request = AIMessageAnalysisRequest(
            message: "Test",
            senderProfile: nil,
            creatorContext: nil
        )

        let response = AIMessageAnalysis(
            category: "business",
            sentiment: "positive",
            priority: 3,
            collaborationScore: 0.5,
            summary: "Summary",
            extractedInfo: .init(
                keyFacts: [],
                requestedActions: [],
                mentionedBrands: []
            )
        )

        let service = AIServiceMock()
        service.analyzeResult = .success(response)

        let expectation = XCTestExpectation(description: "Analyzes message")
        service.analyzeMessage(request)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Unexpected failure: \(error)")
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, response)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testGenerateResponsePropagatesError() {
        let service = AIServiceMock()
        service.responseResult = .failure(AIServiceError.emptyResponse)

        let request = AIResponseGenerationRequest(
            message: "Hi",
            conversationHistory: [],
            creatorProfile: .init(
                displayName: nil,
                persona: nil,
                defaultTone: nil,
                styleGuidelines: nil,
                voiceSamples: nil,
                signature: nil,
                includeSignature: nil,
                preferredFormat: nil
            ),
            responsePreferences: .init(
                tone: nil,
                format: nil,
                includeSignature: nil,
                notes: nil
            )
        )

        let expectation = XCTestExpectation(description: "Fails to generate response")
        service.generateResponse(request)
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    expectation.fulfill()
                }
            }, receiveValue: { _ in
                XCTFail("Expected error")
            })
            .store(in: &self.cancellables)

        wait(for: [expectation], timeout: 1.0)
    }
}

