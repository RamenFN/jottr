import XCTest
@testable import Grain

final class SnippetStoreTests: XCTestCase {

    // Returns a URL in the system's temp directory, unique per invocation.
    private func tempFileURL(suffix: String = "") -> URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("SnippetStoreTests-\(UUID().uuidString)\(suffix).json")
    }

    // Helper to build an enabled snippet.
    private func makeSnippet(trigger: String, expansion: String) -> Snippet {
        Snippet(id: UUID(), trigger: trigger, expansion: expansion, isEnabled: true)
    }

    // Save 3 snippets, load them back, assert equality.
    func testSaveAndLoad() throws {
        let url = tempFileURL(suffix: "saveload")
        let store = SnippetStore(fileURL: url)
        let s1 = makeSnippet(trigger: "sig", expansion: "john@example.com")
        let s2 = makeSnippet(trigger: "addr", expansion: "123 Main St")
        let s3 = makeSnippet(trigger: "ph", expansion: "+1-555-0100")
        try store.save([s1, s2, s3])
        let loaded = store.load()
        XCTAssertEqual(loaded, [s1, s2, s3])
    }

    // Loading from a non-existent path returns an empty array (not an error).
    func testLoadMissingFile() {
        let url = tempFileURL(suffix: "missing")
        let store = SnippetStore(fileURL: url)
        let loaded = store.load()
        XCTAssertEqual(loaded, [])
    }

    // add() appends; after two adds, load returns count == 2.
    func testAddAppends() throws {
        let url = tempFileURL(suffix: "add")
        let store = SnippetStore(fileURL: url)
        let s1 = makeSnippet(trigger: "sig", expansion: "john@example.com")
        let s2 = makeSnippet(trigger: "addr", expansion: "123 Main St")
        try store.add(s1)
        try store.add(s2)
        let loaded = store.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0], s1)
        XCTAssertEqual(loaded[1], s2)
    }

    func testDelete_removesSnippetById() throws {
        let url = tempFileURL(suffix: "delete")
        let store = SnippetStore(fileURL: url)
        let s1 = makeSnippet(trigger: "sig", expansion: "john@example.com")
        let s2 = makeSnippet(trigger: "addr", expansion: "123 Main St")
        let s3 = makeSnippet(trigger: "ph", expansion: "+1-555-0100")
        try store.save([s1, s2, s3])
        try store.delete(id: s2.id)
        let loaded = store.load()
        XCTAssertEqual(loaded, [s1, s3])
    }

    func testDelete_nonExistentId() throws {
        let url = tempFileURL(suffix: "deletemissing")
        let store = SnippetStore(fileURL: url)
        let s1 = makeSnippet(trigger: "sig", expansion: "john@example.com")
        try store.save([s1])
        try store.delete(id: UUID())
        let loaded = store.load()
        XCTAssertEqual(loaded, [s1])
    }

    func testUpdate_changesTriggerAndExpansion() throws {
        let url = tempFileURL(suffix: "update")
        let store = SnippetStore(fileURL: url)
        let s1 = makeSnippet(trigger: "sig", expansion: "john@example.com")
        let s2 = makeSnippet(trigger: "addr", expansion: "123 Main St")
        let s3 = makeSnippet(trigger: "ph", expansion: "+1-555-0100")
        try store.save([s1, s2, s3])
        try store.update(id: s2.id, trigger: "new-trigger", expansion: "new expansion")
        let loaded = store.load()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0], s1)
        XCTAssertEqual(loaded[1].trigger, "new-trigger")
        XCTAssertEqual(loaded[1].expansion, "new expansion")
        XCTAssertEqual(loaded[1].id, s2.id)
        XCTAssertEqual(loaded[2], s3)
    }

    func testUpdate_nonExistentId() throws {
        let url = tempFileURL(suffix: "updatemissing")
        let store = SnippetStore(fileURL: url)
        let s1 = makeSnippet(trigger: "sig", expansion: "john@example.com")
        try store.save([s1])
        try store.update(id: UUID(), trigger: "x", expansion: "y")
        let loaded = store.load()
        XCTAssertEqual(loaded, [s1])
    }
}
