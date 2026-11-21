import SwiftUI

struct MarkdownReaderView: View {
    let source: String
    let searchSession: DocumentSearchSession
    @Binding var scrollTarget: Int?
    let textScale: Double
    let baseURL: URL?
    let readerTheme: ReaderTheme
    var bodyFont = ReaderFontChoice.themeDefault
    var headingFont = ReaderFontChoice.themeDefault
    let position: ReadingPosition
    let positionRestoreRevision: Int
    let onToggleTask: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    @State private var blocks: [MarkdownBlock] = []
    // The source `blocks` was parsed from, to tell a finished parse from one
    // still on its way.
    @State private var parsedSource: String?

    private var theme: MarkdownTheme {
        MarkdownTheme(
            readerTheme: readerTheme,
            colorScheme: colorScheme,
            bodyFont: bodyFont,
            headingFont: headingFont
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(blocks) { block in
                        let blockSearchText = searchSession.matchedBlockIDs.contains(block.id)
                            ? searchSession.effectiveQuery
                            : ""
                        MarkdownBlockView(
                            block: block,
                            bodySize: bodySize * textScale,
                            theme: theme,
                            baseURL: baseURL,
                            searchText: blockSearchText,
                            activeOccurrenceIndex: searchSession.activeMatch?.blockID == block.id
                                ? searchSession.activeMatch?.occurrenceIndex
                                : nil,
                            onToggleTask: onToggleTask
                        )
                            .equatable()
                            .id(block.id)
                    }
                }
                .scrollTargetLayout()
                .frame(maxWidth: theme.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(MarkdownTypography.columnPadding(compact: horizontalSizeClass == .compact))
                .padding(.bottom, horizontalSizeClass == .compact ? 84 : 104)
            }
            .scrollIndicators(.hidden)
            .background(theme.canvas)
            .onScrollTargetVisibilityChange(idType: Int.self, threshold: 0.01) { visibleIDs in
                position.visibleBlockIDs = visibleIDs
            }
            .onChange(of: positionRestoreRevision) {
                // With an unchanged document there is no parse to wait for.
                if parsedSource == source {
                    restorePendingPosition(using: proxy)
                }
            }
            .task(id: source) {
                let sourceSnapshot = source
                let parsedBlocks = await Task.detached(priority: .userInitiated) {
                    MarkdownParser.parse(sourceSnapshot)
                }.value
                guard !Task.isCancelled else { return }
                // Only the parse stands between a source change and the
                // screen; the search index is built when search asks for it.
                blocks = parsedBlocks
                parsedSource = sourceSnapshot
                searchSession.replaceBlocks(parsedBlocks)
                restorePendingPosition(using: proxy)
            }
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.snappy) {
                    proxy.scrollTo(target, anchor: .top)
                }
                scrollTarget = nil
            }
            .onChange(of: searchSession.navigationRevision) {
                scrollToCurrentMatch(using: proxy)
            }
        }
    }

    // Brings the block holding the line the editor left off at on screen,
    // unless the reader is already showing it.
    private func restorePendingPosition(using proxy: ScrollViewProxy) {
        guard let line = position.pendingLine else { return }
        position.pendingLine = nil
        guard let target = blocks.last(where: { $0.id <= line })?.id,
              !position.visibleBlockIDs.contains(target) else { return }
        // Animated like the outline jump: a lazy stack only knows estimated
        // offsets for blocks it has not built, and settles on the real one
        // as the animation brings them in.
        withAnimation(.snappy) {
            proxy.scrollTo(target, anchor: .top)
        }
    }

    private func scrollToCurrentMatch(using proxy: ScrollViewProxy) {
        guard let activeMatch = searchSession.activeMatch,
              let targetIndex = blocks.firstIndex(where: { $0.id == activeMatch.blockID }) else { return }
        let target = activeMatch.blockID
        let anchor = blocks[targetIndex].scrollAnchor(
            forOccurrence: activeMatch.occurrenceIndex,
            query: searchSession.effectiveQuery
        )

        let visible = position.visibleBlockIDs
        if visible.contains(target) {
            // Already on screen: move only as far as it takes to show the
            // whole block (or, in a long one, the part holding the match).
            withAnimation(.snappy) {
                proxy.scrollTo(target, anchor: anchor)
            }
            return
        }

        let isNearby = visible.contains { visibleID in
            guard let index = blocks.firstIndex(where: { $0.id == visibleID }) else { return false }
            return abs(index - targetIndex) <= 24
        }
        if isNearby {
            withAnimation(.snappy) {
                proxy.scrollTo(target, anchor: anchor ?? .center)
            }
        } else {
            // Far away the lazy stack only has estimated offsets, and an
            // animation there sweeps through passages that have nothing to do
            // with the search. Jump, then settle once the blocks around the
            // target have been built and measured.
            proxy.scrollTo(target, anchor: anchor ?? .center)
            Task { @MainActor in
                await Task.yield()
                proxy.scrollTo(target, anchor: anchor ?? .center)
            }
        }
    }
}

