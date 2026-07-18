import SwiftUI

struct MarkdownAccessoryBar: View {
    let readerTheme: ReaderTheme
    let onAction: (MarkdownEditAction) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let inlineActions: [MarkdownEditAction] = [.bold, .italic, .link, .code, .inlineMath]
    // mathBlock leads so it sits right beside inlineMath across the divider.
    private let blockActions: [MarkdownEditAction] = [.mathBlock, .list, .task, .quote]

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
        .tint(theme.accent)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider().overlay(theme.separator.opacity(0.7))
        }
    }

    private var formatMenu: some View {
        Menu {
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
        } label: {
            Label("editor.format", systemImage: "textformat")
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .accessibilityHint(Text("editor.format_hint"))
    }

    private var barDivider: some View {
        Divider()
            .frame(height: 22)
            .overlay(theme.separator)
            .padding(.horizontal, 3)
    }

    private func actionButton(_ action: MarkdownEditAction) -> some View {
        Button {
            onAction(action)
        } label: {
            Label(action.label, systemImage: action.systemImage)
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
    }

    private var theme: MarkdownTheme {
        MarkdownTheme(readerTheme: readerTheme, colorScheme: colorScheme)
    }
}
