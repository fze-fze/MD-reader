import Foundation

nonisolated enum MarkdownTaskToggler {
    static func toggledSource(_ source: String, taskAtLine lineNumber: Int) -> String {
        guard lineNumber >= 0 else { return source }

        let sourceText = source as NSString
        guard let lineRange = contentRange(
            at: lineNumber,
            in: sourceText
        ), let markerLocation = taskMarkerLocation(
            in: sourceText,
            lineRange: lineRange
        ) else {
            return source
        }

        let updated = NSMutableString(string: source)
        let marker = sourceText.character(at: markerLocation)
        updated.replaceCharacters(
            in: NSRange(location: markerLocation, length: 1),
            with: marker == 0x20 ? "x" : " "
        )
        return updated as String
    }

    private static func contentRange(at targetLine: Int, in source: NSString) -> NSRange? {
        var currentLine = 0
        var lineStart = 0

        for location in 0...source.length {
            let isBoundary = location == source.length
                || isNewline(source.character(at: location))

            guard isBoundary else { continue }
            if currentLine == targetLine {
                return NSRange(location: lineStart, length: location - lineStart)
            }
            currentLine += 1
            lineStart = location + 1
        }

        return nil
    }

    private static func taskMarkerLocation(in source: NSString, lineRange: NSRange) -> Int? {
        let lineEnd = NSMaxRange(lineRange)
        var cursor = lineRange.location

        while cursor < lineEnd, isHorizontalWhitespace(source.character(at: cursor)) {
            cursor += 1
        }

        guard cursor < lineEnd, [0x2D, 0x2A, 0x2B].contains(source.character(at: cursor)) else {
            return nil
        }
        cursor += 1

        guard cursor < lineEnd, isHorizontalWhitespace(source.character(at: cursor)) else {
            return nil
        }
        while cursor < lineEnd, isHorizontalWhitespace(source.character(at: cursor)) {
            cursor += 1
        }

        guard cursor + 2 < lineEnd,
              source.character(at: cursor) == 0x5B,
              [0x20, 0x58, 0x78].contains(source.character(at: cursor + 1)),
              source.character(at: cursor + 2) == 0x5D else {
            return nil
        }

        return cursor + 1
    }

    private static func isHorizontalWhitespace(_ character: unichar) -> Bool {
        character == 0x20 || character == 0x09
    }

    private static func isNewline(_ character: unichar) -> Bool {
        [0x000A, 0x000B, 0x000C, 0x000D, 0x0085, 0x2028, 0x2029].contains(character)
    }
}
