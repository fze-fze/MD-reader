import Foundation

nonisolated enum DocumentSearchMatcher {
    static func ranges(in text: String, query: String) -> [Range<String.Index>] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !text.isEmpty else { return [] }

        var matches: [Range<String.Index>] = []
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let match = text.range(
                  of: query,
                  options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                  range: searchStart..<text.endIndex,
                  locale: .current
              ) {
            matches.append(match)
            searchStart = match.upperBound
        }

        return matches
    }
}
