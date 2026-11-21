import Foundation

nonisolated enum MarkdownParser {
    // One source line, measured once: `text` is the line with its indentation
    // and trailing whitespace removed, `indent` the width of what was removed
    // in front (a tab counts as four columns).
    private struct Line {
        let raw: Substring
        let text: String
        let indent: Int

        var isBlank: Bool { text.isEmpty }
    }

    // Line numbering is by `Character`, so a CRLF pair ends one line rather
    // than two. `SourceLines` and `MarkdownTaskToggler` count the same way,
    // which is what keeps block IDs usable as source line indices.
    private static func lines(of source: String) -> [Line] {
        source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map { raw in
            var indent = 0
            var contentStart = raw.startIndex
            while contentStart < raw.endIndex {
                let character = raw[contentStart]
                if character == " " {
                    indent += 1
                } else if character == "\t" {
                    indent += 4
                } else {
                    break
                }
                contentStart = raw.index(after: contentStart)
            }
            let text = raw[contentStart...].trimmingCharacters(in: .whitespaces)
            return Line(raw: raw, text: text, indent: indent)
        }
    }

    static func parse(_ source: String) -> [MarkdownBlock] {
        let lines = lines(of: source)
        var blocks: [MarkdownBlock] = []
        var index = 0

        if let closing = frontMatterEnd(in: lines) {
            let content = lines[1..<closing].map { String($0.raw) }.joined(separator: "\n")
            blocks.append(MarkdownBlock(id: 0, kind: .frontMatter(content), sourceLines: 0..<(closing + 1)))
            index = closing + 1
        }

        while index < lines.count {
            let trimmed = lines[index].text

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if let fence = fenceOpening(trimmed) {
                let start = index
                index += 1
                var codeLines: [String] = []
                while index < lines.count, !closesFence(lines[index].text, fence) {
                    codeLines.append(String(lines[index].raw))
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(MarkdownBlock(
                    id: start,
                    kind: .code(language: fence.info.isEmpty ? nil : fence.info, source: codeLines.joined(separator: "\n")),
                    sourceLines: start..<index
                ))
                continue
            }

            if let next = htmlCommentEnd(at: index, lines: lines) {
                index = next
                continue
            }

            if let math = mathBlock(at: index, lines: lines) {
                blocks.append(MarkdownBlock(
                    id: index,
                    kind: .math(source: math.source),
                    sourceLines: index..<math.nextIndex
                ))
                index = math.nextIndex
                continue
            }

            if let heading = heading(from: trimmed) {
                blocks.append(MarkdownBlock(id: index, kind: .heading(level: heading.level, text: heading.text)))
                index += 1
                continue
            }

            if isDivider(trimmed) {
                blocks.append(MarkdownBlock(id: index, kind: .divider))
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                let start = index
                var quoteLines: [String] = []
                while index < lines.count {
                    let value = lines[index].text
                    guard value.hasPrefix(">") else { break }
                    quoteLines.append(String(value.dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(MarkdownBlock(
                    id: start,
                    kind: .blockquote(quoteLines.joined(separator: "\n")),
                    sourceLines: start..<index
                ))
                continue
            }

            if let image = image(from: trimmed) {
                blocks.append(MarkdownBlock(id: index, kind: .image(alt: image.alt, source: image.source)))
                index += 1
                continue
            }

            if let table = table(at: index, lines: lines) {
                blocks.append(MarkdownBlock(
                    id: index,
                    kind: .table(headers: table.headers, rows: table.rows),
                    sourceLines: index..<table.nextIndex
                ))
                index = table.nextIndex
                continue
            }

            if listItem(from: trimmed) != nil {
                let list = list(at: index, lines: lines)
                blocks.append(MarkdownBlock(id: index, kind: list.kind, sourceLines: index..<list.nextIndex))
                index = list.nextIndex
                continue
            }

            let start = index
            var paragraph = ""
            while index < lines.count {
                let candidate = lines[index].text
                guard !startsBlock(at: index, lines: lines, isFirstLine: index == start) else { break }
                if index != start {
                    // Two trailing spaces ask for a hard break; anything else
                    // is a soft break, drawn as a space.
                    paragraph += lines[index - 1].raw.hasSuffix("  ") ? "\n" : " "
                }
                paragraph += candidate
                index += 1
            }
            blocks.append(MarkdownBlock(
                id: start,
                kind: .paragraph(paragraph),
                sourceLines: start..<index
            ))
        }

        return blocks
    }

    // Whether the line at `index` ends the paragraph or list item before it.
    // A paragraph's own first line is whatever the block rules left over, so
    // only a blank line can stop it.
    private static func startsBlock(at index: Int, lines: [Line], isFirstLine: Bool) -> Bool {
        let candidate = lines[index].text
        if candidate.isEmpty { return true }
        if isFirstLine { return false }
        return heading(from: candidate) != nil
            || candidate.hasPrefix(">")
            || fenceOpening(candidate) != nil
            || isDivider(candidate)
            || image(from: candidate) != nil
            || listItem(from: candidate) != nil
            || htmlCommentEnd(at: index, lines: lines) != nil
            || table(at: index, lines: lines) != nil
            || mathBlock(at: index, lines: lines) != nil
    }

    // YAML front matter is a leading `---` … `---` pair whose first line is a
    // `key:`. Without that check a document that merely opens with a divider
    // would lose everything up to its next divider.
    private static func frontMatterEnd(in lines: [Line]) -> Int? {
        guard lines.count > 2, lines[0].text == "---", lines[0].indent == 0 else { return nil }
        guard let firstContent = lines.dropFirst().first(where: { !$0.isBlank }),
              firstContent.text != "---",
              isYAMLKey(firstContent.text) else { return nil }
        return lines.dropFirst().firstIndex { $0.text == "---" || $0.text == "..." }
    }

    private static func isYAMLKey(_ line: String) -> Bool {
        guard let colon = line.firstIndex(of: ":") else { return false }
        let key = line[..<colon]
        guard !key.isEmpty, key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == " " || $0 == "." }) else {
            return false
        }
        let rest = line[line.index(after: colon)...]
        return rest.isEmpty || rest.first == " "
    }

    struct Fence {
        let marker: Character
        let length: Int
        let info: String
    }

    static func fenceOpening(_ line: String) -> Fence? {
        guard let marker = line.first, marker == "`" || marker == "~" else { return nil }
        let length = line.prefix(while: { $0 == marker }).count
        guard length >= 3 else { return nil }
        let info = line.dropFirst(length).trimmingCharacters(in: .whitespaces)
        // An info string with a backtick in it is inline code, not a fence.
        if marker == "`", info.contains("`") { return nil }
        return Fence(marker: marker, length: length, info: info)
    }

    // A fence closes on a line of the same character, at least as long as the
    // opener and with nothing after it — so a ```` block can show ``` lines.
    static func closesFence(_ line: String, _ fence: Fence) -> Bool {
        guard line.first == fence.marker else { return false }
        let length = line.prefix(while: { $0 == fence.marker }).count
        return length >= fence.length && length == line.count
    }

    // A standalone HTML comment draws nothing. Margin's own annotation
    // comments only ever follow a `==mark==` inside a line, so they never
    // start one.
    private static func htmlCommentEnd(at index: Int, lines: [Line]) -> Int? {
        guard lines[index].text.hasPrefix("<!--") else { return nil }
        var next = index
        while next < lines.count {
            let text = lines[next].text
            if let close = text.range(of: "-->", range: (next == index ? text.index(text.startIndex, offsetBy: 4) : text.startIndex)..<text.endIndex) {
                // Text after the comment on its closing line is real content.
                return close.upperBound == text.endIndex ? next + 1 : nil
            }
            next += 1
        }
        return nil
    }

    // Consecutive list items form one block. Indentation gives each item a
    // nesting level, indented lines that are not items continue the item
    // above, and blank lines between items of one list do not end it.
    private static func list(at start: Int, lines: [Line]) -> (kind: MarkdownBlock.Kind, nextIndex: Int) {
        var items: [MarkdownListItem] = []
        var indents: [Int] = []
        var ordinals: [Int: Int] = [:]
        var hasTask = false
        var firstIsOrdered = false
        var index = start

        while index < lines.count {
            let line = lines[index]

            if line.isBlank {
                var next = index
                while next < lines.count, lines[next].isBlank { next += 1 }
                guard next < lines.count,
                      let following = listItem(from: lines[next].text),
                      lines[next].indent >= 2 || (following.ordinal != nil) == firstIsOrdered,
                      !isDivider(lines[next].text) else { break }
                index = next
                continue
            }

            if !isDivider(line.text), let parsed = listItem(from: line.text) {
                while let last = indents.last, line.indent < last { indents.removeLast() }
                if indents.isEmpty {
                    indents.append(line.indent)
                } else if let last = indents.last, line.indent >= last + 2 {
                    indents.append(line.indent)
                }
                let level = indents.count - 1
                ordinals = ordinals.filter { $0.key <= level }

                var ordinal: Int?
                if let written = parsed.ordinal {
                    ordinal = ordinals[level].map { $0 + 1 } ?? written
                    ordinals[level] = ordinal
                } else {
                    ordinals[level] = nil
                }

                if items.isEmpty { firstIsOrdered = parsed.ordinal != nil }
                if parsed.checked != nil { hasTask = true }
                items.append(MarkdownListItem(
                    id: index,
                    text: parsed.text,
                    isChecked: parsed.checked,
                    level: level,
                    ordinal: ordinal
                ))
                index += 1
                continue
            }

            // An indented line that starts no block of its own belongs to the
            // item above it.
            guard line.indent >= 2,
                  let last = items.last,
                  !startsBlock(at: index, lines: lines, isFirstLine: false) else { break }
            let joiner = lines[index - 1].raw.hasSuffix("  ") ? "\n" : " "
            items[items.count - 1] = MarkdownListItem(
                id: last.id,
                text: last.text + joiner + line.text,
                isChecked: last.isChecked,
                level: last.level,
                ordinal: last.ordinal
            )
            index += 1
        }

        // Trailing blank lines are not part of the list.
        while index > start, lines[index - 1].isBlank { index -= 1 }

        let kind: MarkdownBlock.Kind = if hasTask {
            .taskList(items)
        } else if firstIsOrdered {
            .orderedList(items)
        } else {
            .unorderedList(items)
        }
        return (kind, index)
    }

    static func headings(in source: String) -> [MarkdownHeading] {
        parse(source).compactMap { block in
            guard case let .heading(level, text) = block.kind else { return nil }
            return MarkdownHeading(id: block.id, level: level, text: text)
        }
    }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes) else { return nil }
        let rest = line.dropFirst(hashes)
        guard let separator = rest.first, separator == " " || separator == "\t" else { return nil }
        var text = rest.trimmingCharacters(in: .whitespaces)
        // "## Title ##" — a closing run of #s is decoration, unless it is
        // glued to the text ("C#").
        if let lastWord = text.split(separator: " ").last,
           lastWord.allSatisfy({ $0 == "#" }),
           text.count > lastWord.count {
            text = String(text.dropLast(lastWord.count)).trimmingCharacters(in: .whitespaces)
        }
        return (hashes, text)
    }

    // Display math is $$…$$ only: a standalone $$…$$ line, or a $$ fence over
    // several lines. An unterminated opener is not treated as math so a stray
    // $$ cannot swallow the rest of the document.
    private static func mathBlock(at index: Int, lines: [Line]) -> (source: String, nextIndex: Int)? {
        let trimmed = lines[index].text
        guard trimmed.hasPrefix("$$") else { return nil }
        return fencedMath(at: index, lines: lines, opening: "$$", closing: "$$")
    }

    private static func fencedMath(
        at index: Int,
        lines: [Line],
        opening: String,
        closing: String
    ) -> (source: String, nextIndex: Int)? {
        let trimmed = lines[index].text
        let afterOpening = String(trimmed.dropFirst(opening.count))

        if afterOpening.hasSuffix(closing), afterOpening.count >= closing.count {
            let inner = String(afterOpening.dropLast(closing.count))
                .trimmingCharacters(in: .whitespaces)
            return inner.isEmpty ? nil : (inner, index + 1)
        }

        var contentLines: [String] = []
        let openingRest = afterOpening.trimmingCharacters(in: .whitespaces)
        if !openingRest.isEmpty { contentLines.append(openingRest) }

        var next = index + 1
        while next < lines.count {
            let candidate = lines[next].text
            if candidate == closing {
                let source = contentLines.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return source.isEmpty ? nil : (source, next + 1)
            }
            if candidate.hasSuffix(closing) {
                contentLines.append(
                    String(candidate.dropLast(closing.count)).trimmingCharacters(in: .whitespaces)
                )
                let source = contentLines.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return source.isEmpty ? nil : (source, next + 1)
            }
            contentLines.append(String(lines[next].raw))
            next += 1
        }
        return nil
    }

    private static func isDivider(_ line: String) -> Bool {
        guard let marker = line.first, marker == "-" || marker == "*" || marker == "_" else { return false }
        var count = 0
        for character in line {
            if character == marker {
                count += 1
            } else if character != " " && character != "\t" {
                return false
            }
        }
        return count >= 3
    }

    private static func image(from line: String) -> (alt: String, source: String)? {
        guard line.hasPrefix("!["),
              let separator = line.range(of: "]("),
              line.hasSuffix(")") else { return nil }

        let altStart = line.index(line.startIndex, offsetBy: 2)
        let alt = String(line[altStart..<separator.lowerBound])
        let destinationStart = separator.upperBound
        let destinationEnd = line.index(before: line.endIndex)
        var destination = String(line[destinationStart..<destinationEnd]).trimmingCharacters(in: .whitespaces)
        if let titleStart = destination.range(of: " \"") {
            destination = String(destination[..<titleStart.lowerBound])
        }
        guard !destination.isEmpty else { return nil }
        return (alt, destination)
    }

    private static func listItem(from line: String) -> (text: String, checked: Bool?, ordinal: Int?)? {
        guard let first = line.first else { return nil }

        if first == "-" || first == "*" || first == "+" {
            let rest = line.dropFirst()
            guard let separator = rest.first, separator == " " || separator == "\t" else { return nil }
            let value = rest.trimmingCharacters(in: .whitespaces)
            let lower = value.prefix(4).lowercased()
            if lower == "[ ] " || value == "[ ]" { return (String(value.dropFirst(4)), false, nil) }
            if lower == "[x] " || value.lowercased() == "[x]" { return (String(value.dropFirst(4)), true, nil) }
            return (value, nil, nil)
        }

        let digits = line.prefix(while: { $0.isASCII && $0.isNumber })
        guard !digits.isEmpty, digits.count <= 9, let ordinal = Int(digits) else { return nil }
        let rest = line.dropFirst(digits.count)
        guard let delimiter = rest.first, delimiter == "." || delimiter == ")" else { return nil }
        let afterDelimiter = rest.dropFirst()
        guard let separator = afterDelimiter.first, separator == " " || separator == "\t" else { return nil }
        return (afterDelimiter.trimmingCharacters(in: .whitespaces), nil, ordinal)
    }

    private static func table(at index: Int, lines: [Line]) -> (headers: [String], rows: [[String]], nextIndex: Int)? {
        guard index + 1 < lines.count,
              lines[index].text.contains("|"),
              lines[index + 1].text.contains("-"),
              let header = cells(in: lines[index].text),
              let separator = cells(in: lines[index + 1].text),
              separator.count == header.count,
              header.count > 1 || lines[index].text.hasPrefix("|"),
              separator.allSatisfy({ cell in
                  let value = cell.replacingOccurrences(of: ":", with: "")
                  return !value.isEmpty && value.allSatisfy({ $0 == "-" })
              }) else { return nil }

        var rows: [[String]] = []
        var next = index + 2
        while next < lines.count, !lines[next].isBlank, var row = cells(in: lines[next].text) {
            // A short row is padded and a long one cut, as GFM does; neither
            // ends the table.
            if row.count < header.count {
                row += Array(repeating: "", count: header.count - row.count)
            } else if row.count > header.count {
                row.removeLast(row.count - header.count)
            }
            rows.append(row)
            next += 1
        }
        return (header, rows, next)
    }

    // Splits a table row on its unescaped pipes. `\|` is a literal pipe, and a
    // pipe inside a code span belongs to the code. Returns nil for a line with
    // no cell separator at all.
    private static func cells(in line: String) -> [String]? {
        var cells: [String] = []
        var current = ""
        var sawSeparator = false
        var codeFenceLength = 0
        var characters = Array(line)
        if characters.first == "|" {
            characters.removeFirst()
            sawSeparator = true
        }

        var position = 0
        while position < characters.count {
            let character = characters[position]
            if character == "\\", position + 1 < characters.count, characters[position + 1] == "|" {
                // Inside a code span the backslash would be shown literally,
                // so the escape is resolved here in both cases.
                current.append("|")
                position += 2
                continue
            }
            if character == "`" {
                var run = 1
                while position + run < characters.count, characters[position + run] == "`" { run += 1 }
                if codeFenceLength == 0 {
                    // Only an opener that is closed later starts a span.
                    if hasBacktickRun(of: run, in: characters, from: position + run) { codeFenceLength = run }
                } else if codeFenceLength == run {
                    codeFenceLength = 0
                }
                current.append(String(repeating: "`", count: run))
                position += run
                continue
            }
            if character == "|", codeFenceLength == 0 {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                sawSeparator = true
                position += 1
                continue
            }
            current.append(character)
            position += 1
        }

        guard sawSeparator else { return nil }
        // A trailing pipe closes the last cell rather than opening an empty one.
        let last = current.trimmingCharacters(in: .whitespaces)
        if !last.isEmpty || cells.isEmpty || characters.last != "|" {
            cells.append(last)
        }
        return cells
    }

    private static func hasBacktickRun(of length: Int, in characters: [Character], from start: Int) -> Bool {
        var position = start
        while position < characters.count {
            guard characters[position] == "`" else {
                position += 1
                continue
            }
            var run = 1
            while position + run < characters.count, characters[position + run] == "`" { run += 1 }
            if run == length { return true }
            position += run
        }
        return false
    }
}
