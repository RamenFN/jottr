import XCTest
@testable import Grain

final class SnippetEngineTests: XCTestCase {

    // Helper to build a basic enabled snippet.
    private func makeSnippet(trigger: String, expansion: String, isEnabled: Bool = true) -> Snippet {
        Snippet(id: UUID(), trigger: trigger, expansion: expansion, isEnabled: isEnabled)
    }

    // SNIP-01: Basic replacement — trigger found in transcript, replaced with expansion.
    func testBasicReplacement() {
        let snippet = makeSnippet(trigger: "my sig", expansion: "john@example.com")
        let result = SnippetEngine.apply([snippet], to: "say my sig please")
        XCTAssertEqual(result, "say john@example.com please")
    }

    // SNIP-02: Trigger "sig" must NOT fire inside "signal" (no substring match).
    func testWordBoundaryNoSubstring() {
        let snippet = makeSnippet(trigger: "sig", expansion: "X")
        let result = SnippetEngine.apply([snippet], to: "the signal is clear")
        XCTAssertEqual(result, "the signal is clear")
    }

    // Trigger fires at the start of the string (string-start counts as boundary).
    func testWordBoundaryAtStart() {
        let snippet = makeSnippet(trigger: "my sig", expansion: "john@example.com")
        let result = SnippetEngine.apply([snippet], to: "my sig is here")
        XCTAssertEqual(result, "john@example.com is here")
    }

    // Trigger fires at the end of the string (string-end counts as boundary).
    func testWordBoundaryAtEnd() {
        let snippet = makeSnippet(trigger: "my sig", expansion: "john@example.com")
        let result = SnippetEngine.apply([snippet], to: "here is my sig")
        XCTAssertEqual(result, "here is john@example.com")
    }

    // Trigger adjacent to punctuation fires correctly.
    func testWordBoundaryPunctuation() {
        let snippet = makeSnippet(trigger: "my sig", expansion: "john@example.com")
        let result = SnippetEngine.apply([snippet], to: "my sig, thanks")
        XCTAssertEqual(result, "john@example.com, thanks")
    }

    // SNIP-03: Case-insensitive — "my sig" matches "My Sig", "MY SIG", "my SIG".
    func testCaseInsensitive() {
        let snippet = makeSnippet(trigger: "my sig", expansion: "X")
        XCTAssertEqual(SnippetEngine.apply([snippet], to: "My Sig here"), "X here")
        XCTAssertEqual(SnippetEngine.apply([snippet], to: "MY SIG here"), "X here")
        XCTAssertEqual(SnippetEngine.apply([snippet], to: "my SIG here"), "X here")
    }

    // Longest-match-first: "my email" beats "my" when both could match at the same position.
    func testLongestMatchFirst() {
        let shortSnippet = makeSnippet(trigger: "my", expansion: "SHORT")
        let longSnippet = makeSnippet(trigger: "my email", expansion: "LONG")
        let result = SnippetEngine.apply([shortSnippet, longSnippet], to: "my email address")
        XCTAssertEqual(result, "LONG address")
    }

    // SNIP-05: 200 snippets processed without crash; correct replacements still applied.
    func testLargeSnippetList() {
        var snippets: [Snippet] = (0..<200).map { i in
            makeSnippet(trigger: "trigger\(i)", expansion: "expansion\(i)")
        }
        // Add 5 snippets whose triggers appear in the transcript.
        snippets.append(makeSnippet(trigger: "alpha", expansion: "ALPHA"))
        snippets.append(makeSnippet(trigger: "beta", expansion: "BETA"))
        snippets.append(makeSnippet(trigger: "gamma", expansion: "GAMMA"))
        snippets.append(makeSnippet(trigger: "delta", expansion: "DELTA"))
        snippets.append(makeSnippet(trigger: "epsilon", expansion: "EPSILON"))
        let transcript = "alpha beta gamma delta epsilon"
        let result = SnippetEngine.apply(snippets, to: transcript)
        XCTAssertEqual(result, "ALPHA BETA GAMMA DELTA EPSILON")
    }

    // Disabled snippet (isEnabled: false) must NOT fire.
    func testDisabledSnippetSkipped() {
        let disabled = makeSnippet(trigger: "my sig", expansion: "X", isEnabled: false)
        let result = SnippetEngine.apply([disabled], to: "say my sig please")
        XCTAssertEqual(result, "say my sig please")
    }

    // Empty trigger must never match anything.
    func testEmptyTriggerSkipped() {
        let empty = makeSnippet(trigger: "", expansion: "BOOM")
        let result = SnippetEngine.apply([empty], to: "anything at all")
        XCTAssertEqual(result, "anything at all")
    }

    // Every occurrence of the trigger is replaced (not just the first).
    func testMultipleOccurrences() {
        let snippet = makeSnippet(trigger: "sig", expansion: "john@example.com")
        let result = SnippetEngine.apply([snippet], to: "send sig and sig again")
        XCTAssertEqual(result, "send john@example.com and john@example.com again")
    }

    // Expansion is NOT re-scanned: trigger "foo", expansion "foo bar" — input "foo" becomes "foo bar",
    // and the "foo" inside "foo bar" is not re-matched.
    func testExpansionNotRescanned() {
        let snippet = makeSnippet(trigger: "foo", expansion: "foo bar")
        let result = SnippetEngine.apply([snippet], to: "foo")
        XCTAssertEqual(result, "foo bar")
    }
}
