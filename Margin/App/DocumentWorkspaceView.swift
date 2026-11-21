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
    @State private var readingPosition = ReadingPosition()
    @State private var editorStartLocation = 0
    @State private var positionRestoreRevision = 0
    @State private var editorFindTrigger = 0
    @State private var requestedDocumentAction: DocumentActionRequest?
    // The URL after an in-app rename. DocumentGroup's published fileURL keeps
    // the pre-rename value until the document is reopened, while its internal
    // file presenter follows the coordinated move — so the document stays
    // open and only our URL-derived UI needs the override.
    @State private var renamedFileURL: URL?

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
                position: readingPosition,
                positionRestoreRevision: positionRestoreRevision,
                onToggleTask: toggleTask
            )
            .opacity(mode == .read ? 1 : 0)
            .allowsHitTesting(mode == .read)
            .accessibilityHidden(mode != .read)

            if mode == .live {
                LiveMarkdownEditorView(
                    text: $text,
                    isFocused: editorFocus(in: .live),
                    initialLocation: editorStartLocation,
                    position: readingPosition,
                    textScale: textScale,
                    baseURL: effectiveFileURL?.deletingLastPathComponent(),
                    readerTheme: readerTheme,
                    isCurrentEditor: { mode == .live }
                )
                .transition(.opacity)
            } else if mode == .source {
                MarkdownEditorView(
                    text: $text,
                    initialLocation: editorStartLocation,
                    position: readingPosition,
                    textScale: textScale,
                    isFocused: editorFocus(in: .source),
                    findTrigger: editorFindTrigger,
                    liveFormatting: false,
                    readerTheme: readerTheme,
                    isCurrentEditor: { mode == .source }
                )
                    .transition(.opacity)
            }
        }
        .environment(\.colorScheme, resolvedColorScheme)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .background(InteractivePopGestureRestorer())
        .safeAreaInset(edge: .top, spacing: 0) {
            PagesDocumentNavigationBar(
                mode: Binding(get: { mode }, set: selectMode),
                documentName: displayName,
                theme: theme,
                onDismiss: dismissWorkspace,
                onSearch: presentSearch,
                onSettings: presentSettings,
                onOutline: presentOutline,
                onDocumentInfo: presentDocumentInfo,
                onDocumentAction: requestDocumentAction,
                canMove: effectiveFileURL != nil,
                canRename: effectiveFileURL != nil
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: mode.isEditing)
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

    private func selectMode(_ newMode: WorkspaceMode) {
        guard newMode != mode else { return }
        if newMode == .read {
            finishEditing()
        } else if mode == .read {
            beginEditing(in: newMode)
        } else {
            editorStartLocation = readingPosition.editorCaretLocation
            editorFindTrigger = 0
            mode = newMode
        }
    }

    private func editorFocus(in editorMode: WorkspaceMode) -> Binding<Bool> {
        Binding(get: { mode == editorMode && isEditorFocused }, set: { focused in
            if mode == editorMode { isEditorFocused = focused }
        })
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

    private func beginEditing(in mode: WorkspaceMode) {
        dismissSearch()
        readerSource = text
        // Open the editor on the passage being read, not at the top.
        editorStartLocation = readingPosition.topVisibleLine.map {
            SourceLines.utf16Offset(ofLine: $0, in: text)
        } ?? 0
        readingPosition.editorCaretLocation = editorStartLocation
        editorFindTrigger = 0
        self.mode = mode
        Task { @MainActor in
            await Task.yield()
            if self.mode.isEditing {
                isEditorFocused = true
            }
        }
    }

    private func finishEditing() {
        isEditorFocused = false
        if mode.isEditing {
            // And come back to the reader where the caret was left.
            readingPosition.pendingLine = SourceLines.lineIndex(
                atUTF16Offset: readingPosition.editorCaretLocation,
                in: text
            )
            positionRestoreRevision &+= 1
        }
        readerSource = text
        mode = .read
    }

    // In reading mode the magnifier opens the document search bar; in edit
    // mode it presents UITextView's system find panel instead.
    private func presentSearch() {
        if mode.isEditing {
            if mode == .live { selectMode(.source) }
            editorFindTrigger &+= 1
        } else {
            searchSession.readingPosition = readingPosition
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
                // The heading wins over returning to the caret.
                readingPosition.pendingLine = nil
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
