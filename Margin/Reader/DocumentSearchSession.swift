import Foundation

@MainActor
@Observable
final class DocumentSearchSession {
    private struct Results {
        var effectiveQuery = ""
        var matches: [DocumentSearchIndex.Match] = []
        var matchedBlockIDs: Set<Int> = []
        var currentMatchIndex: Int?

        static let empty = Results()
    }

    struct Request: Equatable {
        let indexRevision: Int
        let query: String
        let isActive: Bool
    }

    var query = ""

    private var results = Results.empty
    private(set) var isSearching = false
    private(set) var navigationRevision = 0
    private(set) var isActive = false

    private var index = DocumentSearchIndex()
    private var indexRevision = 0
    private var searchRevision = 0

    var effectiveQuery: String { results.effectiveQuery }
    var matches: [DocumentSearchIndex.Match] { results.matches }
    var matchedBlockIDs: Set<Int> { results.matchedBlockIDs }
    var currentMatchIndex: Int? { results.currentMatchIndex }

    var request: Request {
        Request(indexRevision: indexRevision, query: query, isActive: isActive)
    }

    var activeMatch: DocumentSearchIndex.Match? {
        guard let currentMatchIndex,
              matches.indices.contains(currentMatchIndex) else {
            return nil
        }
        return matches[currentMatchIndex]
    }

    var hasMatches: Bool {
        !matches.isEmpty
    }

    var statusText: String {
        if matches.isEmpty {
            L10n.string("reader.no_matches")
        } else if let currentMatchIndex {
            L10n.format(
                "reader.match_position",
                Int64(currentMatchIndex + 1),
                Int64(matches.count)
            )
        } else {
            L10n.format("reader.match_count", Int64(matches.count))
        }
    }

    func replaceIndex(_ index: DocumentSearchIndex) {
        self.index = index
        indexRevision &+= 1
        resetResults()
    }

    func activate() {
        isActive = true
    }

    func deactivate() {
        isActive = false
        resetResults()
    }

    func performSearch() async {
        guard isActive else {
            resetResults()
            return
        }

        let querySnapshot = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !querySnapshot.isEmpty else {
            resetResults()
            return
        }

        let indexRevisionSnapshot = indexRevision
        searchRevision &+= 1
        let searchRevisionSnapshot = searchRevision
        isSearching = true
        defer {
            if searchRevisionSnapshot == searchRevision {
                isSearching = false
            }
        }

        do {
            try await Task.sleep(for: .milliseconds(180))
        } catch {
            return
        }
        guard !Task.isCancelled, isActive else { return }

        let indexSnapshot = index
        let results: [DocumentSearchIndex.Match]
        do {
            results = try await indexSnapshot.matches(for: querySnapshot)
        } catch {
            return
        }
        guard !Task.isCancelled,
              isActive,
              searchRevisionSnapshot == searchRevision,
              indexRevisionSnapshot == indexRevision,
              querySnapshot == query.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) else {
            return
        }

        self.results = Results(
            effectiveQuery: querySnapshot,
            matches: results,
            matchedBlockIDs: Set(results.map(\.blockID)),
            currentMatchIndex: nil
        )
    }

    func moveToNext() {
        guard !matches.isEmpty else { return }
        if let currentMatchIndex {
            results.currentMatchIndex = (currentMatchIndex + 1) % matches.count
        } else {
            results.currentMatchIndex = 0
        }
        navigationRevision &+= 1
    }

    func moveToPrevious() {
        guard !matches.isEmpty else { return }
        if let currentMatchIndex {
            results.currentMatchIndex = (currentMatchIndex - 1 + matches.count) % matches.count
        } else {
            results.currentMatchIndex = matches.count - 1
        }
        navigationRevision &+= 1
    }

    func clear() {
        query = ""
        resetResults()
    }

    private func resetResults() {
        searchRevision &+= 1
        results = .empty
        isSearching = false
    }
}
