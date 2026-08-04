import Foundation

// Splits a document into lines while remembering each line's terminator, so a
// rewritten document keeps whatever line endings it arrived with.
//
// Line numbering matches `MarkdownParser`, which splits with
// `components(separatedBy: .newlines)` — that treats CR and LF as separate
// separators, so "a\r\nb" is three lines, the middle one empty. Splitting by
// unicode scalar reproduces that exactly; splitting by `Character` would not,
// because Swift folds CRLF into a single grapheme.
nonisolated enum SourceLines {
    struct Line: Equatable, Sendable {
        var text: String
        var terminator: String
    }

    static func split(_ source: String) -> [Line] {
        var lines: [Line] = []
        var current = ""

        for scalar in source.unicodeScalars {
            if CharacterSet.newlines.contains(scalar) {
                lines.append(Line(text: current, terminator: String(scalar)))
                current = ""
            } else {
                current.unicodeScalars.append(scalar)
            }
        }
        lines.append(Line(text: current, terminator: ""))
        return lines
    }

    static func join(_ lines: [Line]) -> String {
        lines.reduce(into: "") { result, line in
            result += line.text + line.terminator
        }
    }
}
