import Foundation

nonisolated enum InlineMathSegmenter {
    enum Segment: Equatable, Sendable {
        case text(String)
        case math(latex: String, isDisplay: Bool)
    }

    // A segment together with the character offsets it occupies in the scanned
    // string. Mapping a rendered offset back to a source offset needs the
    // ranges; rendering only needs the segments.
    struct RangedSegment: Equatable, Sendable {
        let segment: Segment
        let sourceRange: Range<Int>
    }

    // Segmenting copies the string into an array and scans it. The reader
    // re-runs it on every body evaluation of every visible block, so memoize
    // the pure result. Text without a "$" short-circuits before the lock,
    // which is the overwhelmingly common case.
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: [String: [RangedSegment]] = [:]

    // Inline math is $…$ only; display $$ is a block-level construct handled
    // by MarkdownParser, so a mid-sentence $$ stays literal text.
    static func segments(in source: String) -> [Segment] {
        rangedSegments(in: source).map(\.segment)
    }

    static func rangedSegments(in source: String) -> [RangedSegment] {
        guard source.contains("$") else {
            return [RangedSegment(segment: .text(source), sourceRange: 0..<source.count)]
        }

        if let cached = cacheLock.withLock({ cache[source] }) {
            return cached
        }

        let segments = computeSegments(in: source)
        cacheLock.withLock {
            if cache.count > 500 {
                cache.removeAll(keepingCapacity: true)
            }
            cache[source] = segments
        }
        return segments
    }

    static func purgeCache() {
        cacheLock.withLock { cache.removeAll() }
    }

    private static func computeSegments(in source: String) -> [RangedSegment] {
        let characters = Array(source)
        var segments: [RangedSegment] = []
        var textBuffer = ""
        var textStart = 0
        var index = 0

        func flushText(upTo end: Int) {
            guard !textBuffer.isEmpty else { return }
            segments.append(
                RangedSegment(segment: .text(textBuffer), sourceRange: textStart..<end)
            )
            textBuffer = ""
        }

        while index < characters.count {
            let character = characters[index]
            if textBuffer.isEmpty { textStart = index }

            if character == "\\", index + 1 < characters.count {
                // Escapes (\$, \\, …) stay literal text.
                textBuffer.append(character)
                textBuffer.append(characters[index + 1])
                index += 2
                continue
            }

            // Inline code spans win over math: `$x` is code, not a formula.
            if character == "`" {
                let end = InlineScanning.endOfCodeSpan(in: characters, from: index)
                textBuffer.append(contentsOf: characters[index..<end])
                index = end
                continue
            }

            if character == "$" {
                if index + 1 < characters.count, characters[index + 1] == "$" {
                    textBuffer.append("$$")
                    index += 2
                    continue
                }

                if let close = closingSingleDollar(in: characters, from: index) {
                    flushText(upTo: index)
                    segments.append(
                        RangedSegment(
                            segment: .math(
                                latex: trimmedLatex(characters[(index + 1)..<close]),
                                isDisplay: false
                            ),
                            sourceRange: index..<(close + 1)
                        )
                    )
                    index = close + 1
                    continue
                }
            }

            textBuffer.append(character)
            index += 1
        }

        flushText(upTo: characters.count)
        return segments.isEmpty
            ? [RangedSegment(segment: .text(""), sourceRange: 0..<0)]
            : segments
    }

    private static func trimmedLatex(_ slice: ArraySlice<Character>) -> String {
        String(slice).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Pandoc-style heuristics keep prices like "$5 和 $10" out of math mode:
    // the opening $ must be followed by a non-space, the closing $ must be
    // preceded by a non-space and not followed by a digit, and the span must
    // stay on one line.
    private static func closingSingleDollar(in characters: [Character], from index: Int) -> Int? {
        guard index + 1 < characters.count else { return nil }
        let first = characters[index + 1]
        guard !first.isWhitespace, first != "$" else { return nil }

        var cursor = index + 1
        while cursor < characters.count {
            let character = characters[cursor]
            if character == "\\" {
                cursor += 2
                continue
            }
            if character == "\n" { return nil }
            if character == "$" {
                guard cursor > index + 1 else { return nil }
                let before = characters[cursor - 1]
                guard !before.isWhitespace else { return nil }
                if cursor + 1 < characters.count, characters[cursor + 1].isNumber { return nil }
                return cursor
            }
            cursor += 1
        }
        return nil
    }
}
