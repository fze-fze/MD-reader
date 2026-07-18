import Foundation
import UIKit

enum MarkdownPrintRenderer {
    // Light-scheme palette per reader theme; print is always on white.
    private struct Palette {
        let bodyFont: String
        let text: String
        let headingText: String
        let mutedText: String
        let link: String
        let inlineCodeBg: String
        let inlineCodeText: String
        let preBg: String
        let preBorder: String
        let quoteText: String
        let quoteBg: String
        let quoteRule: String
        let tableRule: String
        let tableStrongRule: String
        let hairline: String
        let frontMatterBg: String
        let headingSizes: String
        let mathTextColor: UIColor
        let markerChecked: UIColor
        let markerUnchecked: UIColor
    }

    private static func palette(for theme: ReaderTheme) -> Palette {
        switch theme {
        case .claude:
            Palette(
                bodyFont: "ui-serif, Georgia, \"Songti SC\", serif",
                text: "#2b2621",
                headingText: "#1c1815",
                mutedText: "#72695e",
                link: "#9d552d",
                inlineCodeBg: "#f2eeea",
                inlineCodeText: "#9f3f38",
                preBg: "#f8f6f2",
                preBorder: "#e2dbd1",
                quoteText: "#625950",
                quoteBg: "#f3ede5",
                quoteRule: "#cbb9a6",
                tableRule: "#d7cec5",
                tableStrongRule: "#bca995",
                hairline: "#cfc6bb",
                frontMatterBg: "#f6f1ea",
                headingSizes: """
                h1 { font-size: 1.84em; margin-top: .2em; } h2 { font-size: 1.48em; } h3 { font-size: 1.24em; }
                h4 { font-size: 1.12em; } h5, h6 { font-size: 1em; }
                """,
                mathTextColor: UIColor(red: 0.11, green: 0.09, blue: 0.08, alpha: 1),
                markerChecked: UIColor(red: 0.74, green: 0.42, blue: 0.23, alpha: 1),
                markerUnchecked: UIColor(red: 0.45, green: 0.41, blue: 0.37, alpha: 1)
            )
        case .github:
            Palette(
                bodyFont: "-apple-system, \"Helvetica Neue\", \"PingFang SC\", sans-serif",
                text: "#333333",
                headingText: "#24292f",
                mutedText: "#777777",
                link: "#4183c4",
                inlineCodeBg: "#f3f4f4",
                inlineCodeText: "#333333",
                preBg: "#f8f8f8",
                preBorder: "#e7eaed",
                quoteText: "#777777",
                quoteBg: "#ffffff",
                quoteRule: "#dfe2e5",
                tableRule: "#dfe2e5",
                tableStrongRule: "#dfe2e5",
                hairline: "#eeeeee",
                frontMatterBg: "#f7f7f7",
                headingSizes: """
                h1 { font-size: 2.25em; margin-top: .2em; padding-bottom: .28em; border-bottom: 1px solid #eeeeee; }
                h2 { font-size: 1.75em; padding-bottom: .24em; border-bottom: 1px solid #eeeeee; }
                h3 { font-size: 1.5em; } h4 { font-size: 1.25em; } h5, h6 { font-size: 1em; }
                """,
                mathTextColor: UIColor(red: 0.14, green: 0.16, blue: 0.18, alpha: 1),
                markerChecked: UIColor(red: 0.25, green: 0.51, blue: 0.77, alpha: 1),
                markerUnchecked: UIColor(red: 0.47, green: 0.47, blue: 0.47, alpha: 1)
            )
        }
    }

