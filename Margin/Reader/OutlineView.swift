import SwiftUI

struct OutlineView: View {
    let headings: [MarkdownHeading]
    let readerTheme: ReaderTheme
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            Group {
                if headings.isEmpty {
                    ContentUnavailableView(
                        "outline.empty_title",
                        systemImage: "list.bullet.indent",
                        description: Text("outline.empty_description")
                    )
                } else {
                    List(headings) { heading in
                        Button {
                            dismiss()
                            onSelect(heading.id)
                        } label: {
                            Text(heading.text)
                                .font(heading.level <= 2 ? .headline : .body)
                                .foregroundStyle(heading.level == 6 ? theme.textSecondary : theme.textPrimary)
                                .padding(.leading, CGFloat(max(0, heading.level - 1)) * 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(theme.sidebarSurface)
                    }
                    .scrollContentBackground(.hidden)
                    .background(theme.sidebarSurface)
                }
            }
            .navigationTitle("outline.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var theme: MarkdownTheme {
        MarkdownTheme(readerTheme: readerTheme, colorScheme: colorScheme)
    }
}
