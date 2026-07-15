import SwiftUI

enum ReaderTheme: String, CaseIterable, Identifiable {
    case claude
    case github

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .claude: "Claude"
        case .github: "GitHub"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .claude: "Anthropic Serif 与温暖纸张配色"
        case .github: "Typora 经典 GitHub 清爽排版"
        }
    }

    var systemImage: String {
        switch self {
        case .claude: "text.book.closed"
        case .github: "chevron.left.forwardslash.chevron.right"
        }
    }
}