    static func html(source: String, title: String, theme: ReaderTheme, baseURL: URL? = nil) -> String {
        let palette = palette(for: theme)
        let body = MarkdownParser.parse(source)
            .map { html(for: $0, baseURL: baseURL, theme: theme, palette: palette) }
            .joined(separator: "\n")
        return """
        <!doctype html>
        <html lang="\(htmlLanguageCode)">
        <head>
        <meta charset="utf-8">
        <title>\(escape(title))</title>
        <style>
        @page { margin: 16mm 17mm 18mm; }
        * { box-sizing: border-box; }
        body { color: \(palette.text); font-family: \(palette.bodyFont); font-size: 13pt; line-height: 1.58; margin: 0; overflow-wrap: anywhere; }
        h1, h2, h3, h4, h5, h6 { color: \(palette.headingText); font-weight: 600; line-height: 1.22; margin: 1.15em 0 .38em; break-after: avoid; }
        \(palette.headingSizes)
        h6 { color: \(palette.mutedText); }
        p { margin: .5em 0; }
        a { color: \(palette.link); text-decoration: none; }
        code { font-family: ui-monospace, "SFMono-Regular", Menlo, monospace; font-size: .9em; background: \(palette.inlineCodeBg); color: \(palette.inlineCodeText); padding: .08em .32em; border-radius: 3px; }
        pre { font-family: ui-monospace, "SFMono-Regular", Menlo, monospace; font-size: .9em; line-height: 1.5; white-space: pre-wrap; background: \(palette.preBg); border: 1px solid \(palette.preBorder); border-radius: 6px; padding: 11px 13px; break-inside: avoid; }
        pre code { color: \(palette.headingText); background: transparent; padding: 0; }
        blockquote { color: \(palette.quoteText); background: \(palette.quoteBg); border-left: 2px solid \(palette.quoteRule); border-radius: 5px; margin: .7em 0; padding: .45em .9em; }
        blockquote p { margin: 0; }
        ul, ol { margin: .5em 0; padding-left: 1.6em; }
        li { margin: .15em 0; }
        ul.task-list { list-style: none; padding-left: .4em; }
        span.task-marker { display: inline-block; width: 1.25em; margin-right: .35em; color: \(palette.link); font-family: sans-serif; }
        img.task-marker { display: inline-block; margin: 0 .45em 0 0; vertical-align: -.16em; }
        table { width: 100%; border-collapse: collapse; margin: .8em 0; font-size: .88em; line-height: 1.38; break-inside: auto; page-break-inside: auto; }
        thead { display: table-header-group; }
        tbody { break-inside: auto; page-break-inside: auto; }
        tr { break-inside: avoid; page-break-inside: avoid; break-after: auto; }
        th, td { border-bottom: 1px solid \(palette.tableRule); padding: 7px 9px; text-align: left; vertical-align: top; }
        th { border-top: 1px solid \(palette.tableStrongRule); border-bottom-color: \(palette.tableStrongRule); font-weight: 600; }
        tr:last-child td { border-bottom-color: \(palette.tableStrongRule); }
        hr { border: 0; border-top: 1px solid \(palette.hairline); margin: 1.6em 0; }
        img { display: block; max-width: 100%; height: auto; margin: .75em auto .25em; break-inside: avoid; }
        figure { margin: .75em 0; break-inside: avoid; } figcaption { color: \(palette.mutedText); font-size: .9em; text-align: center; }
        .front-matter { color: \(palette.quoteText); background: \(palette.frontMatterBg); border-radius: 6px; padding: .7em .9em; white-space: pre-wrap; break-inside: avoid; }
        img.math { display: block; margin: .9em auto; break-inside: avoid; }
        img.inline-math { display: inline-block; margin: 0; }
        pre.math { text-align: center; }
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

    private static func html(
        for block: MarkdownBlock,
        baseURL: URL?,
        theme: ReaderTheme,
        palette: Palette
    ) -> String {
        func inline(_ source: String) -> String {
            Self.inline(source, theme: theme, palette: palette)
        }

        switch block.kind {
        case let .heading(level, text):
            return "<h\(level)>\(inline(text))</h\(level)>"
        case let .paragraph(text):
            return "<p>\(inline(text))</p>"
        case let .blockquote(text):
            return "<blockquote><p>\(inline(text).replacingOccurrences(of: "\n", with: "<br>"))</p></blockquote>"
        case let .unorderedList(items):
            return list(items, tag: "ul", task: false, theme: theme, palette: palette)
        case let .orderedList(items):
            return list(items, tag: "ol", task: false, theme: theme, palette: palette)
        case let .taskList(items):
            return list(items, tag: "ul", task: true, theme: theme, palette: palette)
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
        case let .math(source):
            // Rendered formula images keep print output consistent with the
            // reader; raw LaTeX between $$ is the fallback for invalid input.
            return mathImageTag(latex: source, display: true, theme: theme, palette: palette)
                ?? "<pre class=\"math\">$$\(escape(source))$$</pre>"
        case let .frontMatter(source):
            return "<div class=\"front-matter\">\(escape(source))</div>"
        case .divider:
            return "<hr>"
        }
    }

    private static func list(
        _ items: [MarkdownListItem],
        tag: String,
        task: Bool,
        theme: ReaderTheme,
        palette: Palette
    ) -> String {
        let checkedMarker = task ? taskMarkerTag(checked: true, palette: palette) : nil
        let uncheckedMarker = task ? taskMarkerTag(checked: false, palette: palette) : nil
        let contents = items.map { item in
            var marker = ""
            if task {
                let checked = item.isChecked == true
                marker = (checked ? checkedMarker : uncheckedMarker)
                    ?? "<span class=\"task-marker\">\(checked ? "&#9745;" : "&#9744;")</span>"
            }
            return "<li>\(marker)\(inline(item.text, theme: theme, palette: palette))</li>"
        }.joined()
        let className = task ? " class=\"task-list\"" : ""
        return "<\(tag)\(className)>\(contents)</\(tag)>"
    }

    // The reader draws task markers with SF Symbols; embedding the same
    // symbols keeps print output visually identical to the rendered view.
    private static func taskMarkerTag(checked: Bool, palette: Palette) -> String? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        guard let symbol = UIImage(
            systemName: checked ? "checkmark.square.fill" : "square",
            withConfiguration: configuration
        )?.withTintColor(
            checked ? palette.markerChecked : palette.markerUnchecked,
            renderingMode: .alwaysOriginal
        ) else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: symbol.size)
        let image = renderer.image { _ in symbol.draw(at: .zero) }
        guard let imageData = image.pngData() else { return nil }

        let width = points(image.size.width)
        let height = points(image.size.height)
        let alt = checked ? "&#9745;" : "&#9744;"
        return "<img class=\"task-marker\" style=\"width:\(width)pt;height:\(height)pt\" alt=\"\(alt)\" src=\"data:image/png;base64,\(imageData.base64EncodedString())\">"
    }

    // Mirrors the reader: $…$ spans become rendered images sitting on the
    // text baseline, everything else goes through the markdown pipeline.
    private static func inline(_ source: String, theme: ReaderTheme, palette: Palette) -> String {
        InlineMathSegmenter.segments(in: source).map { segment in
            switch segment {
            case let .text(part):
                inlineText(part)
            case let .math(latex, isDisplay):
                mathImageTag(latex: latex, display: isDisplay, theme: theme, palette: palette)
                    ?? inlineText("$\(latex)$")
            }
        }.joined()
    }

    private static func mathImageTag(
        latex: String,
        display: Bool,
        theme: ReaderTheme,
        palette: Palette
    ) -> String? {
        guard let formula = MathRenderer.formula(
            latex: latex,
            fontSize: display ? 15 : 13,
            textColor: palette.mathTextColor,
            display: display,
            readerTheme: theme
        ), let imageData = formula.image.pngData() else {
            return nil
        }

        let source = "data:image/png;base64,\(imageData.base64EncodedString())"
        let width = points(formula.image.size.width)
        let height = points(formula.image.size.height)
        let alt = escapeAttribute(latex)
        if display {
            return "<img class=\"math\" style=\"width:\(width)pt;height:\(height)pt\" alt=\"\(alt)\" src=\"\(source)\">"
        }
        let descent = points(formula.descent)
        return "<img class=\"inline-math\" style=\"width:\(width)pt;height:\(height)pt;vertical-align:-\(descent)pt\" alt=\"\(alt)\" src=\"\(source)\">"
    }

    private static func points(_ value: CGFloat) -> String {
        String(format: "%.2f", value)
    }

    private static func inlineText(_ source: String) -> String {
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
