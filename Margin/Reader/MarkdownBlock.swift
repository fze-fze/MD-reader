import Foundation
import SwiftUI

nonisolated struct MarkdownBlock: Identifiable, Equatable, Sendable {
    // 0-based index of the block's first source line. Outline jumps and task
    // toggling both key off this, so it must stay a line index.
    let id: Int
    let kind: Kind
    // Every source line the block was built from. A paragraph joins its lines
    // with " ", so writing an annotation back needs the full span, not just
    // the first line.
    let sourceLines: Range<Int>

    init(id: Int, kind: Kind, sourceLines: Range<Int>? = nil) {
        self.id = id
        self.kind = kind
        self.sourceLines = sourceLines ?? (id..<(id + 1))
    }

    enum Kind: Equatable, Sendable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case blockquote(String)
        case unorderedList([MarkdownListItem])
        case orderedList([MarkdownListItem])
        case taskList([MarkdownListItem])
        case code(language: String?, source: String)
        case math(source: String)
        case table(headers: [String], rows: [[String]])
        case image(alt: String, source: String)
        case frontMatter(String)
        case divider
    }

    var searchableText: String {
        searchableFragments.joined(separator: " ")
    }

    var searchableFragments: [String] {
        switch kind {
        case let .heading(_, text), let .paragraph(text), let .blockquote(text):
            [Self.inlinePlainText(text)]
        case let .frontMatter(text):
            [text]
        case let .unorderedList(items), let .orderedList(items), let .taskList(items):
            items.map { Self.inlinePlainText($0.text) }
        case let .code(_, source), let .math(source):
            [source]
        case let .table(headers, rows):
            (headers + rows.flatMap { $0 }).map(Self.inlinePlainText)
        case let .image(alt, _):
            alt.isEmpty ? [] : [Self.inlinePlainText(alt)]
        case .divider:
            []
        }
    }

    // Where in the block a search occurrence sits, as a scroll anchor, for
    // blocks long enough to outgrow the screen: aligning that point with the
    // same point of the viewport shows the match rather than the block's
    // middle. Nil for a block short enough to show whole.
    func scrollAnchor(forOccurrence occurrenceIndex: Int, query: String) -> UnitPoint? {
        let fragments = searchableFragments
        let total = fragments.reduce(0) { $0 + $1.count }
        let lineCount = fragments.reduce(0) { $0 + $1.split(whereSeparator: \.isNewline).count }
        guard total > 600 || lineCount > 12 else { return nil }

        var seen = 0
        var preceding = 0
        for fragment in fragments {
            let ranges = DocumentSearchMatcher.ranges(in: fragment, query: query)
            if occurrenceIndex < seen + ranges.count {
                let offset = fragment.distance(
                    from: fragment.startIndex,
                    to: ranges[occurrenceIndex - seen].lowerBound
                )
                return UnitPoint(x: 0.5, y: Double(preceding + offset) / Double(max(total, 1)))
            }
            seen += ranges.count
            preceding += fragment.count
        }
        return nil
    }

    // Search matches what the reader draws, so annotation markers and their
    // comments are stripped alongside the rest of the inline syntax, and each
    // inline formula collapses to U+FFFC. The placeholder blocks queries from
    // matching across a formula seam, keeping index match counts aligned with
    // the per-segment highlighting the reader can actually draw.
    private static func inlinePlainText(_ source: String) -> String {
        InlinePlainText.render(source)
    }
}

nonisolated struct MarkdownListItem: Identifiable, Equatable, Sendable {
    let id: Int
    let text: String
    let isChecked: Bool?
    // Nesting depth, 0 for a top-level item.
    let level: Int
    // The number an ordered item is drawn with; nil for bullets and tasks.
    let ordinal: Int?

    init(id: Int, text: String, isChecked: Bool?, level: Int = 0, ordinal: Int? = nil) {
        self.id = id
        self.text = text
        self.isChecked = isChecked
        self.level = level
        self.ordinal = ordinal
    }
}

nonisolated struct MarkdownHeading: Identifiable, Equatable, Sendable {
    let id: Int
    let level: Int
    let text: String
}
