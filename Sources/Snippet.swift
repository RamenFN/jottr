import Foundation

struct Snippet: Codable, Identifiable, Equatable {
    var id: UUID
    var trigger: String
    var expansion: String
    var isEnabled: Bool
}
