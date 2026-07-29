import Foundation

nonisolated enum MermaidSupport {
    // Fence infostrings occasionally carry extra words (```mermaid theme=dark),
    // so only the first token decides whether the block is a diagram.
    static func isMermaid(language: String?) -> Bool {
        guard let language else { return false }
        let token = language
            .trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: { $0.isWhitespace })
            .first?
            .lowercased()
        return token == "mermaid"
    }
}
