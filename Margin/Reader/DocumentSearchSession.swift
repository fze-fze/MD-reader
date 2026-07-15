import Foundation

@MainActor
@Observable
final class DocumentSearchSession {
    struct Request: Equatable {
        let indexRevision: Int
        let query: String
        let isActive: Bool
    }

    var query = ""

    private(set) var effectiveQuery = ""
    private(set) var matches: [DocumentSearchIndex.Match] = []
    private(set) var matchedBlockIDs: Set<Int> = []
    private(set) var currentMatchIndex: Int?
    private(set) var isSearching = false
    private(set) var navigationRevision = 0
    private(set) var isActive = false

    private var index = DocumentSearchIndex()
    private var indexRevision = 0

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

        resetResults()
        isSearching = true

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
              querySnapshot == query.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) else {
            return
        }

        effectiveQuery = querySnapshot
        matches = results
        matchedBlockIDs = Set(results.map(\.blockID))
        currentMatchIndex = nil
        isSearching = false
    }

    func moveToNext() {
        guard !matches.isEmpty else { return }
        if let currentMatchIndex {
            self.currentMatchIndex = (currentMatchIndex + 1) % matches.count
        } else {
            currentMatchIndex = 0
        }
        navigationRevision &+= 1
    }

    func moveToPrevious() {
        guard !matches.isEmpty else { return }
        if let currentMatchIndex {
            self.currentMatchIndex = (currentMatchIndex - 1 + matches.count) % matches.count
        } else {
            currentMatchIndex = matches.count - 1
        }
        navigationRevision &+= 1
    }

    func clear() {
        query = ""
        resetResults()
    }

    private func resetResults() {
        effectiveQuery = ""
        matches = []
        matchedBlockIDs = []
        currentMatchIndex = nil
        isSearching = false
    }
}
