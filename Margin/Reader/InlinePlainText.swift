import Foundation

// The characters a line of inline Markdown actually renders as, and where each
// of them came from in the source.
//
// The reader draws `InlineMarkdownStyler`'s output, whose characters are
// exactly `AttributedString(markdown:.inlineOnlyPreservingWhitespace)` applied
// per segment — so `render` reproduces the rendered character sequence, and
// `map` says which source characters produced each one. Writing an annotation
// back into the source is the only caller of `map`, so its cost lands on a
// user action rather than on the render path.
nonisolated enum InlinePlainText {
    // Source characters behind one rendered character.
    struct Mapping: Equatable, Sendable {
        let start: Int
        let end: Int
    }

    static func render(_ source: String) -> String {
        AnnotationSegmenter.segments(in: source).map { segment in
            InlineMathSegmenter.segments(in: segment.text).map { mathSegment in
                switch mathSegment {
                case let .text(part):
                    // Inline math renders as an image, so it becomes U+FFFC —
                    // one rendered character, matching the text attachment the
                    // reader draws and keeping search offsets aligned.
                    strippedMarkdown(part)
                case .math:
                    "\u{FFFC}"
                }
            }.joined()
        }.joined()
    }

    // One entry per rendered character. A rendered range a..<b covers the
    // source range map[a].start..<map[b - 1].end.
    static func map(_ source: String) -> [Mapping] {
        var mappings: [Mapping] = []

        for segment in AnnotationSegmenter.segments(in: source) {
            // For an annotated run the text starts after the opening "==".
            let textStart = segment.annotation == nil
                ? segment.sourceRange.lowerBound
                : segment.sourceRange.lowerBound + 2

            for ranged in InlineMathSegmenter.rangedSegments(in: segment.text) {
                let base = textStart + ranged.sourceRange.lowerBound
                switch ranged.segment {
                case let .text(part):
                    mappings.append(contentsOf: align(part, base: base))
                case .math:
                    mappings.append(
                        Mapping(start: base, end: textStart + ranged.sourceRange.upperBound)
                    )
                }
            }
        }
        return mappings
    }

    // Inline Markdown rendering only ever *deletes* characters (`**`, backticks,
    // link destinations, escape backslashes), so the rendered text is a
    // subsequence of the source. Walking the two in lockstep and skipping
    // whatever the renderer dropped therefore recovers the alignment exactly —
    // and, unlike re-parsing prefixes, it can never disagree with the parse the
    // reader actually drew.
    private static func align(_ part: String, base: Int) -> [Mapping] {
        let sourceCharacters = Array(part)
        let plainCharacters = Array(strippedMarkdown(part))

        var mappings: [Mapping] = []
        var cursor = 0

        for character in plainCharacters {
            var probe = cursor
            while probe < sourceCharacters.count, sourceCharacters[probe] != character {
                probe += 1
            }
            if probe < sourceCharacters.count {
                mappings.append(Mapping(start: base + probe, end: base + probe + 1))
                cursor = probe + 1
            } else {
                // A rendered character with no source counterpart (a
                // substitution rather than a deletion). Anchor it at the
                // cursor and keep the cursor put so the rest stays in sync.
                mappings.append(Mapping(start: base + cursor, end: base + cursor))
            }
        }
        return mappings
    }

    static func strippedMarkdown(_ source: String) -> String {
        guard let attributed = try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) else {
            return source
        }
        return String(attributed.characters)
    }
}
