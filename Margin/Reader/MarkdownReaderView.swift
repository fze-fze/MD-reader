import SwiftUI

struct MarkdownReaderView: View {
    let source: String
    let searchSession: DocumentSearchSession
    @Binding var scrollTarget: Int?
    let textScale: Double
    let baseURL: URL?
    let readerTheme: ReaderTheme
    let onToggleTask: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    @State private var blocks: [MarkdownBlock] = []

    private var theme: MarkdownTheme {
        MarkdownTheme(readerTheme: readerTheme, colorScheme: colorScheme)
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
                            .id(block.id)
                    }
                }
                .frame(maxWidth: theme.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalSizeClass == .compact ? 20 : 32)
                .padding(.top, horizontalSizeClass == .compact ? 24 : 32)
                .padding(.bottom, horizontalSizeClass == .compact ? 84 : 104)
            }
            .scrollIndicators(.hidden)
            .background(theme.canvas)
            .task(id: source) {
                let sourceSnapshot = source
                let result = await Task.detached(priority: .userInitiated) {
                    let parsedBlocks = MarkdownParser.parse(sourceSnapshot)
                    return (parsedBlocks, DocumentSearchIndex(blocks: parsedBlocks))
                }.value
                guard !Task.isCancelled else { return }
                blocks = result.0
                searchSession.replaceIndex(result.1)
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

    private func scrollToCurrentMatch(using proxy: ScrollViewProxy) {
        guard let activeMatch = searchSession.activeMatch else { return }
        withAnimation(.snappy) {
            proxy.scrollTo(activeMatch.blockID, anchor: .center)
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock
    let bodySize: Double
    let theme: MarkdownTheme
    let baseURL: URL?
    let searchText: String
    let activeOccurrenceIndex: Int?
    let onToggleTask: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch block.kind {
        case let .heading(level, text):
            heading(level: level, text: text)
        case let .paragraph(text):
            InlineMarkdownText(
                source: text,
                fonts: inlineFonts(size: bodySize),
                mathFontSize: bodySize,
                foregroundStyle: theme.textPrimary,
                theme: theme,
                searchText: searchText,
                activeOccurrenceIndex: activeOccurrenceIndex
            )
            .lineSpacing(bodySize * 0.38)
            .padding(.vertical, bodySize * 0.39)
            .accessibilityElement(children: .contain)
        case let .blockquote(text):
            quote(text)
        case let .unorderedList(items):
            list(items, ordered: false)
        case let .orderedList(items):
            list(items, ordered: true)
        case let .taskList(items):
            taskList(items)
        case let .code(language, source):
            codeBlock(language: language, source: source)
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
        return InlineMarkdownText(
            source: text,
            fonts: inlineFonts(size: bodySize * multiplier, weight: .semibold),
            mathFontSize: bodySize * multiplier,
            foregroundStyle: level == 6 ? theme.textSecondary : theme.textStrong,
            theme: theme,
            searchText: searchText,
            activeOccurrenceIndex: activeOccurrenceIndex
        )
        .lineSpacing(bodySize * 0.16)
        .padding(.top, level == 1 ? bodySize * 0.35 : bodySize * 1.45)
        .padding(.bottom, bodySize * 0.35)
        .accessibilityAddTraits(.isHeader)
    }

    private func quote(_ text: String) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(theme.quoteRule)
                .frame(width: 2)
            InlineMarkdownText(
                source: text,
                fonts: inlineFonts(size: bodySize),
                mathFontSize: bodySize,
                foregroundStyle: theme.quoteText,
                theme: theme,
                searchText: searchText,
                activeOccurrenceIndex: activeOccurrenceIndex
            )
            .lineSpacing(bodySize * 0.38)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.quoteFill, in: RoundedRectangle(cornerRadius: 10))
        .padding(.vertical, bodySize * 0.39)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.format("reader.quote_accessibility", text))
    }

    private func list(_ items: [MarkdownListItem], ordered: Bool) -> some View {
        let offsets = fragmentOccurrenceOffsets
        let itemFonts = inlineFonts(size: bodySize)
        return VStack(alignment: .leading, spacing: 7) {
            ForEach(items.enumerated(), id: \.element.id) { itemIndex, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(ordered ? "\(itemIndex + 1)." : "•")
                        .font(documentFont(size: bodySize))
                        .foregroundStyle(theme.textSecondary)
                        .frame(minWidth: 20, alignment: .trailing)
                    InlineMarkdownText(
                        source: item.text,
                        fonts: itemFonts,
                        mathFontSize: bodySize,
                        foregroundStyle: theme.textPrimary,
                        theme: theme,
                        searchText: searchText,
                        activeOccurrenceIndex: activeOccurrenceIndex,
                        occurrenceOffset: occurrenceOffset(offsets, itemIndex)
                    )
                    .lineSpacing(bodySize * 0.38)
                }
            }
        }
        .padding(.leading, 2)
        .padding(.vertical, bodySize * 0.39)
    }

    private func taskList(_ items: [MarkdownListItem]) -> some View {
        let offsets = fragmentOccurrenceOffsets
        let itemFonts = inlineFonts(size: bodySize)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(items.enumerated(), id: \.element.id) { itemIndex, item in
                HStack(alignment: .center, spacing: 0) {
                    Button {
                        onToggleTask(item.id)
                    } label: {
                        Image(systemName: item.isChecked == true ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.isChecked == true ? theme.accent : theme.textSecondary)
                            .font(.system(size: bodySize * 0.95))
                            .contentTransition(.symbolEffect(.replace))
                            .animation(
                                reduceMotion ? nil : .snappy(duration: 0.18),
                                value: item.isChecked
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
                    .accessibilityLabel(item.text)
                    .accessibilityValue(
                        L10n.string(
                            item.isChecked == true
                                ? "reader.task.completed"
                                : "reader.task.incomplete"
                        )
                    )
                    .accessibilityHint(
                        L10n.string(
                            item.isChecked == true
                                ? "reader.task.mark_incomplete_hint"
                                : "reader.task.mark_completed_hint"
                        )
                    )
                    .sensoryFeedback(.selection, trigger: item.isChecked)

                    InlineMarkdownText(
                        source: item.text,
                        fonts: itemFonts,
                        mathFontSize: bodySize,
                        foregroundStyle: theme.textPrimary,
                        theme: theme,
                        searchText: searchText,
                        activeOccurrenceIndex: activeOccurrenceIndex,
                        occurrenceOffset: occurrenceOffset(offsets, itemIndex)
                    )
                    .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
            }
        }
        .padding(.vertical, bodySize * 0.39)
    }

    private func codeBlock(language: String?, source: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(language?.uppercased() ?? L10n.string("reader.code"))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                CodeCopyButton(source: source, theme: theme)
            }
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
        let headerFonts = inlineFonts(size: bodySize * 0.93, weight: .semibold)
        let cellFonts = inlineFonts(size: bodySize * 0.93)
        return ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 0) {
                GridRow {
                    ForEach(headers.enumerated(), id: \.offset) { columnIndex, value in
                        InlineMarkdownText(
                            source: value,
                            fonts: headerFonts,
                            mathFontSize: bodySize * 0.93,
                            foregroundStyle: theme.textStrong,
                            theme: theme,
                            searchText: searchText,
                            activeOccurrenceIndex: activeOccurrenceIndex,
                            occurrenceOffset: occurrenceOffset(offsets, columnIndex)
                        )
                        .padding(.vertical, 12)
                    }
                }
                Divider().overlay(theme.tableStrongRule)
                ForEach(rows.enumerated(), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(row.enumerated(), id: \.offset) { columnIndex, value in
                            InlineMarkdownText(
                                source: value,
                                fonts: cellFonts,
                                mathFontSize: bodySize * 0.93,
                                foregroundStyle: theme.textPrimary,
                                theme: theme,
                                searchText: searchText,
                                activeOccurrenceIndex: activeOccurrenceIndex,
                                occurrenceOffset: occurrenceOffset(
                                    offsets,
                                    headers.count + rowIndex * headers.count + columnIndex
                                )
                            )
                            .padding(.vertical, 12)
                        }
                    }
                    if rowIndex < rows.count - 1 {
                        Divider().overlay(theme.tableRowRule)
                    }
                }
            }
            .overlay(alignment: .top) { Divider().overlay(theme.tableStrongRule) }
            .overlay(alignment: .bottom) { Divider().overlay(theme.tableStrongRule) }
        }
        .scrollIndicators(.hidden)
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
        ContentUnavailableView(
            "reader.image_error_title",
            systemImage: "photo.badge.exclamationmark",
            description: Text(
                alt.isEmpty ? L10n.string("reader.image_error_description") : alt
            )
        )
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(theme.codeFill, in: .rect(cornerRadius: 8))
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
            theme: theme.readerTheme,
            size: size,
            weight: weight
        )
    }

    private func inlineFonts(
        size: Double,
        weight: UIFont.Weight = .regular
    ) -> InlineMarkdownFonts {
        MarkdownTypography.inlineFonts(
            theme: theme.readerTheme,
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
