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

    // The index costs an inline-Markdown parse per block, so it is built from
    // `blocks` off the main actor the first time search needs it rather than
    // on every document change.
    @ObservationIgnored private var blocks: [MarkdownBlock] = []
    @ObservationIgnored private var index: DocumentSearchIndex? = DocumentSearchIndex()
    @ObservationIgnored private var indexBuild: (revision: Int, task: Task<DocumentSearchIndex, Never>)?
    // Where the reader is, so the first jump of a search goes to the nearest
    // match rather than to the top of the document.
    @ObservationIgnored weak var readingPosition: ReadingPosition?
    private var indexRevision = 0
    private var searchRevision = 0

    var effectiveQuery: String { results.effectiveQuery }
    var matches: [DocumentSearchIndex.Match] { results.matches }
    var matchedBlockIDs: Set<Int> { results.matchedBlockIDs }
    var currentMatchIndex: Int? { results.currentMatchIndex }

    var request: Request {
        // Trimmed, as the search itself is: a trailing space is not a new
        // query.
        Request(
            indexRevision: indexRevision,
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: isActive
        )
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
        blocks = []
        self.index = index
        indexBuild = nil
        indexRevision &+= 1
        resetResults()
    }

    func replaceBlocks(_ blocks: [MarkdownBlock]) {
        self.blocks = blocks
        index = nil
        indexBuild = nil
        indexRevision &+= 1
        resetResults()
        if isActive { warmIndex() }
    }

    func activate() {
        isActive = true
        // Start indexing while the user is still typing the query.
        warmIndex()
    }

    private func warmIndex() {
        guard index == nil else { return }
        Task { _ = await currentIndex() }
    }

    // The index for the current blocks, built at most once per revision no
    // matter how many searches are waiting on it. Nil when the document
    // changed underneath the build.
    private func currentIndex() async -> DocumentSearchIndex? {
        if let index { return index }

        let revision = indexRevision
        let build: Task<DocumentSearchIndex, Never>
        if let indexBuild, indexBuild.revision == revision {
            build = indexBuild.task
        } else {
            let snapshot = blocks
            build = Task.detached(priority: .userInitiated) {
                DocumentSearchIndex(blocks: snapshot)
            }
            indexBuild = (revision, build)
        }

        let built = await build.value
        guard revision == indexRevision else { return nil }
        index = built
        indexBuild = nil
        return built
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

        // Just long enough to coalesce a burst of keystrokes; a superseded
        // search is cancelled anyway.
        do {
            try await Task.sleep(for: .milliseconds(60))
        } catch {
            return
        }
        guard !Task.isCancelled, isActive else { return }

        guard let indexSnapshot = await currentIndex() else { return }
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
            results.currentMatchIndex = firstMatchIndexFromReadingPosition ?? 0
        }
        navigationRevision &+= 1
    }

    func moveToPrevious() {
        guard !matches.isEmpty else { return }
        if let currentMatchIndex {
            results.currentMatchIndex = (currentMatchIndex - 1 + matches.count) % matches.count
        } else {
            let next = firstMatchIndexFromReadingPosition ?? 0
            results.currentMatchIndex = (next - 1 + matches.count) % matches.count
        }
        navigationRevision &+= 1
    }

    // The first match on or below the top of what the reader is showing.
    // Matches are in document order, as are block IDs.
    private var firstMatchIndexFromReadingPosition: Int? {
        guard let topLine = readingPosition?.topVisibleLine else { return nil }
        return matches.firstIndex { $0.blockID >= topLine }
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
