import XCTest
@testable import Grain

final class TranscriptionServiceTests: XCTestCase {
    // TranscriptionService requires an API key at init; we use a dummy key since
    // these tests only exercise parseTranscript and stripTrailingHallucinations
    // without making network calls.
    private let service = TranscriptionService(apiKey: "test-key")

    // MARK: - Hallucination Stripping

    func testStripTrailingOkay() throws {
        let json = try JSONSerialization.data(withJSONObject: ["text": "Hello world okay"])
        let result = try service.parseTranscript(from: json)
        XCTAssertEqual(result, "Hello world")
    }

    func testStripTrailingNo() throws {
        let json = try JSONSerialization.data(withJSONObject: ["text": "This is a test no"])
        let result = try service.parseTranscript(from: json)
        XCTAssertEqual(result, "This is a test")
    }

    func testStripTrailingThankYou() throws {
        let json = try JSONSerialization.data(withJSONObject: ["text": "Great meeting thank you"])
        let result = try service.parseTranscript(from: json)
        XCTAssertEqual(result, "Great meeting")
    }

    func testDoesNotStripMidSentence() throws {
        let json = try JSONSerialization.data(withJSONObject: ["text": "I said no to the proposal"])
        let result = try service.parseTranscript(from: json)
        XCTAssertEqual(result, "I said no to the proposal")
    }

    func testDoesNotStripSubstring() throws {
        // "volcano" ends with "no" but should NOT be stripped
        let json = try JSONSerialization.data(withJSONObject: ["text": "I visited the volcano"])
        let result = try service.parseTranscript(from: json)
        XCTAssertEqual(result, "I visited the volcano")
    }

    func testStripStackedHallucinations() throws {
        let json = try JSONSerialization.data(withJSONObject: ["text": "Hello okay no"])
        let result = try service.parseTranscript(from: json)
        XCTAssertEqual(result, "Hello")
    }

    func testPreservesCleanText() throws {
        let json = try JSONSerialization.data(withJSONObject: ["text": "This is perfectly fine"])
        let result = try service.parseTranscript(from: json)
        XCTAssertEqual(result, "This is perfectly fine")
    }

    func testCaseInsensitive() throws {
        let json = try JSONSerialization.data(withJSONObject: ["text": "Hello world Okay"])
        let result = try service.parseTranscript(from: json)
        XCTAssertEqual(result, "Hello world")
    }
}
