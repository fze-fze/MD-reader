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
    case quote
    case list
    case task

    var id: Self { self }

    var label: String {
        switch self {
        case .body: "正文"
        case .heading1: "标题 1"
        case .heading2: "标题 2"
        case .heading3: "标题 3"
        case .bold: "粗体"
        case .italic: "斜体"
        case .link: "链接"
        case .code: "行内代码"
        case .quote: "引用"
        case .list: "项目列表"
        case .task: "任务列表"
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
        case .quote: "text.quote"
        case .list: "list.bullet"
        case .task: "checklist"
        }
    }
}
