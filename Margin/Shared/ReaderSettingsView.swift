import SwiftUI

struct ReaderSettingsView: View {
    @Binding private var appearance: ReaderAppearance
    @Binding private var textScale: Double
    @Binding private var readerTheme: ReaderTheme
    @State private var draftTextScale: Double

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(
        appearance: Binding<ReaderAppearance>,
        textScale: Binding<Double>,
        readerTheme: Binding<ReaderTheme>
    ) {
        _appearance = appearance
        _textScale = textScale
        _readerTheme = readerTheme
        _draftTextScale = State(initialValue: textScale.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("主题") {
                    NavigationLink {
                        ThemePickerView(selectedTheme: $readerTheme)
                    } label: {
                        LabeledContent("文稿主题") {
                            Text(readerTheme.title)
                        }
                    }
                }

                Section("外观") {
                    Picker("显示模式", selection: $appearance) {
                        ForEach(ReaderAppearance.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("排版") {
                    LabeledContent("正文大小") {
                        HStack {
                            Image(systemName: "textformat.size.smaller")
                                .accessibilityHidden(true)
                            Slider(
                                value: $draftTextScale,
                                in: 0.85...1.3,
                                step: 0.05,
                                onEditingChanged: updateTextScale
                            )
                                .frame(maxWidth: 190)
                            Image(systemName: "textformat.size.larger")
                                .accessibilityHidden(true)
                        }
                    }
                    Button("恢复默认排版") {
                        draftTextScale = 1
                        commitTextScale()
                    }
                    .disabled(draftTextScale == 1)
                }
            }
            .tint(theme.accent)
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(appearance.colorScheme)
        .onDisappear(perform: commitTextScale)
    }

    private var theme: MarkdownTheme {
        MarkdownTheme(readerTheme: readerTheme, colorScheme: colorScheme)
    }

    private func updateTextScale(isEditing: Bool) {
        if !isEditing {
            commitTextScale()
        }
    }

    private func commitTextScale() {
        guard textScale != draftTextScale else { return }
        textScale = draftTextScale
    }
}
