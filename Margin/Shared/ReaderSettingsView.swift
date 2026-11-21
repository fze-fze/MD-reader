import SwiftUI

struct ReaderSettingsView: View {
    @Binding private var appearance: ReaderAppearance
    @Binding private var textScale: Double
    @Binding private var readerTheme: ReaderTheme
    @Binding private var bodyFont: ReaderFontChoice
    @Binding private var headingFont: ReaderFontChoice
    @State private var draftTextScale: Double

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(
        appearance: Binding<ReaderAppearance>,
        textScale: Binding<Double>,
        readerTheme: Binding<ReaderTheme>,
        bodyFont: Binding<ReaderFontChoice>,
        headingFont: Binding<ReaderFontChoice>
    ) {
        _appearance = appearance
        _textScale = textScale
        _readerTheme = readerTheme
        _bodyFont = bodyFont
        _headingFont = headingFont
        _draftTextScale = State(initialValue: textScale.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.section.theme") {
                    NavigationLink {
                        ThemePickerView(selectedTheme: $readerTheme)
                    } label: {
                        LabeledContent("settings.document_theme") {
                            Text(readerTheme.title)
                        }
                    }
                }

                Section("settings.section.appearance") {
                    Picker("settings.display_mode", selection: $appearance) {
                        ForEach(ReaderAppearance.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("settings.section.typography") {
                    Picker("settings.body_font", selection: $bodyFont) {
                        ForEach(ReaderFontChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    Picker("settings.heading_font", selection: $headingFont) {
                        ForEach(ReaderFontChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    LabeledContent("settings.body_size") {
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
                    Button("settings.reset_typography") {
                        draftTextScale = 1
                        commitTextScale()
                        bodyFont = .themeDefault
                        headingFont = .themeDefault
                    }
                    .disabled(
                        draftTextScale == 1
                            && bodyFont == .themeDefault
                            && headingFont == .themeDefault
                    )
                }
            }
            .tint(theme.accent)
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
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
