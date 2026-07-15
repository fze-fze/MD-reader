import SwiftUI

struct MarkdownAccessoryBar: View {
    let readerTheme: ReaderTheme
    let onAction: (MarkdownEditAction) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let inlineActions: [MarkdownEditAction] = [.bold, .italic, .link, .code]
    private let blockActions: [MarkdownEditAction] = [.list, .task, .quote]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 2) {
                formatMenu
                barDivider

                ForEach(inlineActions) { action in
                    actionButton(action)
                }

                barDivider

                ForEach(blockActions) { action in
                    actionButton(action)
                }
            }
            .padding(.horizontal, 8)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider().overlay(theme.separator.opacity(0.7))
        }
    }

    private var formatMenu: some View {
        Menu("editor.format", systemImage: "textformat") {
            Button(MarkdownEditAction.body.label, systemImage: MarkdownEditAction.body.systemImage) {
                onAction(.body)
            }
            Section("editor.heading_section") {
                Button(MarkdownEditAction.heading1.label, systemImage: MarkdownEditAction.heading1.systemImage) {
                    onAction(.heading1)
                }
                Button(MarkdownEditAction.heading2.label, systemImage: MarkdownEditAction.heading2.systemImage) {
                    onAction(.heading2)
                }
                Button(MarkdownEditAction.heading3.label, systemImage: MarkdownEditAction.heading3.systemImage) {
                    onAction(.heading3)
                }
            }
        }
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityHint(Text("editor.format_hint"))
    }

    private var barDivider: some View {
        Divider()
            .frame(height: 22)
            .overlay(theme.separator)
            .padding(.horizontal, 3)
    }

    private func actionButton(_ action: MarkdownEditAction) -> some View {
        Button(action.label, systemImage: action.systemImage) {
            onAction(action)
        }
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
    }

    private var theme: MarkdownTheme {
        MarkdownTheme(readerTheme: readerTheme, colorScheme: colorScheme)
    }
}