struct MarkdownBlockView: View, Equatable {
    // Lets SwiftUI skip blocks whose inputs did not change when the document
    // is re-parsed or the search state moves — a task toggle or a keystroke
    // in the search field then redraws one block instead of every visible
    // one. `onToggleTask` is left out: it captures only the document binding.
    static func == (lhs: MarkdownBlockView, rhs: MarkdownBlockView) -> Bool {
        lhs.block == rhs.block
            && lhs.bodySize == rhs.bodySize
            && lhs.theme == rhs.theme
            && lhs.baseURL == rhs.baseURL
            && lhs.searchText == rhs.searchText
            && lhs.activeOccurrenceIndex == rhs.activeOccurrenceIndex
    }

    let block: MarkdownBlock
    let bodySize: Double
    let theme: MarkdownTheme
    let baseURL: URL?
    let searchText: String
    let activeOccurrenceIndex: Int?
    let onToggleTask: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Width of the reading column, so a narrow table's rules still span it.
    @State private var tableContainerWidth: CGFloat = 0

    var body: some View {
        switch block.kind {
        case let .heading(level, text):
            heading(level: level, text: text)
        case let .paragraph(text):
            SelectableInlineText(
                source: text,
                fonts: inlineUIFonts(size: bodySize),
                mathFontSize: bodySize,
                foregroundColor: UIColor(theme.textPrimary),
                theme: theme,
                searchText: searchText,
                activeOccurrenceIndex: activeOccurrenceIndex,
                lineSpacing: bodySize * 0.38
            )
            .padding(.vertical, bodySize * 0.39)
            .accessibilityElement(children: .contain)
        case let .blockquote(text):
            quote(text)
        case let .unorderedList(items), let .orderedList(items), let .taskList(items):
            list(items)
        case let .code(language, source):
            if MermaidSupport.isMermaid(language: language) {
                MermaidBlockView(
                    source: source,
                    bodySize: bodySize,
                    theme: theme,
                    searchText: searchText,
                    activeOccurrenceIndex: activeOccurrenceIndex
                )
            } else {
                codeBlock(language: language, source: source)
            }
        case let .math(source):
            MathBlockView(
                source: source,
                bodySize: bodySize,
                theme: theme,
                searchText: searchText,
                activeOccurrenceIndex: activeOccurrenceIndex
            )
        case let .table(headers, rows):
            table(headers: headers, rows: rows)
        case let .image(alt, source):
            markdownImage(alt: alt, source: source)
        case let .frontMatter(source):
            frontMatter(source)
        case .divider:
            Divider()
                .overlay(theme.separator.opacity(0.75))
                .padding(.vertical, 26)
        }
    }

    private func heading(level: Int, text: String) -> some View {
        let multiplier = theme.headingScale(level: level)
        return SelectableInlineText(
            source: text,
            fonts: MarkdownTypography.inlineUIFonts(
                typeface: theme.headingTypeface,
                size: bodySize * multiplier,
                weight: .semibold
            ),
            mathFontSize: bodySize * multiplier,
            foregroundColor: UIColor(level == 6 ? theme.textSecondary : theme.textStrong),
            theme: theme,
            searchText: searchText,
            activeOccurrenceIndex: activeOccurrenceIndex,
            lineSpacing: bodySize * 0.16
        )
        .padding(.top, level == 1 ? bodySize * 0.35 : bodySize * 1.45)
        .padding(.bottom, bodySize * 0.35)
        .accessibilityAddTraits(.isHeader)
    }

