import Foundation

enum MarkdownPrintRenderer {
    static func html(source: String, title: String, baseURL: URL? = nil) -> String {
        let body = MarkdownParser.parse(source).map { html(for: $0, baseURL: baseURL) }.joined(separator: "\n")
        return """
        <!doctype html>
        <html lang="\(htmlLanguageCode)">
        <head>
        <meta charset="utf-8">
        <title>\(escape(title))</title>
        <style>
        @page { margin: 16mm 17mm 18mm; }
        * { box-sizing: border-box; }
        body { color: #2b2621; font-family: ui-serif, Georgia, "Songti SC", serif; font-size: 13pt; line-height: 1.58; margin: 0; overflow-wrap: anywhere; }
        h1, h2, h3, h4, h5, h6 { color: #1c1815; font-weight: 600; line-height: 1.22; margin: 1.15em 0 .38em; break-after: avoid; }
        h1 { font-size: 1.84em; margin-top: .2em; } h2 { font-size: 1.48em; } h3 { font-size: 1.24em; }
        h4 { font-size: 1.12em; } h5, h6 { font-size: 1em; } h6 { color: #72695e; }
        p { margin: .5em 0; }
        a { color: #9d552d; text-decoration: none; }
        code { font-family: ui-monospace, "SFMono-Regular", Menlo, monospace; font-size: .9em; background: #f2eeea; color: #9f3f38; padding: .08em .32em; border-radius: 3px; }
        pre { font-family: ui-monospace, "SFMono-Regular", Menlo, monospace; font-size: .9em; line-height: 1.5; white-space: pre-wrap; background: #f8f6f2; border: 1px solid #e2dbd1; border-radius: 6px; padding: 11px 13px; break-inside: avoid; }
        pre code { color: #1c1815; background: transparent; padding: 0; }
        blockquote { color: #625950; background: #f3ede5; border-left: 2px solid #cbb9a6; border-radius: 5px; margin: .7em 0; padding: .45em .9em; }
        blockquote p { margin: 0; }
        ul, ol { margin: .5em 0; padding-left: 1.6em; }
        li { margin: .15em 0; }
        .task-marker { display: inline-block; width: 1.25em; color: #9d552d; font-family: sans-serif; }
        table { width: 100%; border-collapse: collapse; margin: .8em 0; font-size: .88em; line-height: 1.38; break-inside: auto; page-break-inside: auto; }
        thead { display: table-header-group; }
        tbody { break-inside: auto; page-break-inside: auto; }
        tr { break-inside: avoid; page-break-inside: avoid; break-after: auto; }
        th, td { border-bottom: 1px solid #d7cec5; padding: 7px 9px; text-align: left; vertical-align: top; }
        th { border-top: 1px solid #bca995; border-bottom-color: #bca995; font-weight: 600; }
        tr:last-child td { border-bottom-color: #bca995; }
        hr { border: 0; border-top: 1px solid #cfc6bb; margin: 1.6em 0; }
        img { display: block; max-width: 100%; height: auto; margin: .75em auto .25em; break-inside: avoid; }
        figure { margin: .75em 0; break-inside: avoid; } figcaption { color: #72695e; font-size: .9em; text-align: center; }
        .front-matter { color: #625950; background: #f6f1ea; border-radius: 6px; padding: .7em .9em; white-space: pre-wrap; break-inside: avoid; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private static var htmlLanguageCode: String {
        Bundle.main.preferredLocalizations.first == "zh-Hans" ? "zh-CN" : "en"
    }

    private static func html(for block: MarkdownBlock, baseURL: URL?) -> String {
        switch block.kind {
        case let .heading(level, text):
            return "<h\(level)>\(inline(text))</h\(level)>"
        case let .paragraph(text):
            return "<p>\(inline(text))</p>"
        case let .blockquote(text):
            return "<blockquote><p>\(inline(text).replacingOccurrences(of: "\n", with: "<br>"))</p></blockquote>"
        case let .unorderedList(items):
            return list(items, tag: "ul", task: false)
        case let .orderedList(items):
            return list(items, tag: "ol", task: false)
        case let .taskList(items):
            return list(items, tag: "ul", task: true)
        case let .code(language, source):
            let className = language.map { " class=\"language-\(escapeAttribute($0))\"" } ?? ""
            return "<pre><code\(className)>\(escape(source))</code></pre>"
        case let .table(headers, rows):
            let header = headers.map { "<th>\(inline($0))</th>" }.joined()
            let body = rows.map { row in
                "<tr>\(row.map { "<td>\(inline($0))</td>" }.joined())</tr>"
            }.joined()
            return "<table><thead><tr>\(header)</tr></thead><tbody>\(body)</tbody></table>"
        case let .image(alt, source):
            let resolvedSource: String
            if let url = URL(string: source), url.scheme != nil {
                resolvedSource = url.absoluteString
            } else if let baseURL {
                resolvedSource = baseURL.appending(path: source.removingPercentEncoding ?? source).standardizedFileURL.absoluteString
            } else {
                resolvedSource = source
            }
            let caption = alt.isEmpty ? "" : "<figcaption>\(inline(alt))</figcaption>"
            return "<figure><img src=\"\(escapeAttribute(resolvedSource))\" alt=\"\(escapeAttribute(alt))\">\(caption)</figure>"
        case let .frontMatter(source):
            return "<div class=\"front-matter\">\(escape(source))</div>"
        case .divider:
            return "<hr>"
        }
    }

    private static func list(_ items: [MarkdownListItem], tag: String, task: Bool) -> String {
        let contents = items.map { item in
            let marker = task ? "<span class=\"task-marker\">\(item.isChecked == true ? "&#9745;" : "&#9744;")</span>" : ""
            return "<li>\(marker)\(inline(item.text))</li>"
        }.joined()
        return "<\(tag)>\(contents)</\(tag)>"
    }

    private static func inline(_ source: String) -> String {
        var value = escape(source)
        var codeFragments: [String] = []
        value = replacing(#"`([^`]+)`"#, in: value) { groups in
            let token = "PRINTCODETOKEN\(codeFragments.count)ENDTOKEN"
            codeFragments.append("<code>\(groups[1])</code>")
            return token
        }
        value = replacing(#"\[([^\]]+)\]\(([^\s\)]+)(?:\s+&quot;.*?&quot;)?\)"#, in: value) { groups in
            // The whole inline source was escaped before matching, so the URL is
            // already safe for a quoted HTML attribute here.
            "<a href=\"\(groups[2])\">\(groups[1])</a>"
        }
        value = replacing(#"\*\*(.+?)\*\*"#, in: value) { "<strong>\($0[1])</strong>" }
        value = replacing(#"__(.+?)__"#, in: value) { "<strong>\($0[1])</strong>" }
        value = replacing(#"(?<!\*)\*([^*\n]+)\*(?!\*)"#, in: value) { "<em>\($0[1])</em>" }
        value = replacing(#"(?<!_)_([^_\n]+)_(?!_)"#, in: value) { "<em>\($0[1])</em>" }
        value = replacing(#"~~(.+?)~~"#, in: value) { "<del>\($0[1])</del>" }
        for (index, fragment) in codeFragments.enumerated() {
            value = value.replacingOccurrences(of: "PRINTCODETOKEN\(index)ENDTOKEN", with: fragment)
        }
        return value
    }

    private static func replacing(
        _ pattern: String,
        in source: String,
        transform: ([String]) -> String
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return source }
        let matches = expression.matches(in: source, range: NSRange(source.startIndex..., in: source))
        var result = source
        for match in matches.reversed() {
            guard let range = Range(match.range, in: source) else { continue }
            let groups = (0..<match.numberOfRanges).map { index -> String in
                guard match.range(at: index).location != NSNotFound,
                      let groupRange = Range(match.range(at: index), in: source) else { return "" }
                return String(source[groupRange])
            }
            result.replaceSubrange(range, with: transform(groups))
        }
        return result
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeAttribute(_ value: String) -> String {
        escape(value).replacingOccurrences(of: "\"", with: "&quot;")
    }
}
