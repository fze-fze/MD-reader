import SwiftUI

struct LiveMarkdownEditorView: View {
    private struct EditingRegion {
        let id = UUID()
        var row: LiveMarkdownDocument.Row
        var selection: NSRange
        var length: Int

        var range: NSRange { NSRange(location: row.range.location, length: length) }
    }

    private struct PresentationRow: Identifiable {
        enum ID: Hashable { case active, preview(Int) }
        let id: ID
        let row: LiveMarkdownDocument.Row
    }

    private struct ParseRequest: Equatable {
        let source: String
        let isComposing: Bool
    }

    @Binding var text: String
    @Binding var isFocused: Bool
    let initialLocation: Int
    let position: ReadingPosition
    let textScale: Double
    let baseURL: URL?
    let readerTheme: ReaderTheme
    let isCurrentEditor: () -> Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    @State private var document: LiveMarkdownDocument?
    @State private var parsedSource: String?
    @State private var rows: [PresentationRow] = []
    @State private var active: EditingRegion?
    @State private var requestedRow: LiveMarkdownDocument.Row?
    @State private var isComposing = false
    @State private var accessoryRequest: MarkdownEditorView.AccessoryRequest?

    private var theme: MarkdownTheme {
        MarkdownTheme(readerTheme: readerTheme, colorScheme: colorScheme)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { entry in
                        if let active, entry.id == .active {
                            editor(for: active)
                        } else {
                            preview(entry.row)
                        }
                    }
                }
                .frame(maxWidth: theme.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(MarkdownTypography.columnPadding(compact: horizontalSizeClass == .compact))
                .padding(.bottom, horizontalSizeClass == .compact ? 84 : 104)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: active?.id) { oldID, _ in
                proxy.scrollTo(PresentationRow.ID.active, anchor: oldID == nil ? .top : nil)
            }
        }
        .safeAreaBar(edge: .bottom) {
            if active != nil, isFocused {
                MarkdownAccessoryBar(readerTheme: readerTheme) { action in
                    accessoryRequest = .init(action: action)
                }
            }
        }
        .task(id: ParseRequest(source: text, isComposing: isComposing)) {
            guard !isComposing else { return }
            let source = text
            // Keep the active UITextView responsive. Only the new block
            // structure (not the native input) waits for this quiet period.
            if document != nil {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
            let snapshot = await Task.detached(priority: .userInitiated) {
                LiveMarkdownDocument(source: source)
            }.value
            guard !Task.isCancelled, text == source, !isComposing else { return }
            let location = requestedRow.map(mappedEnd) ?? (active == nil ? initialLocation : position.editorCaretLocation)
            document = snapshot
            parsedSource = source
            let row = snapshot.row(at: location)
            if requestedRow != nil || active?.range != row.range || active?.row.id != row.id {
                activate(row, location: location, focus: active == nil || isFocused || requestedRow != nil)
            } else {
                active?.row = row
            }
            requestedRow = nil
            updateRows()
        }
    }

    private func editor(for region: EditingRegion) -> some View {
        MarkdownEditorView(
            text: Binding(get: {
                let source = text as NSString
                let range = active?.id == region.id ? active?.range ?? region.range : region.range
                guard NSMaxRange(range) <= source.length else { return "" }
                return source.substring(with: range)
            }, set: { replacement in
                guard var current = active, current.id == region.id else { return }
                let source = text as NSString
                guard NSMaxRange(current.range) <= source.length,
                      source.substring(with: current.range) != replacement else { return }
                let updated = source.replacingCharacters(in: current.range, with: replacement)
                current.length = replacement.utf16.count
                active = current
                text = updated
            }),
            initialLocation: region.selection.location,
            position: position,
            textScale: textScale,
            isFocused: Binding(get: { active?.id == region.id && isFocused }, set: { focused in
                if active?.id == region.id { isFocused = focused }
            }),
            findTrigger: 0,
            liveFormatting: true,
            readerTheme: readerTheme,
            embedded: true,
            sourceOffset: region.range.location,
            accessoryRequest: accessoryRequest,
            isCurrentEditor: { active?.id == region.id && isCurrentEditor() },
            regionID: region.id,
            regionSelection: Binding(get: {
                active?.id == region.id ? active?.selection ?? region.selection : region.selection
            }, set: { selection in
                if active?.id == region.id, active?.selection != selection { active?.selection = selection }
            }),
            isComposing: $isComposing
        )
    }

    private func preview(_ row: LiveMarkdownDocument.Row) -> some View {
        Group {
            if let block = row.block {
                MarkdownBlockView(
                    block: block,
                    bodySize: bodySize * textScale,
                    theme: theme,
                    baseURL: baseURL,
                    searchText: "",
                    activeOccurrenceIndex: nil,
                    onToggleTask: { _ in }
                )
                .equatable()
            } else {
                Color.clear.frame(height: row.id == document?.rows.last?.id ? 44 : 4)
            }
        }
        .allowsHitTesting(false)
        .overlay {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { select(row) }
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { select(row) }
    }

    private func select(_ row: LiveMarkdownDocument.Row) {
        if parsedSource == text, !isComposing {
            activate(row, location: NSMaxRange(row.range), focus: true)
            updateRows()
        } else {
            requestedRow = row
        }
    }

    private func mappedEnd(_ row: LiveMarkdownDocument.Row) -> Int {
        guard let active, row.id > active.row.id else { return NSMaxRange(row.range) }
        // Only the active draft could have shifted positions in this snapshot.
        return NSMaxRange(row.range) + active.length - active.row.range.length
    }

    private func updateRows() {
        // Keep one native UITextView identity even when its source region
        // moves after typing Return or tapping another block.
        rows = document?.rows.map {
            PresentationRow(id: $0.id == active?.row.id ? .active : .preview($0.id), row: $0)
        } ?? []
    }

    private func activate(_ row: LiveMarkdownDocument.Row, location: Int, focus: Bool) {
        let local = max(0, min(row.range.length, location - row.range.location))
        position.editorCaretLocation = row.range.location + local
        active = EditingRegion(row: row, selection: NSRange(location: local, length: 0), length: row.range.length)
        isFocused = focus
    }
}
