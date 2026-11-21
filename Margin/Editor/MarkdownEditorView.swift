import SwiftUI

struct MarkdownEditorView: View {
    struct AccessoryRequest: Equatable {
        let id = UUID()
        let action: MarkdownEditAction
    }

    @Binding var text: String
    let position: ReadingPosition
    let textScale: Double
    @Binding var isFocused: Bool
    let findTrigger: Int
    let liveFormatting: Bool
    let readerTheme: ReaderTheme
    let embedded: Bool
    let sourceOffset: Int
    let accessoryRequest: AccessoryRequest?
    let isCurrentEditor: () -> Bool
    let regionID: UUID?
    let regionSelection: Binding<NSRange>?
    let isComposing: Binding<Bool>?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    @State private var sourceSelection: NSRange

    // The editor owns a synchronous mirror of the document text. Feeding the
    // UITextView from the DocumentGroup binding directly lets a stale binding
    // round-trip revert fresh keystrokes in updateUIView, which flings the
    // caret — and the scroll position — to the end of the document. While the
    // editor is on screen this mirror is the source of truth and only pushes
    // outward; the editor is recreated from the binding on each edit session.
    @State private var sourceText: String

    private var editorText: String {
        get { embedded ? text : sourceText }
        nonmutating set {
            if !embedded { sourceText = newValue }
            if text != newValue { text = newValue }
        }
    }

    private var selectedRange: NSRange {
        get { regionSelection?.wrappedValue ?? sourceSelection }
        nonmutating set {
            if let regionSelection {
                regionSelection.wrappedValue = newValue
            } else {
                sourceSelection = newValue
            }
            if isCurrentEditor() { position.editorCaretLocation = sourceOffset + newValue.location }
        }
    }

    init(
        text: Binding<String>,
        initialLocation: Int,
        position: ReadingPosition,
        textScale: Double,
        isFocused: Binding<Bool>,
        findTrigger: Int,
        liveFormatting: Bool,
        readerTheme: ReaderTheme,
        embedded: Bool = false,
        sourceOffset: Int = 0,
        accessoryRequest: AccessoryRequest? = nil,
        isCurrentEditor: @escaping () -> Bool = { true },
        regionID: UUID? = nil,
        regionSelection: Binding<NSRange>? = nil,
        isComposing: Binding<Bool>? = nil
    ) {
        _text = text
        _sourceText = State(initialValue: text.wrappedValue)
        _sourceSelection = State(initialValue: NSRange(location: initialLocation, length: 0))
        self.position = position
        self.textScale = textScale
        _isFocused = isFocused
        self.findTrigger = findTrigger
        self.liveFormatting = liveFormatting
        self.readerTheme = readerTheme
        self.embedded = embedded
        self.sourceOffset = sourceOffset
        self.accessoryRequest = accessoryRequest
        self.isCurrentEditor = isCurrentEditor
        self.regionID = regionID
        self.regionSelection = regionSelection
        self.isComposing = isComposing
    }

    private var theme: MarkdownTheme {
        MarkdownTheme(readerTheme: readerTheme, colorScheme: colorScheme)
    }

    var body: some View {
        let padding = MarkdownTypography.columnPadding(compact: horizontalSizeClass == .compact)
        NativeMarkdownTextView(
            text: Binding(get: { editorText }, set: { editorText = $0 }),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            isFocused: $isFocused,
            findTrigger: findTrigger,
            liveFormatting: liveFormatting,
            theme: theme,
            readerTheme: readerTheme,
            bodySize: bodySize * textScale,
            embedded: embedded,
            regionID: regionID,
            isComposing: isComposing
        )
        .frame(maxWidth: theme.contentMaxWidth + padding.leading + padding.trailing)
        .frame(maxWidth: .infinity)
        .background(theme.canvas)
        .onChange(of: accessoryRequest) { _, request in
            if let request { apply(request.action) }
        }
        .safeAreaBar(edge: .bottom) {
            if isFocused && !embedded {
                MarkdownAccessoryBar(readerTheme: readerTheme) { action in
                    apply(action)
                }
            }
        }
    }