    private func quote(_ text: String) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(theme.quoteRule)
                .frame(width: 3)
            SelectableInlineText(
                source: text,
                fonts: inlineUIFonts(size: bodySize),
                mathFontSize: bodySize,
                foregroundColor: UIColor(theme.quoteText),
                theme: theme,
                searchText: searchText,
                activeOccurrenceIndex: activeOccurrenceIndex,
                lineSpacing: bodySize * 0.38
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.quoteFill)
        .clipShape(
            .rect(
                topLeadingRadius: 1.5,
                bottomLeadingRadius: 1.5,
                bottomTrailingRadius: 10,
                topTrailingRadius: 10
            )
        )
        .padding(.vertical, bodySize * 0.39)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.format("reader.quote_accessibility", text))
    }

    // One view for every list kind: each item draws its own marker (number,
    // bullet or checkbox) and is indented by its nesting level, so mixed and
    // nested lists need no special casing.
    private func list(_ items: [MarkdownListItem]) -> some View {
        let offsets = fragmentOccurrenceOffsets
        let itemFonts = inlineUIFonts(size: bodySize)
        let hasTasks = items.contains { $0.isChecked != nil }
        return VStack(alignment: .leading, spacing: hasTasks ? 4 : 7) {
            ForEach(items.enumerated(), id: \.element.id) { itemIndex, item in
                Group {
                    if let isChecked = item.isChecked {
                        taskRow(
                            item,
                            isChecked: isChecked,
                            fonts: itemFonts,
                            occurrenceOffset: occurrenceOffset(offsets, itemIndex)
                        )
                    } else {
                        bulletRow(
                            item,
                            fonts: itemFonts,
                            occurrenceOffset: occurrenceOffset(offsets, itemIndex)
                        )
                        // Lines up with the text of neighbouring task rows.
                        .padding(.leading, hasTasks ? 14 : 0)
                    }
                }
                .padding(.leading, Double(item.level) * bodySize * 1.5)
            }
        }
        .padding(.leading, hasTasks ? 0 : 2)
        .padding(.vertical, bodySize * 0.39)
    }

    private func bulletRow(
        _ item: MarkdownListItem,
        fonts: InlineMarkdownUIFonts,
        occurrenceOffset: Int
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(listMarker(for: item))
                .font(documentFont(size: bodySize))
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
                .frame(minWidth: 20, alignment: .trailing)
            SelectableInlineText(
                source: item.text,
                fonts: fonts,
                mathFontSize: bodySize,
                foregroundColor: UIColor(theme.textPrimary),
                theme: theme,
                searchText: searchText,
                activeOccurrenceIndex: activeOccurrenceIndex,
                occurrenceOffset: occurrenceOffset,
                lineSpacing: bodySize * 0.38
            )
        }
    }

    private func listMarker(for item: MarkdownListItem) -> String {
        if let ordinal = item.ordinal { return "\(ordinal)." }
        return switch item.level {
        case 0: "•"
        case 1: "◦"
        default: "▪"
        }
    }

    private func taskRow(
        _ item: MarkdownListItem,
        isChecked: Bool,
        fonts: InlineMarkdownUIFonts,
        occurrenceOffset: Int
    ) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Button {
                onToggleTask(item.id)
            } label: {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isChecked ? theme.accent : theme.textSecondary)
                    .font(.system(size: bodySize * 0.95))
                    .contentTransition(.symbolEffect(.replace))
                    .animation(
                        reduceMotion ? nil : .snappy(duration: 0.18),
                        value: isChecked
                    )
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(.rect)
            .accessibilityLabel(item.text)
            .accessibilityValue(
                L10n.string(isChecked ? "reader.task.completed" : "reader.task.incomplete")
            )
            .accessibilityHint(
                L10n.string(
                    isChecked
                        ? "reader.task.mark_incomplete_hint"
                        : "reader.task.mark_completed_hint"
                )
            )
            .sensoryFeedback(.selection, trigger: isChecked)

            SelectableInlineText(
                source: item.text,
                fonts: fonts,
                mathFontSize: bodySize,
                foregroundColor: UIColor(isChecked ? theme.textSecondary : theme.textPrimary),
                theme: theme,
                searchText: searchText,
                activeOccurrenceIndex: activeOccurrenceIndex,
                occurrenceOffset: occurrenceOffset
            )
            .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
    }

    private func codeBlock(language: String?, source: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(language?.uppercased() ?? L10n.string("reader.code"))
                    .font(.system(.caption2, design: theme.codeFont, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                CodeCopyButton(source: source, theme: theme)
            }
            // The copy button keeps its 44pt target without the header
            // row growing a band of dead space above the code.
            .padding(.vertical, -6)
            ScrollView(.horizontal) {
                SearchablePlainText(
                    source: source,
                    font: .system(size: bodySize * 0.9, design: theme.codeFont),
                    foregroundStyle: theme.codeText,
                    theme: theme,
                    searchText: searchText,
                    activeOccurrenceIndex: activeOccurrenceIndex,
                    occurrenceOffset: 0
                )
                    .lineSpacing(bodySize * 0.39)
                    .textSelection(.enabled)
                    .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.codeFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.codeBorder))
        .padding(.top, 14)
        .padding(.bottom, 18)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            language.map { L10n.format("reader.code_block_language", $0) }
                ?? L10n.string("reader.code_block")
        )
    }

    private func table(headers: [String], rows: [[String]]) -> some View {
        let offsets = fragmentOccurrenceOffsets
        let headerFonts = inlineUIFonts(size: bodySize * 0.93, weight: .semibold)
        let cellFonts = inlineUIFonts(size: bodySize * 0.93)
        return ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 0) {
                GridRow {
                    ForEach(headers.enumerated(), id: \.offset) { columnIndex, value in
                        tableCell(
                            value: value,
                            fonts: headerFonts,
                            foregroundColor: UIColor(theme.textStrong),
                            occurrenceOffset: occurrenceOffset(offsets, columnIndex)
                        )
                    }
                }
                Divider().overlay(theme.tableStrongRule)
                ForEach(rows.enumerated(), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(row.enumerated(), id: \.offset) { columnIndex, value in
                            tableCell(
                                value: value,
                                fonts: cellFonts,
                                foregroundColor: UIColor(theme.textPrimary),
                                occurrenceOffset: occurrenceOffset(
                                    offsets,
                                    headers.count + rowIndex * headers.count + columnIndex
                                )
                            )
                        }
                    }
                    if rowIndex < rows.count - 1 {
                        Divider().overlay(theme.tableRowRule)
                    }
                }
            }
            .frame(minWidth: tableContainerWidth, alignment: .leading)
            .overlay(alignment: .top) { Divider().overlay(theme.tableStrongRule) }
            .overlay(alignment: .bottom) { Divider().overlay(theme.tableStrongRule) }
        }
        .scrollIndicators(.hidden)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            tableContainerWidth = width
        }
        .padding(.vertical, bodySize * 0.39)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            L10n.format(
                "reader.table_accessibility",
                Int64(headers.count),
                Int64(rows.count)
            )
        )
    }

    // A single table cell. Selectable and copyable like body text, but sized to
    // its content so the column widths still track the longest cell, and marked
    // out of the annotation scope (tables are not annotatable in v1).
    private func tableCell(
        value: String,
        fonts: InlineMarkdownUIFonts,
        foregroundColor: UIColor,
        occurrenceOffset: Int
    ) -> some View {
        SelectableInlineText(
            source: value,
            fonts: fonts,
            mathFontSize: bodySize * 0.93,
            foregroundColor: foregroundColor,
            theme: theme,
            searchText: searchText,
            activeOccurrenceIndex: activeOccurrenceIndex,
            occurrenceOffset: occurrenceOffset,
            allowsAnnotation: false,
            sizingMode: .intrinsic
        )
        .padding(.vertical, 12)
    }

    private func frontMatter(_ source: String) -> some View {
        SearchablePlainText(
            source: source,
            font: documentFont(size: bodySize),
            foregroundStyle: theme.textSecondary,
            theme: theme,
            searchText: searchText,
            activeOccurrenceIndex: activeOccurrenceIndex,
            occurrenceOffset: 0
        )
            .lineSpacing(bodySize * 0.38)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(theme.frontMatterFill, in: RoundedRectangle(cornerRadius: 10))
            .padding(.bottom, bodySize * 0.78)
            .accessibilityLabel(L10n.format("reader.metadata_accessibility", source))
    }

    @ViewBuilder
    private func markdownImage(alt: String, source: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if let url = imageURL(for: source) {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFit()
                    case .failure:
                        imagePlaceholder(alt: alt)
                    case .empty:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                    @unknown default:
                        imagePlaceholder(alt: alt)
                    }
                }
            } else {
                imagePlaceholder(alt: alt)
            }

            if !alt.isEmpty {
                SearchablePlainText(
                    source: alt,
                    font: documentFont(size: bodySize * 0.9),
                    foregroundStyle: theme.textSecondary,
                    theme: theme,
                    searchText: searchText,
                    activeOccurrenceIndex: activeOccurrenceIndex,
                    occurrenceOffset: 0
                )
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, bodySize * 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(alt.isEmpty ? L10n.string("reader.document_image") : alt)
    }

    private func imagePlaceholder(alt: String) -> some View {
        // The caption below already carries the alt text, so the placeholder
        // only says what went wrong, in the document's own type.
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: bodySize * 1.5, weight: .light))
                .symbolRenderingMode(.hierarchical)
            Text("reader.image_error_title")
                .font(documentFont(size: bodySize * 0.9, weight: .medium))
            if alt.isEmpty {
                Text("reader.image_error_description")
                    .font(documentFont(size: bodySize * 0.82))
            }
        }
        .foregroundStyle(theme.textSecondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 112)
        .background(theme.codeFill, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.codeBorder))
    }

    // Remote and document-relative images both load through the shared cache;
    // this only resolves the URL, leaving I/O and decoding to the loader.
    private func imageURL(for source: String) -> URL? {
        if let url = URL(string: source),
           ["http", "https"].contains(url.scheme?.lowercased()) {
            return url
        }
        guard let baseURL else { return nil }
        let path = source.removingPercentEncoding ?? source
        let fileURL = baseURL.appending(path: path).standardizedFileURL
        return FileManager.default.fileExists(atPath: fileURL.path()) ? fileURL : nil
    }

    private func documentFont(
        size: Double,
        weight: UIFont.Weight = .regular
    ) -> Font {
        MarkdownTypography.documentFont(
            typeface: theme.bodyTypeface,
            size: size,
            weight: weight
        )
    }

    private func inlineFonts(
        size: Double,
        weight: UIFont.Weight = .regular
    ) -> InlineMarkdownFonts {
        MarkdownTypography.inlineFonts(
            typeface: theme.bodyTypeface,
            size: size,
            weight: weight
        )
    }

    private func inlineUIFonts(
        size: Double,
        weight: UIFont.Weight = .regular
    ) -> InlineMarkdownUIFonts {
        MarkdownTypography.inlineUIFonts(
            typeface: theme.bodyTypeface,
            size: size,
            weight: weight
        )
    }

    // Prefix sums of per-fragment match counts, so a list item or table cell
    // knows where its own matches start within the block. Computing fragments
    // parses markdown, so this stays empty unless a search is actually running
    // — otherwise every render of every list and table would pay for it.
    private var fragmentOccurrenceOffsets: [Int] {
        guard !searchText.isEmpty else { return [] }

        var offsets: [Int] = []
        var runningTotal = 0
        for fragment in block.searchableFragments {
            offsets.append(runningTotal)
            runningTotal += DocumentSearchMatcher.ranges(
                in: fragment,
                query: searchText
            ).count
        }
        return offsets
    }

    private func occurrenceOffset(_ offsets: [Int], _ fragmentIndex: Int) -> Int {
        offsets.indices.contains(fragmentIndex) ? offsets[fragmentIndex] : 0
    }
}

