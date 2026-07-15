import SwiftUI
import UIKit

struct MarkdownReaderView: View {
    let source: String
    let searchText: String
    @Binding var scrollTarget: Int?
    let textScale: Double
    let baseURL: URL?
    let readerTheme: ReaderTheme
    let onToggleTask: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    @State private var currentMatchIndex = 0
    @State private var blocks: [MarkdownBlock] = []
    @State private var searchIndex = DocumentSearchIndex()
    @State private var searchMatches: [DocumentSearchIndex.Match] = []
    @State private var contentRevision = 0

    private var theme: MarkdownTheme {
        MarkdownTheme(readerTheme: readerTheme, colorScheme: colorScheme)
    }
    private var searchRequest: SearchRequest {
        SearchRequest(contentRevision: contentRevision, query: searchText)
    }
    private var activeMatch: DocumentSearchIndex.Match? {
        guard searchMatches.indices.contains(currentMatchIndex) else { return nil }
        return searchMatches[currentMatchIndex]
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(blocks) { block in
                        MarkdownBlockView(
                            block: block,
                            bodySize: bodySize * textScale,
                            theme: theme,
                            baseURL: baseURL,
                            searchText: searchText,
                            activeOccurrenceIndex: activeMatch?.blockID == block.id
                                ? activeMatch?.occurrenceIndex
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
                searchIndex = result.1
                contentRevision &+= 1
            }
            .task(id: searchRequest) {
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else {
                    searchMatches = []
                    currentMatchIndex = 0
                    return
                }

                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }

                let indexSnapshot = searchIndex
                let matches = await Task.detached(priority: .userInitiated) {
                    indexSnapshot.matches(for: query)
                }.value
                guard !Task.isCancelled else { return }

                searchMatches = matches
                currentMatchIndex = 0
                scrollToCurrentMatch(using: proxy)
            }
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.snappy) {
                    proxy.scrollTo(target, anchor: .top)
                }
                scrollTarget = nil
            }
            .overlay(alignment: .bottom) {
                if !searchText.isEmpty {
                    SearchMatchBadge(
                        count: searchMatches.count,
                        current: searchMatches.isEmpty ? 0 : currentMatchIndex + 1,
                        onPrevious: {
                            guard !searchMatches.isEmpty else { return }
                            currentMatchIndex = (currentMatchIndex - 1 + searchMatches.count) % searchMatches.count
                            scrollToCurrentMatch(using: proxy)
                        },
                        onNext: {
                            guard !searchMatches.isEmpty else { return }
                            currentMatchIndex = (currentMatchIndex + 1) % searchMatches.count
                            scrollToCurrentMatch(using: proxy)
                        }
                    )
                        .padding(.bottom, 12)
                }
            }
        }
    }

    private func scrollToCurrentMatch(using proxy: ScrollViewProxy) {
        guard searchMatches.indices.contains(currentMatchIndex) else { return }
        withAnimation(.snappy) {
            proxy.scrollTo(searchMatches[currentMatchIndex].blockID, anchor: .center)
        }
    }
}

private struct SearchRequest: Equatable {
    let contentRevision: Int
    let query: String
}

