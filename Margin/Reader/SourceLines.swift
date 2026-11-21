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

    static func join(_ lines: [Line]) -> String {
        lines.reduce(into: "") { result, line in
            result += line.text + line.terminator
        }
    }
}
