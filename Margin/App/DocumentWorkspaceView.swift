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
    @State private var editorFindTrigger = 0
    @State private var requestedDocumentAction: DocumentActionRequest?
    // The URL after an in-app rename. DocumentGroup's published fileURL keeps
    // the pre-rename value until the document is reopened, while its internal
    // file presenter follows the coordinated move — so the document stays
    // open and only our URL-derived UI needs the override.
    @State private var renamedFileURL: URL?

    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(text: Binding<String>, fileURL: URL?) {
        _text = text
        _readerSource = State(initialValue: text.wrappedValue)
        self.fileURL = fileURL
    }

    private var resolvedColorScheme: ColorScheme {
        appearance.colorScheme ?? systemColorScheme
    }

    private var effectiveFileURL: URL? {
        renamedFileURL ?? fileURL
    }

    private var displayName: String {
        effectiveFileURL?.deletingPathExtension().lastPathComponent
            ?? L10n.string("workspace.untitled")
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
                baseURL: effectiveFileURL?.deletingLastPathComponent(),
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
                    findTrigger: editorFindTrigger,
                    readerTheme: readerTheme
                )
                    .transition(.opacity)
            }
        }
        .environment(\.colorScheme, resolvedColorScheme)
        // DocumentGroup's own bar is the document chrome: its back button,
        // file name, and title menu are built from the open document, already
        // in the Pages-style editor layout. Hiding it and drawing a
        // replacement is what left a second bar on screen when another app
        // opened a file. `.toolbarRole` is deliberately not set — DocumentGroup
        // picks the role itself, and overriding it has produced a duplicate
        // back button on iPad.
        .toolbar {
            WorkspaceToolbarContent(
                mode: mode,
                documentName: displayName,
                onSearch: presentSearch,
                onToggleMode: toggleWorkspaceMode,
                onSettings: presentSettings,
                onOutline: presentOutline,
                onDocumentInfo: presentDocumentInfo,
                onDocumentAction: requestDocumentAction,
                canMove: effectiveFileURL != nil,
                canRename: effectiveFileURL != nil
            )
        }
        .tint(theme.accent)
        .background(InteractivePopGestureRestorer())
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
                fileURL: effectiveFileURL,
                displayName: displayName,
                requestedAction: $requestedDocumentAction,
                onRenamed: { renamedFileURL = $0 }
            )
        )
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

    // In reading mode the magnifier opens the document search bar; in edit
    // mode it presents UITextView's system find panel instead.
    private func presentSearch() {
        if mode == .edit {
            editorFindTrigger &+= 1
        } else {
            searchSession.activate()
            isSearchPresented = true
        }
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
                fileURL: effectiveFileURL,
                statistics: DocumentStatistics(source: text)
            )
        }
    }
}

private enum WorkspaceSheet: String, Identifiable {
    case outline, settings, info
    var id: Self { self }
}
