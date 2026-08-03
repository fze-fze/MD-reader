import Foundation

// A reader annotation: a marked span of text plus an optional note.
//
// Persisted into the Markdown source as `==marked text==` followed by an HTML
// comment carrying everything Markdown itself cannot express:
//
//     A sentence with ==marked text==<!--margin:{"g":"a1b2c3","n":"my note","s":"wavy"}--> in it.
//
// Other editors (Typora, Obsidian) render the `==…==` as an ordinary highlight
// and hide the comment, so a document annotated in Margin degrades cleanly.
nonisolated struct MarginAnnotation: Equatable, Sendable {
    enum Style: String, Equatable, Sendable, CaseIterable, Identifiable {
        case underline
        case wavy
        case circle

        var id: Self { self }
    }

    var style: Style
    var note: String
    // Shared by every piece of one annotation when a selection spans several
    // source lines, and used as the seed for the hand-drawn jitter — so it has
    // to stay stable, or the mark would reshape itself on every redraw.
    var groupID: String

    init(style: Style = .underline, note: String = "", groupID: String = MarginAnnotation.makeGroupID()) {
        self.style = style
        self.note = note
        self.groupID = groupID
    }

    static func makeGroupID() -> String {
        String(UUID().uuidString.prefix(8)).lowercased()
    }
}

nonisolated extension MarginAnnotation {
    static let commentPrefix = "<!--margin:"
    static let commentSuffix = "-->"

    private struct Payload: Codable {
        var s: String
        var n: String?
        var g: String
    }

    var comment: String {
        let payload = Payload(s: style.rawValue, n: note.isEmpty ? nil : note, g: groupID)
        let encoder = JSONEncoder()
        // Stable key order keeps the written source diff-friendly.
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return Self.commentPrefix + json + Self.commentSuffix
    }

    // Parses the JSON body of a `<!--margin:…-->` comment. A malformed body
    // yields nil, which makes the scanner treat the comment as ordinary text
    // rather than silently swallowing it.
    static func parse(commentBody json: String) -> MarginAnnotation? {
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let style = Style(rawValue: payload.s) else {
            return nil
        }
        return MarginAnnotation(style: style, note: payload.n ?? "", groupID: payload.g)
    }
}

