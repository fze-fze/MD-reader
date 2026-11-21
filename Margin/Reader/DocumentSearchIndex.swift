import Foundation

nonisolated struct DocumentSearchIndex: Equatable, Sendable {
    struct Match: Identifiable, Equatable, Sendable {
        struct ID: Hashable, Sendable {
            let blockID: Int
            let occurrenceIndex: Int
        }

        let blockID: Int
        let occurrenceIndex: Int

        var id: ID {
            ID(blockID: blockID, occurrenceIndex: occurrenceIndex)
        }
    }

    private struct Entry: Equatable, Sendable {
        let blockID: Int
        let fragments: [String]
    }

    private let entries: [Entry]

    init(blocks: [MarkdownBlock] = []) {
        entries = blocks.compactMap { block in
            let fragments = block.searchableFragments.filter { !$0.isEmpty }
            return fragments.isEmpty ? nil : Entry(blockID: block.id, fragments: fragments)
        }
    }

    func matches(for query: String) -> [Match] {
        (try? collectMatches(for: query)) ?? []
    }

    // `@concurrent`: a nonisolated async function otherwise runs on its
    // caller's actor, which for the search session is the main one.
    @concurrent
    func matches(for query: String) async throws -> [Match] {
        try collectMatches(for: query) {
            try Task.checkCancellation()
        }
    }

    private func collectMatches(
        for query: String,
        cancellationCheck: () throws -> Void = {}
    ) throws -> [Match] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        var allMatches: [Match] = []
        for entry in entries {
            try cancellationCheck()
            var occurrenceIndex = 0

            for fragment in entry.fragments {
                try cancellationCheck()
                let count = DocumentSearchMatcher.ranges(in: fragment, query: query).count
                for _ in 0..<count {
                    allMatches.append(Match(
                        blockID: entry.blockID,
                        occurrenceIndex: occurrenceIndex
                    ))
                    occurrenceIndex += 1
                }
            }
        }
        return allMatches
    }
}
