import SwiftUI

struct DocumentWorkspaceView: View {
    @Binding private var text: String
    private let fileURL: URL?

    @AppStorage("readerAppearance") private var appearance = ReaderAppearance.system
    @AppStorage("readerTextScale") private var textScale = 1.0
    @AppStorage("readerTheme") private var readerTheme = ReaderTheme.claude
    @State private var mode: WorkspaceMode = .read
    @State private var readerSource: String
    @State private var presentedSheet: WorkspaceSheet?
    @State private var searchSession = DocumentSearchSession()
    @State private var isSearchPresented = false
    @State private var scrollTarget: Int?
    @State private var isEditorFocused = false
    @State private var requestedDocumentAction: DocumentActionRequest?

    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    init(text: Binding<String>, fileURL: URL?) {
        _text = text
        _readerSource = State(initialValue: text.wrappedValue)
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

            MarkdownReaderView(
                source: readerSource,
                searchSession: searchSession,
                scrollTarget: $scrollTarget,
                textScale: textScale,
                baseURL: fileURL?.deletingLastPathComponent(),
                readerTheme: readerTheme,
                onToggleTask: toggleTask
            )
            .opacity(mode == .read ? 1 : 0)
            .allowsHitTesting(mode == .read)
            .accessibilityHidden(mode != .read)

            if mode == .edit {
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
        .toolbarVisibility(.hidden, for: .navigationBar)
        .background(InteractivePopGestureRestorer())
        .safeAreaInset(edge: .top, spacing: 0) {
            PagesDocumentNavigationBar(
                mode: mode,
                theme: theme,
                canUseReaderTools: mode == .read,
                onDismiss: dismissWorkspace,
                onSearch: presentSearch,
                onToggleMode: toggleWorkspaceMode,
                onSettings: presentSettings,
                onOutline: presentOutline,
                onDocumentInfo: presentDocumentInfo,
                onDocumentAction: requestDocumentAction,
                canMoveOrRename: fileURL != nil
            )
        }
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
                displayName: displayName,
                requestedAction: $requestedDocumentAction
            )
        )
        .onAppear {
            if QuickActionDocumentCreator.consumeEditorRequest(for: fileURL) {
                beginEditing()
            }
        }
        .onChange(of: text) { _, updatedText in
            if mode == .read {
                readerSource = updatedText
            }
        }
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

    private func dismissWorkspace() {
        dismiss()
    }

    private func toggleWorkspaceMode() {
        if mode == .read {
            beginEditing()
        } else {
            finishEditing()
        }
    }

    private func presentSettings() {
        presentedSheet = .settings
    }

    private func presentOutline() {
        presentedSheet = .outline
    }

    private func presentDocumentInfo() {
        presentedSheet = .info
    }

    private func requestDocumentAction(_ action: DocumentActionRequest) {
        requestedDocumentAction = action
    }

    private func beginEditing() {
        dismissSearch()
        readerSource = text
        mode = .edit
        Task { @MainActor in
            await Task.yield()
            isEditorFocused = true
        }
    }

    private func finishEditing() {
        isEditorFocused = false
        readerSource = text
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
        let updatedText = MarkdownTaskToggler.toggledSource(
            text,
            taskAtLine: lineNumber
        )
        text = updatedText
        readerSource = updatedText
    }

    @ViewBuilder
    private func sheetView(_ sheet: WorkspaceSheet) -> some View {
        switch sheet {
        case .outline:
            OutlineView(
                headings: MarkdownParser.headings(in: text),
                readerTheme: readerTheme
            ) { headingID in
                finishEditing()
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
