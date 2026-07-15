import Foundation

nonisolated struct MarkdownBlock: Identifiable, Equatable, Sendable {
    let id: Int
    let kind: Kind

    enum Kind: Equatable, Sendable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case blockquote(String)
        case unorderedList([MarkdownListItem])
        case orderedList([MarkdownListItem])
        case taskList([MarkdownListItem])
        case code(language: String?, source: String)
        case table(headers: [String], rows: [[String]])
        case image(alt: String, source: String)
        case frontMatter(String)
        case divider
    }

    var searchableText: String {
        searchableFragments.joined(separator: " ")
    }

    var searchableFragments: [String] {
        switch kind {
        case let .heading(_, text), let .paragraph(text), let .blockquote(text):
            [Self.inlinePlainText(text)]
        case let .frontMatter(text):
            [text]
        case let .unorderedList(items), let .orderedList(items), let .taskList(items):
            items.map { Self.inlinePlainText($0.text) }
        case let .code(_, source):
            [source]
        case let .table(headers, rows):
            (headers + rows.flatMap { $0 }).map(Self.inlinePlainText)
        case let .image(alt, _):
            alt.isEmpty ? [] : [Self.inlinePlainText(alt)]
        case .divider:
            []
        }
    }

    private static func inlinePlainText(_ source: String) -> String {
        guard let attributed = try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) else {
            return source
        }
        return String(attributed.characters)
    }
}

nonisolated struct MarkdownListItem: Identifiable, Equatable, Sendable {
    let id: Int
    let text: String
    let isChecked: Bool?
}

nonisolated struct MarkdownHeading: Identifiable, Equatable, Sendable {
    let id: Int
    let level: Int
    let text: String
}