    private func apply(_ action: MarkdownEditAction) {
        switch action {
        case .body: setHeadingPrefix("")
        case .heading1: setHeadingPrefix("# ")
        case .heading2: setHeadingPrefix("## ")
        case .heading3: setHeadingPrefix("### ")
        case .bold:
            wrapSelection(
                prefix: "**",
                suffix: "**",
                placeholder: L10n.string("editor.placeholder.bold")
            )
        case .italic:
            wrapSelection(
                prefix: "_",
                suffix: "_",
                placeholder: L10n.string("editor.placeholder.italic")
            )
        case .link:
            wrapSelection(
                prefix: "[",
                suffix: "](https://)",
                placeholder: L10n.string("editor.placeholder.link")
            )
        case .code:
            wrapSelection(
                prefix: "`",
                suffix: "`",
                placeholder: L10n.string("editor.placeholder.code")
            )
        case .inlineMath:
            wrapSelection(
                prefix: "$",
                suffix: "$",
                placeholder: L10n.string("editor.placeholder.math")
            )
        case .quote: toggleLinePrefix(.quote)
        case .list: toggleLinePrefix(.list)
        case .task: toggleLinePrefix(.task)
        case .mathBlock:
            insertMathBlock(placeholder: L10n.string("editor.placeholder.math"))
        }
    }

    private func setHeadingPrefix(_ prefix: String) {
        let nsText = editorText as NSString
        let safeLocation = min(selectedRange.location, nsText.length)
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
        let line = nsText.substring(with: lineRange)
        let hashCount = line.prefix(while: { $0 == "#" }).count
        let hasHeadingPrefix = (1...6).contains(hashCount) && line.dropFirst(hashCount).first == " "
        let oldPrefixLength = hasHeadingPrefix ? hashCount + 1 : 0
        let replacementRange = NSRange(location: lineRange.location, length: oldPrefixLength)
        editorText = nsText.replacingCharacters(in: replacementRange, with: prefix)

        let offsetInLine = max(0, selectedRange.location - lineRange.location)
        let adjustedOffset = max(0, offsetInLine - oldPrefixLength) + (prefix as NSString).length
        selectedRange.location = lineRange.location + adjustedOffset
    }

    private func wrapSelection(prefix: String, suffix: String, placeholder: String) {
        guard let range = Range(selectedRange, in: editorText) else { return }
        let selected = String(editorText[range])
        let content = selected.isEmpty ? placeholder : selected
        let replacement = prefix + content + suffix
        editorText.replaceSubrange(range, with: replacement)
        let prefixLength = (prefix as NSString).length
        let contentLength = (content as NSString).length
        selectedRange = NSRange(location: selectedRange.location + prefixLength, length: contentLength)
    }

    private func toggleLinePrefix(_ prefix: MarkdownLineEditing.Prefix) {
        let edit = MarkdownLineEditing.togglingPrefix(prefix, in: editorText, selection: selectedRange)
        editorText = (editorText as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
        selectedRange = edit.selection
    }

    // Display math must sit on standalone $$ lines for the parser to pick it
    // up, so the insertion adds the newlines the caret position is missing and
    // leaves the formula body (selection or placeholder) selected.
    private func insertMathBlock(placeholder: String) {
        let nsText = editorText as NSString
        let location = min(selectedRange.location, nsText.length)
        let length = min(selectedRange.length, nsText.length - location)
        let range = NSRange(location: location, length: length)
        let selected = nsText.substring(with: range)
        let content = selected.isEmpty ? placeholder : selected

        let newline: unichar = 0x0A
        let needsLeadingNewline = location > 0
            && nsText.character(at: location - 1) != newline
        let trailingIndex = location + length
        let needsTrailingNewline = trailingIndex < nsText.length
            && nsText.character(at: trailingIndex) != newline

        let prefix = (needsLeadingNewline ? "\n" : "") + "$$\n"
        let suffix = "\n$$" + (needsTrailingNewline ? "\n" : "")
        editorText = nsText.replacingCharacters(in: range, with: prefix + content + suffix)
        selectedRange = NSRange(
            location: location + (prefix as NSString).length,
            length: (content as NSString).length
        )
    }
}
