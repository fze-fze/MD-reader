import SwiftUI

enum ReaderTheme: String, CaseIterable, Hashable, Identifiable {
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
        case .claude: "theme.claude.subtitle"
        case .github: "theme.github.subtitle"
        }
    }

    var systemImage: String {
        switch self {
        case .claude: "text.book.closed"
        case .github: "chevron.left.forwardslash.chevron.right"
        }
    }
}
