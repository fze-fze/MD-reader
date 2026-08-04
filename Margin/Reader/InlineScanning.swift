import Foundation

// Small primitives shared by the inline scanners (math, annotations). Both
// need to step over code spans verbatim, because a delimiter inside `…` is
// literal text rather than syntax.
nonisolated enum InlineScanning {
    static func runLength(
        of character: Character,
        in characters: [Character],
        from index: Int
    ) -> Int {
        var length = 0
        while index + length < characters.count, characters[index + length] == character {
            length += 1
        }
        return length
    }

    // Index of the backtick run that closes a run of the same length, or nil
    // when the span never closes.
    static func closingBacktickRun(
        length: Int,
        in characters: [Character],
        from index: Int
    ) -> Int? {
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

    // Advances past a code span starting at `index`, returning the index just
    // after it. For an unterminated span only the opening run is consumed, so
    // the delimiters fall back to literal text.
    static func endOfCodeSpan(in characters: [Character], from index: Int) -> Int {
        let fenceLength = runLength(of: "`", in: characters, from: index)
        guard let close = closingBacktickRun(
            length: fenceLength,
            in: characters,
            from: index + fenceLength
        ) else {
            return index + fenceLength
        }
        return close + fenceLength
    }
}
