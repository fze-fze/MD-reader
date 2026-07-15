import SwiftUI

struct ThemeSelectionButton: View {
    @AppStorage("readerTheme") private var selectedTheme = ReaderTheme.claude

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button("选取主题", action: ThemePickerPresenter.present)
            .tint(MarkdownTheme(readerTheme: selectedTheme, colorScheme: colorScheme).accent)
            .accessibilityHint("当前为\(selectedTheme.titleText)，打开主题选择页")
    }
}

private extension ReaderTheme {
    var titleText: String {
        switch self {
        case .claude: "Claude"
        case .github: "GitHub"
        }
    }
}
