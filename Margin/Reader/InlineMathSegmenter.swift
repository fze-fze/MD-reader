import Foundation

nonisolated enum InlineMathSegmenter {
    enum Segment: Equatable, Sendable {
        case text(String)
        case math(latex: String, isDisplay: Bool)
    }

    // Inline math is $…$ only; display $$ is a block-level construct handled
    // by MarkdownParser, so a mid-sentence $$ stays literal text.
    static func segments(in source: String) -> [Segment] {
        guard source.contains("$") else {
            return [.text(source)]
        }

        let characters = Array(source)
        var segments: [Segment] = []
        var textBuffer = ""
        var index = 0

        func flushText() {
            guard !textBuffer.isEmpty else { return }
            segments.append(.text(textBuffer))
            textBuffer = ""
        }

        while index < characters.count {
            let character = characters[index]

            if character == "\\", index + 1 < characters.count {
                // Escapes (\$, \\, …) stay literal text.
                textBuffer.append(character)
                textBuffer.append(characters[index + 1])
                index += 2
                continue
            }

            // Inline code spans win over math: `$x` is code, not a formula.
            if character == "`" {
                let fenceLength = runLength(of: "`", in: characters, from: index)
                if let close = closingBacktickRun(length: fenceLength, in: characters, from: index + fenceLength) {
                    textBuffer.append(contentsOf: characters[index..<(close + fenceLength)])
                    index = close + fenceLength
                } else {
                    textBuffer.append(contentsOf: characters[index..<(index + fenceLength)])
                    index += fenceLength
                }
                continue
            }

            if character == "$" {
                if index + 1 < characters.count, characters[index + 1] == "$" {
                    textBuffer.append("$$")
                    index += 2
                    continue
                }

                if let close = closingSingleDollar(in: characters, from: index) {
                    flushText()
                    segments.append(.math(
                        latex: trimmedLatex(characters[(index + 1)..<close]),
                        isDisplay: false
                    ))
                    index = close + 1
                    continue
                }
            }

            textBuffer.append(character)
            index += 1
        }

        flushText()
        return segments.isEmpty ? [.text("")] : segments
    }

    private static func trimmedLatex(_ slice: ArraySlice<Character>) -> String {
        String(slice).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runLength(of character: Character, in characters: [Character], from index: Int) -> Int {
        var length = 0
        while index + length < characters.count, characters[index + length] == character {
            length += 1
        }
        return length
    }

    private static func closingBacktickRun(length: Int, in characters: [Character], from index: Int) -> Int? {
        var cursor = index
        while cursor < characters.count {
            if characters[cursor] == "`" {
                let run = runLength(of: "`", in: characters, from: cursor)
                if run == length { return cursor }
                cursor += run
            } else {
                cursor += 1
            }
        }
        return nil
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