private struct SearchMatchBadge: View {
    let count: Int
    let current: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Text(count == 0 ? "没有匹配项" : "\(current) / \(count)")
                .font(.footnote.monospacedDigit())
                .padding(.horizontal, 8)
            Button("上一个匹配项", systemImage: "chevron.up", action: onPrevious)
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(count == 0)
            Button("下一个匹配项", systemImage: "chevron.down", action: onNext)
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(count == 0)
        }
        .padding(.horizontal, 12)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityAddTraits(.updatesFrequently)
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
                font: documentFont(size: bodySize),
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
            font: documentFont(size: bodySize * multiplier, weight: .semibold),
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
                font: documentFont(size: bodySize),
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
        .accessibilityLabel("引用：\(text)")
    }

    private func list(_ items: [MarkdownListItem], ordered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(items.enumerated(), id: \.element.id) { itemIndex, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(ordered ? "\(itemIndex + 1)." : "•")
                        .font(documentFont(size: bodySize))
                        .foregroundStyle(theme.textSecondary)
                        .frame(minWidth: 20, alignment: .trailing)
                    InlineMarkdownText(
                        source: item.text,
                        font: documentFont(size: bodySize),
                        foregroundStyle: theme.textPrimary,
                        theme: theme,
                        searchText: searchText,
                        activeOccurrenceIndex: activeOccurrenceIndex,
                        occurrenceOffset: occurrenceOffset(for: itemIndex)
                    )
                    .lineSpacing(bodySize * 0.38)
                }
            }
        }
        .padding(.leading, 2)
        .padding(.vertical, bodySize * 0.39)
    }

    private func taskList(_ items: [MarkdownListItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
                    .accessibilityValue(item.isChecked == true ? "已完成" : "未完成")
                    .accessibilityHint(item.isChecked == true ? "轻点标记为未完成" : "轻点标记为已完成")
                    .sensoryFeedback(.selection, trigger: item.isChecked)

                    InlineMarkdownText(
                        source: item.text,
                        font: documentFont(size: bodySize),
                        foregroundStyle: theme.textPrimary,
                        theme: theme,
                        searchText: searchText,
                        activeOccurrenceIndex: activeOccurrenceIndex,
                        occurrenceOffset: occurrenceOffset(for: itemIndex)
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
                Text(language?.uppercased() ?? "代码")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("复制", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = source
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(theme.textSecondary)
                .frame(minWidth: 44, minHeight: 44)
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
        .accessibilityLabel(language.map { "\($0) 代码块" } ?? "代码块")
    }

    private func table(headers: [String], rows: [[String]]) -> some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 0) {
                GridRow {
                    ForEach(headers.enumerated(), id: \.offset) { columnIndex, value in
                        InlineMarkdownText(
                            source: value,
                            font: documentFont(size: bodySize * 0.93, weight: .semibold),
                            foregroundStyle: theme.textStrong,
                            theme: theme,
                            searchText: searchText,
                            activeOccurrenceIndex: activeOccurrenceIndex,
                            occurrenceOffset: occurrenceOffset(for: columnIndex)
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
                                font: documentFont(size: bodySize * 0.93),
                                foregroundStyle: theme.textPrimary,
                                theme: theme,
                                searchText: searchText,
                                activeOccurrenceIndex: activeOccurrenceIndex,
                                occurrenceOffset: occurrenceOffset(
                                    for: headers.count + rowIndex * headers.count + columnIndex
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
        .accessibilityLabel("表格，\(headers.count) 列，\(rows.count) 行")
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
            .accessibilityLabel("文档元数据：\(source)")
    }

    @ViewBuilder
    private func markdownImage(alt: String, source: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if let url = URL(string: source), ["http", "https"].contains(url.scheme?.lowercased()) {
                AsyncImage(url: url) { phase in
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
            } else if let image = localImage(source: source) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
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
        .accessibilityLabel(alt.isEmpty ? "文档图片" : alt)
    }

    private func imagePlaceholder(alt: String) -> some View {
        ContentUnavailableView(
            "无法载入图片",
            systemImage: "photo.badge.exclamationmark",
            description: Text(alt.isEmpty ? "请检查图片路径。" : alt)
        )
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(theme.codeFill, in: .rect(cornerRadius: 8))
    }

    private func localImage(source: String) -> UIImage? {
        guard let baseURL else { return nil }
        let path = source.removingPercentEncoding ?? source
        return UIImage(contentsOfFile: baseURL.appending(path: path).standardizedFileURL.path())
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

    private func occurrenceOffset(for fragmentIndex: Int) -> Int {
        guard fragmentIndex > 0 else { return 0 }
        return block.searchableFragments.prefix(fragmentIndex).reduce(into: 0) { count, fragment in
            count += DocumentSearchMatcher.ranges(in: fragment, query: searchText).count
        }
    }
}
