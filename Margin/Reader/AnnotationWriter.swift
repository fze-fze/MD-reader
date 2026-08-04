import Foundation

// Writes annotations back into the Markdown source.
//
// The reader hands over a range in *rendered* coordinates — what the user
// actually selected — and this maps it onto source characters via
// `InlinePlainText.map`, then splices the `==` markers and the `<!--margin:-->`
// comment in around it. Every entry point returns nil when the edit cannot be
// made safely, so a rejected edit leaves the document untouched rather than
// producing broken syntax.
nonisolated enum AnnotationWriter {
    // Where a fragment's rendered text lives in the source: the lines it spans,
    // and how those lines are stitched together.
    struct Fragment: Equatable, Sendable {
        let lines: [Int]
        // The character the parser joins the lines with — " " for paragraphs,
        // "\n" for blockquotes. Single-line fragments ignore it.
        let joiner: String
        // Block markers the parser strips before rendering ("## ", "- [x] ",
        // "> "), so the writer can skip them when mapping offsets.
        let kind: MarkdownBlock.Kind

        init(lines: [Int], joiner: String = " ", kind: MarkdownBlock.Kind) {
            self.lines = lines
            self.joiner = joiner
            self.kind = kind
        }
    }

    static func inserting(
        _ annotation: MarginAnnotation,
        into source: String,
        fragment: Fragment,
        renderedRange: Range<Int>
    ) -> String? {
        guard !renderedRange.isEmpty else { return nil }

        var lines = SourceLines.split(source)
        guard let pieces = sourcePieces(
            for: renderedRange,
            fragment: fragment,
            lines: lines
        ) else { return nil }

        // Splicing into a range that already carries a marker would nest the
        // syntax; reject instead of corrupting the line.
        for piece in pieces where overlapsExistingAnnotation(piece, in: lines) {
            return nil
        }

        let comment = annotation.comment
        // Apply back to front so earlier offsets stay valid.
        for piece in pieces.reversed() {
            var characters = Array(lines[piece.line].text)
            characters.insert(contentsOf: Array("==" + comment), at: piece.range.upperBound)
            characters.insert(contentsOf: Array("=="), at: piece.range.lowerBound)
            lines[piece.line].text = String(characters)
        }
        return SourceLines.join(lines)
    }

    static func updating(
        groupID: String,
        style: MarginAnnotation.Style,
        note: String,
        in source: String
    ) -> String? {
        rewrite(groupID: groupID, in: source) { segment in
            let updated = MarginAnnotation(style: style, note: note, groupID: groupID)
            return "==" + segment.text + "==" + updated.comment
        }
    }

    static func removing(groupID: String, from source: String) -> String? {
        rewrite(groupID: groupID, in: source) { segment in segment.text }
    }

    // MARK: - Rendered range → source pieces

    private struct Piece: Equatable {
        let line: Int
        let range: Range<Int>
    }

    private static func sourcePieces(
        for renderedRange: Range<Int>,
        fragment: Fragment,
        lines: [SourceLines.Line]
    ) -> [Piece]? {
        var pieces: [Piece] = []
        var cursor = 0

        for lineIndex in fragment.lines {
            guard lines.indices.contains(lineIndex) else { return nil }

            let raw = lines[lineIndex].text
            let contentStart = contentOffset(in: raw, kind: fragment.kind)
            let content = trimmingTrailingWhitespace(String(Array(raw).dropFirst(contentStart)))
            let map = InlinePlainText.map(content)

            let lineRange = cursor..<(cursor + map.count)
            let lower = max(renderedRange.lowerBound, lineRange.lowerBound)
            let upper = min(renderedRange.upperBound, lineRange.upperBound)

            if lower < upper {
                let localStart = lower - cursor
                let localEnd = upper - cursor
                pieces.append(
                    Piece(
                        line: lineIndex,
                        range: (contentStart + map[localStart].start)..<(contentStart + map[localEnd - 1].end)
                    )
                )
            }
            // The joiner the parser inserted between lines counts as one
            // rendered character.
            cursor += map.count + 1
        }

        return pieces.isEmpty ? nil : pieces
    }

    private static func overlapsExistingAnnotation(
        _ piece: Piece,
        in lines: [SourceLines.Line]
    ) -> Bool {
        AnnotationSegmenter.segments(in: lines[piece.line].text).contains { segment in
            segment.annotation != nil
                && segment.sourceRange.lowerBound < piece.range.upperBound
                && piece.range.lowerBound < segment.sourceRange.upperBound
        }
    }

    // MARK: - Rewriting an existing annotation

    private static func rewrite(
        groupID: String,
        in source: String,
        replacement: (AnnotationSegmenter.Segment) -> String
    ) -> String? {
        var lines = SourceLines.split(source)
        var changed = false

        for index in lines.indices {
            let segments = AnnotationSegmenter.segments(in: lines[index].text)
            guard segments.contains(where: { $0.annotation?.groupID == groupID }) else { continue }

            var rebuilt = ""
            for segment in segments {
                if segment.annotation?.groupID == groupID {
                    rebuilt += replacement(segment)
                } else {
                    let characters = Array(lines[index].text)
                    rebuilt += String(characters[segment.sourceRange])
                }
            }
            lines[index].text = rebuilt
            changed = true
        }

        return changed ? SourceLines.join(lines) : nil
    }

    // MARK: - Block markers

    // Characters at the head of a line that the parser strips before the text
    // is rendered. Mirrors `MarkdownParser.heading(from:)` and
    // `MarkdownParser.listItem(from:)`.
    static func contentOffset(in line: String, kind: MarkdownBlock.Kind) -> Int {
        let characters = Array(line)
        var cursor = 0

        func skipHorizontalWhitespace() {
            while cursor < characters.count, characters[cursor] == " " || characters[cursor] == "\t" {
                cursor += 1
            }
        }

        skipHorizontalWhitespace()

        switch kind {
        case .heading:
            let hashes = characters[cursor...].prefix { $0 == "#" }.count
            guard (1...6).contains(hashes),
                  cursor + hashes < characters.count,
                  characters[cursor + hashes] == " " else { return cursor }
            cursor += hashes + 1

        case .blockquote:
            guard cursor < characters.count, characters[cursor] == ">" else { return cursor }
            cursor += 1
            skipHorizontalWhitespace()

        case .unorderedList, .taskList:
            guard cursor + 1 < characters.count,
                  ["-", "*", "+"].contains(characters[cursor]),
                  characters[cursor + 1] == " " else { return cursor }
            cursor += 2
            // "- [x] " — the checkbox is not part of the rendered text.
            if cursor + 3 < characters.count,
               characters[cursor] == "[",
               [" ", "x", "X"].contains(characters[cursor + 1]),
               characters[cursor + 2] == "]",
               characters[cursor + 3] == " " {
                cursor += 4
            }

        case .orderedList:
            var probe = cursor
            while probe < characters.count, characters[probe].isNumber { probe += 1 }
            guard probe > cursor,
                  probe + 1 < characters.count,
                  characters[probe] == ".",
                  characters[probe + 1] == " " else { return cursor }
            cursor = probe + 2

        default:
            break
        }

        return cursor
    }

    private static func trimmingTrailingWhitespace(_ value: String) -> String {
        var characters = Array(value)
        while let last = characters.last, last == " " || last == "\t" {
            characters.removeLast()
        }
        return String(characters)
    }
}