// Splits a line of inline Markdown into annotated and unannotated runs.
//
// Mirrors `InlineMathSegmenter`: same memoization shape, same short-circuit
// when the trigger character is absent, and the same rule that inline code
// spans and backslash escapes win over the delimiter.
nonisolated enum AnnotationSegmenter {
    struct Segment: Equatable, Sendable {
        // The text as it should render — for an annotated run this is the
        // content between the `==` markers, with the markers and the trailing
        // comment already removed.
        let text: String
        let annotation: MarginAnnotation?
        // Character offsets into the string that was scanned, spanning the
        // whole construct (markers and comment included).
        let sourceRange: Range<Int>
    }

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: [String: [Segment]] = [:]

    static func segments(in source: String) -> [Segment] {
        guard source.contains("==") else {
            return [Segment(text: source, annotation: nil, sourceRange: 0..<source.count)]
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

    // The rendered text of a line, with every annotation construct reduced to
    // the marked text alone.
    static func strippedText(in source: String) -> String {
        segments(in: source).map(\.text).joined()
    }

    private static func computeSegments(in source: String) -> [Segment] {
        let characters = Array(source)
        var segments: [Segment] = []
        var buffer = ""
        var bufferStart = 0
        var index = 0

        func flushPlain(upTo end: Int) {
            guard !buffer.isEmpty else { return }
            segments.append(
                Segment(text: buffer, annotation: nil, sourceRange: bufferStart..<end)
            )
            buffer = ""
        }

        while index < characters.count {
            let character = characters[index]

            if character == "\\", index + 1 < characters.count {
                buffer.append(character)
                buffer.append(characters[index + 1])
                index += 2
                continue
            }

            if character == "`" {
                let end = InlineScanning.endOfCodeSpan(in: characters, from: index)
                buffer.append(contentsOf: characters[index..<end])
                index = end
                continue
            }

            // Consume any run of "=" whole. Rejecting only the first position of
            // a longer run would let the scanner step forward and match an
            // opener inside it, turning "a ===x=== b" into an annotation.
            if character == "=" {
                let run = InlineScanning.runLength(of: "=", in: characters, from: index)
                if run != 2 {
                    if buffer.isEmpty { bufferStart = index }
                    buffer.append(contentsOf: characters[index..<(index + run)])
                    index += run
                    continue
                }
            }

            if character == "=",
               index + 1 < characters.count,
               characters[index + 1] == "=",
               let close = closingMarker(in: characters, from: index) {
                let content = String(characters[(index + 2)..<close])
                let afterMarker = close + 2
                let parsed = comment(in: characters, from: afterMarker)
                flushPlain(upTo: index)
                bufferStart = parsed?.end ?? afterMarker
                segments.append(
                    Segment(
                        text: content,
                        annotation: parsed?.annotation ?? MarginAnnotation(groupID: derivedGroupID(for: content)),
                        sourceRange: index..<(parsed?.end ?? afterMarker)
                    )
                )
                index = parsed?.end ?? afterMarker
                continue
            }

            if buffer.isEmpty { bufferStart = index }
            buffer.append(character)
            index += 1
        }

        flushPlain(upTo: characters.count)
        return segments.isEmpty
            ? [Segment(text: "", annotation: nil, sourceRange: 0..<0)]
            : segments
    }

    // A bare `==x==` written by another editor carries no group id. Deriving a
    // stable one from the marked text keeps the hand-drawn jitter from
    // reshaping itself between redraws.
    private static func derivedGroupID(for content: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in content.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(hash, radix: 36)
    }

    // Index of the "==" that closes the marker opened at `index`, or nil.
    // Requires non-empty content that neither starts nor ends with whitespace,
    // so a comparison like `a == b` stays literal text.
    private static func closingMarker(in characters: [Character], from index: Int) -> Int? {
        let contentStart = index + 2
        guard contentStart < characters.count,
              !characters[contentStart].isWhitespace else { return nil }

        var cursor = contentStart
        while cursor < characters.count {
            let character = characters[cursor]

            if character == "\\" {
                cursor += 2
                continue
            }
            if character == "`" {
                cursor = InlineScanning.endOfCodeSpan(in: characters, from: cursor)
                continue
            }
            // Annotations never span a line break.
            if character.isNewline { return nil }

            if character == "=" {
                // The closer is exactly "==" too — a longer run is literal text.
                let run = InlineScanning.runLength(of: "=", in: characters, from: cursor)
                if run == 2 {
                    guard cursor > contentStart, !characters[cursor - 1].isWhitespace else { return nil }
                    return cursor
                }
                cursor += run
                continue
            }
            cursor += 1
        }
        return nil
    }

    // Parses a `<!--margin:{…}-->` comment sitting immediately after a closing
    // marker. Returns nil when there is no comment or its body is malformed.
    private static func comment(
        in characters: [Character],
        from index: Int
    ) -> (annotation: MarginAnnotation, end: Int)? {
        let prefix = Array(MarginAnnotation.commentPrefix)
        let suffix = Array(MarginAnnotation.commentSuffix)
        guard index + prefix.count <= characters.count,
              Array(characters[index..<(index + prefix.count)]) == prefix else { return nil }

        var cursor = index + prefix.count
        while cursor + suffix.count <= characters.count {
            if Array(characters[cursor..<(cursor + suffix.count)]) == suffix {
                let body = String(characters[(index + prefix.count)..<cursor])
                guard let annotation = MarginAnnotation.parse(commentBody: body) else { return nil }
                return (annotation, cursor + suffix.count)
            }
            cursor += 1
        }
        return nil
    }
}
