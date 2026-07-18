import Foundation

enum MarkdownEditAction: Identifiable {
    case body
    case heading1
    case heading2
    case heading3
    case bold
    case italic
    case link
    case code
    case inlineMath
    case quote
    case list
    case task
    case mathBlock

    var id: Self { self }

    var label: String {
        switch self {
        case .body: L10n.string("editor.body")
        case .heading1: L10n.string("editor.heading1")
        case .heading2: L10n.string("editor.heading2")
        case .heading3: L10n.string("editor.heading3")
        case .bold: L10n.string("editor.bold")
        case .italic: L10n.string("editor.italic")
        case .link: L10n.string("editor.link")
        case .code: L10n.string("editor.inline_code")
        case .inlineMath: L10n.string("editor.inline_math")
        case .quote: L10n.string("editor.quote")
        case .list: L10n.string("editor.bullet_list")
        case .task: L10n.string("editor.task_list")
        case .mathBlock: L10n.string("editor.math_block")
        }
    }

    var systemImage: String {
        switch self {
        case .body: "textformat"
        case .heading1: "1.square"
        case .heading2: "2.square"
        case .heading3: "3.square"
        case .bold: "bold"
        case .italic: "italic"
        case .link: "link"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .inlineMath: "x.squareroot"
        case .quote: "text.quote"
        case .list: "list.bullet"
        case .task: "checklist"
        case .mathBlock: "function"
        }
    }
}
