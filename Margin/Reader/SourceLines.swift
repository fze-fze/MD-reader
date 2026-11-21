import Foundation

// Splits a document into lines while remembering each line's terminator, so a
// rewritten document keeps whatever line endings it arrived with.
//
// Line numbering matches `MarkdownParser`: both split by `Character`, and
// Swift folds CRLF into a single grapheme, so "a\r\nb" is two lines and the
// first one remembers "\r\n" as its terminator.
nonisolated enum SourceLines {
    struct Line: Equatable, Sendable {
        var text: String
        var terminator: String
    }

    static func split(_ source: String) -> [Line] {
        var lines: [Line] = []

        var lineStart = source.startIndex
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]
            let next = source.index(after: index)
            if character.isNewline {
                lines.append(Line(text: String(source[lineStart..<index]), terminator: String(character)))
                lineStart = next
            }
            index = next
        }
        lines.append(Line(text: String(source[lineStart...]), terminator: ""))
        return lines
    }

    // UTF-16 offset of the first character of `line` (clamped to the end of
    // the document) — the unit UITextView measures selections in.
    static func utf16Offset(ofLine line: Int, in source: String) -> Int {
        guard line > 0 else { return 0 }
        var offset = 0
        var current = 0
        for character in source {
            offset += character.utf16.count
            if character.isNewline {
                current += 1
                if current == line { return offset }
            }
        }
        return offset
    }

    // The line holding the character at `utf16Offset`.
    static func lineIndex(atUTF16Offset utf16Offset: Int, in source: String) -> Int {
        var offset = 0
        var line = 0
        for character in source {
            let next = offset + character.utf16.count
            if next > utf16Offset { break }
            offset = next
            if character.isNewline { line += 1 }
        }
        return line
    }

    static func join(_ lines: [Line]) -> String {
        lines.reduce(into: "") { result, line in
            result += line.text + line.terminator
        }
    }
}
