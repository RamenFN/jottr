import Foundation

final class SnippetStore {
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Jottr"
        let dir = appSupport.appendingPathComponent(appName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("snippets.json")
    }

    /// Test-only initializer — accepts an explicit file URL for isolation.
    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() -> [Snippet] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Snippet].self, from: data)) ?? []
    }

    func save(_ snippets: [Snippet]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(snippets)
        try data.write(to: fileURL, options: .atomic)
    }

    func add(_ snippet: Snippet) throws {
        guard !snippet.trigger.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var all = load()
        all.append(snippet)
        try save(all)
    }

    func delete(id: UUID) throws {
        var all = load()
        all.removeAll { $0.id == id }
        try save(all)
    }

    func update(id: UUID, trigger: String, expansion: String) throws {
        var all = load()
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        all[index].trigger = trigger
        all[index].expansion = expansion
        try save(all)
    }
}
