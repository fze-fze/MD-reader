import SwiftUI

struct ThemeSelectionButton: View {
    @AppStorage("readerTheme") private var selectedTheme = ReaderTheme.claude

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button("launch.select_theme", action: ThemePickerPresenter.present)
            .tint(MarkdownTheme(readerTheme: selectedTheme, colorScheme: colorScheme).accent)
            .accessibilityHint(
                L10n.format("theme.picker.current_hint", selectedTheme.titleText)
            )
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
