import Foundation

// A presentation over the source's UTF-16 ranges, never a rewritten string.
nonisolated struct LiveMarkdownLine {
    enum Block: Equatable {
        case body
        case heading(Int)
        case quote
        case code(fence: Bool)
    }

    struct Inline {
        var range: NSRange
        var intent: InlinePresentationIntent
        var isLink: Bool
    }

    struct Marker {
        var range: NSRange
        var symbol: String
    }

    var block: Block = .body
    var hidden: [NSRange] = []
    var inline: [Inline] = []
    var marker: Marker?

    private static let heading = try! NSRegularExpression(pattern: #"^ {0,3}(#{1,6})[ \t]+(?=\S)"#)
    private static let closingHashes = try! NSRegularExpression(pattern: #"[ \t]+#+[ \t]*$"#)
    private static let quote = try! NSRegularExpression(pattern: #"^ {0,3}>[ \t]?"#)
    private static let bullet = try! NSRegularExpression(pattern: #"^([ \t]*)([-+*])(?:[ \t]+\[([ xX])\](?=[ \t]|$)|(?=[ \t]))"#)

    init(source: String, code: Bool = false, fence: Bool = false) {
        if code {
            block = .code(fence: fence)
            return
        }
        let range = NSRange(location: 0, length: source.utf16.count)
        // Bound the work even for documents with generated, exceptionally long lines.
        guard range.length > 0, range.length <= 8_192 else { return }

        var start = 0
        var end = range.length
        if let match = Self.heading.firstMatch(in: source, range: range) {
            block = .heading(match.range(at: 1).length)
            start = NSMaxRange(match.range)
            hidden.append(match.range)
            if let closing = Self.closingHashes.firstMatch(
                in: source,
                range: NSRange(location: start, length: end - start)
            ), closing.range.location > start {
                end = closing.range.location
                hidden.append(closing.range)
            }
        } else if let match = Self.quote.firstMatch(in: source, range: range) {
            block = .quote
            start = NSMaxRange(match.range)
            hidden.append(match.range)
        } else if let match = Self.bullet.firstMatch(in: source, range: range) {
            start = NSMaxRange(match.range)
            let check = match.range(at: 3)
            let symbol = check.location == NSNotFound ? "•" :
                ((source as NSString).substring(with: check) == " " ? "☐" : "☑")
            marker = Marker(
                range: NSRange(location: match.range(at: 2).location, length: start - match.range(at: 2).location),
                symbol: symbol
            )
        }

        let content = (source as NSString).substring(with: NSRange(location: start, length: end - start))
        parseInline(content, offset: start)
    }

    private mutating func parseInline(_ source: String, offset: Int) {
        guard source.utf8.contains(where: { "*_`~[<\\".utf8.contains($0) }) else { return }
        // Keep the reader's LaTeX syntax literal in the editor. In particular,
        // underscores inside a formula are not Markdown emphasis.
        if source.contains("$") {
            let characters = Array(source)
            var lower = 0
            var position = offset
            for piece in InlineMathSegmenter.rangedSegments(in: source) {
                let upper = piece.sourceRange.upperBound
                let text = String(characters[lower..<upper])
                if case .text = piece.segment {
                    parseMarkdown(text, offset: position)
                }
                position += text.utf16.count
                lower = upper
            }
        } else {
            parseMarkdown(source, offset: offset)
        }
    }

    private mutating func parseMarkdown(_ source: String, offset: Int) {
        guard let parsed = try? AttributedString(markdown: source, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            appliesSourcePositionAttributes: true
        )), !parsed.characters.isEmpty else { return }

        let original = source as NSString
        var runs: [Inline] = []
        var gaps: [NSRange] = []
        var end = 0
        var previousWasLink = false
        for run in parsed.runs {
            guard let position = run.markdownSourcePosition,
                  let sourceRange = Range<String.Index>(position, in: source) else { return }
            // Foundation's direct NSRange conversion can truncate a run to
            // one character; convert its Swift source range to UTF-16.
            let range = NSRange(sourceRange, in: source)
            guard range.location >= end, NSMaxRange(range) <= original.length else { return }

            let intent = run.inlinePresentationIntent ?? []
            let isLink = run.link != nil
            if range.location > end {
                let gap = NSRange(location: end, length: range.location - end)
                let syntax = original.substring(with: gap)
                if Self.isInlineDelimiter(syntax) {
                    gaps.append(gap)
                } else if isLink, !previousWasLink, syntax.last == "[",
                          syntax.dropLast().allSatisfy({ "*_~".contains($0) }) {
                    gaps.append(gap)
                } else if previousWasLink, Self.isLinkSuffix(syntax) {
                    gaps.append(gap)
                }
            }

            if !intent.isEmpty || isLink {
                runs.append(Inline(range: range.offset(by: offset), intent: intent, isLink: isLink))
            }
            previousWasLink = isLink
            end = NSMaxRange(range)
        }

        if end < original.length {
            let gap = NSRange(location: end, length: original.length - end)
            let syntax = original.substring(with: gap)
            if Self.isInlineDelimiter(syntax) || (previousWasLink && Self.isLinkSuffix(syntax)) {
                gaps.append(gap)
            }
        }

        inline.append(contentsOf: runs)
        hidden.append(contentsOf: gaps.map { $0.offset(by: offset) })
    }

    private static func isInlineDelimiter(_ syntax: String) -> Bool {
        syntax.allSatisfy { "*_`~".contains($0) }
    }

    private static func isLinkSuffix(_ syntax: String) -> Bool {
        guard syntax.hasPrefix("]("), let lastParenthesis = syntax.lastIndex(of: ")") else { return false }
        return syntax[syntax.index(after: lastParenthesis)...].allSatisfy { "*_~".contains($0) }
    }
}

private nonisolated extension NSRange {
    func offset(by amount: Int) -> NSRange {
        NSRange(location: location + amount, length: length)
    }
}
