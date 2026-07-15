import Foundation

nonisolated enum MarkdownParser {
    static func parse(_ source: String) -> [MarkdownBlock] {
        let lines = source.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var index = 0

        if lines.first?.trimmingCharacters(in: .whitespaces) == "---",
           let closing = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
            let content = lines[1..<closing].joined(separator: "\n")
            blocks.append(MarkdownBlock(id: 0, kind: .frontMatter(content)))
            index = closing + 1
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = String(trimmed.prefix(3))
                let languageText = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let start = index
                index += 1
                var codeLines: [String] = []
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(marker) {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(MarkdownBlock(
                    id: start,
                    kind: .code(language: languageText.isEmpty ? nil : languageText, source: codeLines.joined(separator: "\n"))
                ))
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
                    let value = lines[index].trimmingCharacters(in: .whitespaces)
                    guard value.hasPrefix(">") else { break }
                    quoteLines.append(String(value.dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(MarkdownBlock(id: start, kind: .blockquote(quoteLines.joined(separator: "\n"))))
                continue
            }

            if let image = image(from: trimmed) {
                blocks.append(MarkdownBlock(id: index, kind: .image(alt: image.alt, source: image.source)))
                index += 1
                continue
            }

            if let table = table(at: index, lines: lines) {
                blocks.append(MarkdownBlock(id: index, kind: .table(headers: table.headers, rows: table.rows)))
                index = table.nextIndex
                continue
            }

            if listItem(from: trimmed) != nil {
                let start = index
                var items: [MarkdownListItem] = []
                var listKind: ListKind = .unordered
                while index < lines.count, let parsed = listItem(from: lines[index].trimmingCharacters(in: .whitespaces)) {
                    listKind = parsed.kind == .task ? .task : (listKind == .task ? .task : parsed.kind)
                    items.append(MarkdownListItem(id: index, text: parsed.text, isChecked: parsed.checked))
                    index += 1
                }
                let kind: MarkdownBlock.Kind = switch listKind {
                case .unordered: .unorderedList(items)
                case .ordered: .orderedList(items)
                case .task: .taskList(items)
                }
                blocks.append(MarkdownBlock(id: start, kind: kind))
                continue
            }

            let start = index
            var paragraph: [String] = []
            while index < lines.count {
                let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                guard !candidate.isEmpty,
                      heading(from: candidate) == nil,
                      !candidate.hasPrefix(">"),
                      !candidate.hasPrefix("```"),
                      !candidate.hasPrefix("~~~"),
                      !isDivider(candidate),
                      image(from: candidate) == nil,
                      listItem(from: candidate) == nil else { break }
                if index != start, table(at: index, lines: lines) != nil { break }
                paragraph.append(candidate)
                index += 1
            }
            blocks.append(MarkdownBlock(id: start, kind: .paragraph(paragraph.joined(separator: " "))))
        }

        return blocks
    }

    static func headings(in source: String) -> [MarkdownHeading] {
        parse(source).compactMap { block in
            guard case let .heading(level, text) = block.kind else { return nil }
            return MarkdownHeading(id: block.id, level: level, text: text)
        }
    }

    private enum ListKind { case unordered, ordered, task }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        return (hashes, String(line.dropFirst(hashes + 1)))
    }

    private static func isDivider(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        return compact == "---" || compact == "***" || compact == "___"
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

    private static func listItem(from line: String) -> (kind: ListKind, text: String, checked: Bool?)? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            let value = String(line.dropFirst(2))
            let lower = value.lowercased()
            if lower.hasPrefix("[ ] ") { return (.task, String(value.dropFirst(4)), false) }
            if lower.hasPrefix("[x] ") { return (.task, String(value.dropFirst(4)), true) }
            return (.unordered, value, nil)
        }

        guard let dot = line.firstIndex(of: "."), dot < line.endIndex else { return nil }
        let number = line[..<dot]
        let afterDot = line.index(after: dot)
        guard !number.isEmpty,
              number.allSatisfy(\.isNumber),
              afterDot < line.endIndex,
              line[afterDot] == " " else { return nil }
        return (.ordered, String(line[line.index(after: afterDot)...]), nil)
    }

    private static func table(at index: Int, lines: [String]) -> (headers: [String], rows: [[String]], nextIndex: Int)? {
        guard index + 1 < lines.count else { return nil }
        let header = cells(in: lines[index])
        let separator = cells(in: lines[index + 1])
        guard header.count > 1,
              separator.count == header.count,
              separator.allSatisfy({ cell in
                  let value = cell.replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)
                  return value.count >= 3 && value.allSatisfy({ $0 == "-" })
              }) else { return nil }

        var rows: [[String]] = []
        var next = index + 2
        while next < lines.count {
            let row = cells(in: lines[next])
            guard row.count == header.count else { break }
            rows.append(row)
            next += 1
        }
        return (header, rows, next)
    }

    private static func cells(in line: String) -> [String] {
        var value = line.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("|") { value.removeFirst() }
        if value.hasSuffix("|") { value.removeLast() }
        guard value.contains("|") else { return [] }
        return value.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }
}
