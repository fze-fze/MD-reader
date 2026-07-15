import SwiftUI

struct DocumentWorkspaceView: View {
    @Binding var text: String
    let fileURL: URL?

    @AppStorage("readerAppearance") private var appearance = ReaderAppearance.system
    @AppStorage("readerTextScale") private var textScale = 1.0
    @AppStorage("readerTheme") private var readerTheme = ReaderTheme.claude
    @State private var mode: WorkspaceMode = .read
    @State private var presentedSheet: WorkspaceSheet?
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var scrollTarget: Int?
    @State private var isEditorFocused = false

    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolvedColorScheme: ColorScheme {
        appearance.colorScheme ?? systemColorScheme
    }

    private var displayName: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? "未命名"
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
                    searchText: searchText,
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
        .modifier(
            DocumentSearchModifier(
                searchText: $searchText,
                isPresented: $isSearchPresented
            )
        )
        .modifier(
            DocumentActionsModifier(
                text: text,
                fileURL: fileURL,
                displayName: displayName
            )
        )
        .onChange(of: isSearchPresented) { _, isPresented in
            if !isPresented {
                searchText = ""
            }
        }
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
        .sensoryFeedback(.selection, trigger: mode)
        .preferredColorScheme(appearance.colorScheme)
    }

    @ToolbarContentBuilder
    private var workspaceToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if mode == .read {
                Button("搜索", systemImage: "magnifyingglass") {
                    isSearchPresented = true
                }
                workspaceMenu
                Button("编辑", action: beginEditing)
            } else {
                Button("完成", action: finishEditing)
                    .buttonStyle(.glassProminent)
                    .tint(theme.accent)
            }
        }
    }

    private var workspaceMenu: some View {
        Menu("更多", systemImage: "ellipsis") {
            Button("目录", systemImage: "list.bullet.indent") {
                presentedSheet = .outline
            }
            Button("阅读设置", systemImage: "textformat.size") {
                presentedSheet = .settings
            }
            Button("文档信息", systemImage: "info.circle") {
                presentedSheet = .info
            }
        }
    }

    private func beginEditing() {
        isSearchPresented = false
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

    private func toggleTask(atLine lineNumber: Int) {
        text = MarkdownTaskToggler.toggledSource(text, taskAtLine: lineNumber)
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

private struct DocumentSearchModifier: ViewModifier {
    @Binding var searchText: String
    @Binding var isPresented: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPresented {
            content.searchable(
                text: $searchText,
                isPresented: $isPresented,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "在文档中查找"
            )
        } else {
            content
        }
    }
}
