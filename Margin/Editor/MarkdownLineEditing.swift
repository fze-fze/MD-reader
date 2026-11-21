import Foundation

// Line-level edits the editor makes on the user's behalf: continuing a list
// when Return is pressed inside one, and switching a line's block prefix from
// the accessory bar. Pure functions over the text and selection (UTF-16, as
// UITextView reports them) so they can be tested without a text view.
nonisolated enum MarkdownLineEditing {
    struct Edit: Equatable {
        let range: NSRange
        let replacement: String
        // Where the caret goes once the replacement is in place.
        let selection: NSRange
    }

    enum Prefix {
        case quote
        case list
        case task
    }

    private struct Marker {
        let indent: String
        // The marker a following line should start with, without indentation.
        let continuation: String
        // UTF-16 length of indentation plus marker, i.e. where content starts.
        let length: Int
    }

    // Return pressed with `selection` inside a list item or quote: the next
    // line starts with the same marker (the next number for an ordered item,
    // an unchecked box for a task). On an item that is still empty the marker
    // is removed instead, which is how a list is ended.
    static func continuingList(in text: String, selection: NSRange) -> Edit? {
        let source = text as NSString
        guard selection.location != NSNotFound, NSMaxRange(selection) <= source.length else { return nil }

        let contentRange = contentRange(ofLineAt: selection.location, in: source)
        let line = source.substring(with: contentRange)
        guard let marker = marker(in: line),
              selection.location >= contentRange.location + marker.length else { return nil }

        let content = (line as NSString).substring(from: marker.length)
        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            return Edit(
                range: NSRange(location: contentRange.location, length: max(contentRange.length, NSMaxRange(selection) - contentRange.location)),
                replacement: "",
                selection: NSRange(location: contentRange.location, length: 0)
            )
        }

        let lineBreak = usesCarriageReturns(source, lineEnd: NSMaxRange(contentRange)) ? "\r\n" : "\n"
        let replacement = lineBreak + marker.indent + marker.continuation
        return Edit(
            range: selection,
            replacement: replacement,
            selection: NSRange(location: selection.location + (replacement as NSString).length, length: 0)
        )
    }

    // Switches the block prefix of the line holding the caret. Asking for the
    // prefix a line already has removes it; asking for a list on a task line
    // (or the reverse) converts it rather than stacking a second marker.
    static func togglingPrefix(_ prefix: Prefix, in text: String, selection: NSRange) -> Edit {
        let source = text as NSString
        let location = min(max(selection.location, 0), source.length)
        let contentRange = contentRange(ofLineAt: location, in: source)
        let line = source.substring(with: contentRange) as NSString

        let indentLength = line.length - (line as String).drop(while: { $0 == " " || $0 == "\t" }).utf16.count
        let body = line.substring(from: indentLength)
        let existing = existingPrefix(in: body)
        let existingLength = existing?.length ?? 0

        let replacedLength: Int
        let inserted: String
        switch (prefix, existing?.kind) {
        case (.quote, .quote?), (.list, .list?), (.task, .task?):
            (replacedLength, inserted) = (existingLength, "")
        case (.list, .task?):
            (replacedLength, inserted) = (existingLength, "- ")
        case (.task, .list?):
            (replacedLength, inserted) = (existingLength, "- [ ] ")
        case (.quote, _):
            // A quote wraps whatever the line already is.
            (replacedLength, inserted) = (0, "> ")
        case (.list, _):
            (replacedLength, inserted) = (0, "- ")
        case (.task, _):
            (replacedLength, inserted) = (0, "- [ ] ")
        }

        let range = NSRange(location: contentRange.location + indentLength, length: replacedLength)
        let insertedLength = (inserted as NSString).length
        // A caret in the content keeps its place in the content; one that sat
        // in or before the old prefix lands just after the new one.
        let adjusted = location >= NSMaxRange(range)
            ? NSRange(location: location + insertedLength - replacedLength, length: selection.length)
            : NSRange(location: range.location + insertedLength, length: 0)
        return Edit(range: range, replacement: inserted, selection: adjusted)
    }

    // MARK: - Line anatomy

    // The line containing `location`, without its terminator.
    private static func contentRange(ofLineAt location: Int, in source: NSString) -> NSRange {
        var start = 0
        var end = 0
        var contentsEnd = 0
        source.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
        return NSRange(location: start, length: contentsEnd - start)
    }

    private static func usesCarriageReturns(_ source: NSString, lineEnd: Int) -> Bool {
        lineEnd < source.length && source.character(at: lineEnd) == 0x0D
    }

    private static func marker(in line: String) -> Marker? {
        let indent = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
        let body = line.dropFirst(indent.count)
        guard let first = body.first else { return nil }
        let indentLength = indent.utf16.count

        if first == ">" {
            let rest = body.dropFirst()
            let space = rest.first == " " ? 1 : 0
            return Marker(indent: indent, continuation: "> ", length: indentLength + 1 + space)
        }

        if first == "-" || first == "*" || first == "+" {
            let rest = body.dropFirst()
            guard rest.first == " " || rest.first == "\t" else { return nil }
            let afterBullet = rest.drop(while: { $0 == " " || $0 == "\t" })
            var length = indentLength + 1 + (rest.count - afterBullet.count)
            var continuation = "\(first) "
            let box = afterBullet.prefix(4).lowercased()
            if box == "[ ] " || box == "[x] " {
                continuation += "[ ] "
                length += 4
            }
            return Marker(indent: indent, continuation: continuation, length: length)
        }

        let digits = body.prefix(while: { $0.isASCII && $0.isNumber })
        guard !digits.isEmpty, digits.count <= 9, let number = Int(digits) else { return nil }
        let rest = body.dropFirst(digits.count)
        guard let delimiter = rest.first, delimiter == "." || delimiter == ")" else { return nil }
        let afterDelimiter = rest.dropFirst()
        guard afterDelimiter.first == " " || afterDelimiter.first == "\t" else { return nil }
        let content = afterDelimiter.drop(while: { $0 == " " || $0 == "\t" })
        return Marker(
            indent: indent,
            continuation: "\(number + 1)\(delimiter) ",
            length: indentLength + digits.count + 1 + (afterDelimiter.count - content.count)
        )
    }

    private static func existingPrefix(in body: String) -> (kind: Prefix, length: Int)? {
        if body.hasPrefix("> ") { return (.quote, 2) }
        if body.hasPrefix(">") { return (.quote, 1) }
        guard let first = body.first, first == "-" || first == "*" || first == "+",
              body.dropFirst().first == " " else { return nil }
        let box = body.dropFirst(2).prefix(4).lowercased()
        if box == "[ ] " || box == "[x] " { return (.task, 6) }
        return (.list, 2)
    }
}