private struct MathBlockView: View {
    let source: String
    let bodySize: Double
    let theme: MarkdownTheme
    let searchText: String
    let activeOccurrenceIndex: Int?

    var body: some View {
        if let formula = MathRenderer.formula(
            latex: source,
            fontSize: bodySize * 1.12,
            textColor: UIColor(theme.textPrimary),
            display: true,
            readerTheme: theme.readerTheme
        ) {
            ViewThatFits(in: .horizontal) {
                Image(uiImage: formula.image)
                ScrollView(.horizontal) {
                    Image(uiImage: formula.image)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, bodySize * 0.55)
            .accessibilityLabel(L10n.format("reader.math_accessibility", source))
        } else {
            // Invalid LaTeX: show the raw source in code styling so the
            // document still reads and search highlighting keeps working.
            SearchablePlainText(
                source: source,
                font: .system(size: bodySize * 0.9, design: theme.codeFont),
                foregroundStyle: theme.codeText,
                theme: theme,
                searchText: searchText,
                activeOccurrenceIndex: activeOccurrenceIndex,
                occurrenceOffset: 0
            )
            .lineSpacing(bodySize * 0.39)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.codeFill, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.codeBorder))
            .padding(.vertical, bodySize * 0.39)
            .accessibilityLabel(L10n.format("reader.math_accessibility", source))
        }
    }
}
