import Foundation

nonisolated struct LiveMarkdownDocument: Sendable {
    struct Row: Identifiable, Sendable {
        let id: Int
        let range: NSRange
        let block: MarkdownBlock?
    }

    let rows: [Row]

    init(source: String) {
        let lines = SourceLines.split(source)
        var offset = 0
        let ranges = lines.map { line in
            let range = NSRange(location: offset, length: line.text.utf16.count)
            offset = NSMaxRange(range) + line.terminator.utf16.count
            return range
        }
        var rows: [Row] = []
        var line = 0

        func append(_ lineRange: Range<Int>, block: MarkdownBlock?) {
            guard let last = lineRange.last else { return }
            let start = ranges[lineRange.lowerBound].location
            rows.append(Row(
                id: lineRange.lowerBound,
                range: NSRange(location: start, length: NSMaxRange(ranges[last]) - start),
                block: block
            ))
        }

        for block in MarkdownParser.parse(source) {
            append(line..<block.id, block: nil)
            append(block.sourceLines, block: block)
            line = block.sourceLines.upperBound
        }
        append(line..<ranges.count, block: nil)
        self.rows = rows
    }

    func row(at location: Int) -> Row {
        // Gaps own blank lines and comments that the Reader skips. A caret
        // on a line terminator belongs to the row that precedes it.
        var lower = 0
        var upper = rows.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if rows[middle].range.location <= location {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return rows[max(0, lower - 1)]
    }
}
