import SwiftUI

struct DocumentWorkspaceView: View {
    @Binding private var text: String
    private let fileURL: URL?

    @AppStorage("readerAppearance") private var appearance = ReaderAppearance.system
    @AppStorage("readerTextScale") private var textScale = 1.0
    @AppStorage("readerTheme") private var readerTheme = ReaderTheme.claude
    @State private var mode: WorkspaceMode = .read
    @State private var presentedSheet: WorkspaceSheet?
    @State private var searchSession = DocumentSearchSession()
    @State private var isSearchPresented = false
    @State private var scrollTarget: Int?
    @State private var isEditorFocused = false

    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(text: Binding<String>, fileURL: URL?) {
        _text = text
        self.fileURL = fileURL
    }

    private var resolvedColorScheme: ColorScheme {
        appearance.colorScheme ?? systemColorScheme
    }

    private var displayName: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? L10n.string("workspace.untitled")
    }

    private var theme: MarkdownTheme {
        MarkdownTheme(readerTheme: readerTheme, colorScheme: resolvedColorScheme)
    }

    var body: some View {
        ZStack {
            theme.canvas
                .ignoresSafeArea()

            if mode == .read {
                MarkdownReaderView(
                    source: text,
                    searchSession: searchSession,
                    scrollTarget: $scrollTarget,
                    textScale: textScale,
                    baseURL: fileURL?.deletingLastPathComponent(),
                    readerTheme: readerTheme,
                    onToggleTask: toggleTask
                )
                .transition(.opacity)
            } else {
                MarkdownEditorView(
                    text: $text,
                    textScale: textScale,
                    isFocused: $isEditorFocused,
                    readerTheme: readerTheme
                )
                    .transition(.opacity)
            }
        }
        .environment(\.colorScheme, resolvedColorScheme)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if mode == .read, isSearchPresented {
                DocumentSearchBar(
                    session: searchSession,
                    theme: theme,
                    onDismiss: dismissSearch
                )
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
                )
            }
        }
        .modifier(
            DocumentActionsModifier(
                text: text,
                fileURL: fileURL,
                displayName: displayName
            )
        )
        .onAppear {
            if QuickActionDocumentCreator.consumeEditorRequest(for: fileURL) {
                beginEditing()
            }
        }
        .toolbar { workspaceToolbar }
        .sheet(item: $presentedSheet) { sheet in
            sheetView(sheet)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: mode)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.16),
            value: isSearchPresented
        )
        .sensoryFeedback(.selection, trigger: mode)
        .preferredColorScheme(appearance.colorScheme)
    }

    @ToolbarContentBuilder
    private var workspaceToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if mode == .read {
                Button("workspace.search", systemImage: "magnifyingglass", action: presentSearch)
                    .keyboardShortcut("f", modifiers: .command)
                workspaceMenu
                Button("workspace.edit", action: beginEditing)
            } else {
                Button("common.done", action: finishEditing)
                    .buttonStyle(.glassProminent)
                    .tint(theme.accent)
            }
        }
    }

    private var workspaceMenu: some View {
        Menu("workspace.more", systemImage: "ellipsis") {
            Button("workspace.outline", systemImage: "list.bullet.indent") {
                presentedSheet = .outline
            }
            Button("workspace.reader_settings", systemImage: "textformat.size") {
                presentedSheet = .settings
            }
            Button("workspace.document_info", systemImage: "info.circle") {
                presentedSheet = .info
            }
        }
    }

    private func beginEditing() {
        dismissSearch()
        mode = .edit
        Task { @MainActor in
            await Task.yield()
            isEditorFocused = true
        }
    }

    private func finishEditing() {
        isEditorFocused = false
        mode = .read
    }

    private func presentSearch() {
        searchSession.activate()
        isSearchPresented = true
    }

    private func dismissSearch() {
        isSearchPresented = false
        searchSession.deactivate()
    }

    private func toggleTask(atLine lineNumber: Int) {
        text = MarkdownTaskToggler.toggledSource(
            text,
            taskAtLine: lineNumber
        )
    }

    @ViewBuilder
    private func sheetView(_ sheet: WorkspaceSheet) -> some View {
        switch sheet {
        case .outline:
            OutlineView(
                headings: MarkdownParser.headings(in: text),
                readerTheme: readerTheme
            ) { headingID in
                mode = .read
                scrollTarget = headingID
            }
        case .settings:
            ReaderSettingsView(
                appearance: $appearance,
                textScale: $textScale,
                readerTheme: $readerTheme
            )
        case .info:
            DocumentInfoView(
                fileURL: fileURL,
                statistics: DocumentStatistics(source: text)
            )
        }
    }
}

private enum WorkspaceSheet: String, Identifiable {
    case outline, settings, info
    var id: Self { self }
}
