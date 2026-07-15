import SwiftUI

struct MarkdownEditorView: View {
    @Binding var text: String
    let textScale: Double
    @Binding var isFocused: Bool
    let readerTheme: ReaderTheme

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    @State private var selectedRange = NSRange(location: 0, length: 0)

    private var theme: MarkdownTheme {
        MarkdownTheme(readerTheme: readerTheme, colorScheme: colorScheme)
    }

    var body: some View {
        NativeMarkdownTextView(
            text: $text,
            selectedRange: $selectedRange,
            isFocused: $isFocused,
            theme: theme,
            readerTheme: readerTheme,
            bodySize: bodySize * textScale
        )
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
        .background(theme.canvas)
        .safeAreaBar(edge: .bottom) {
            if isFocused {
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
        case .bold: wrapSelection(prefix: "**", suffix: "**", placeholder: "重点")
        case .italic: wrapSelection(prefix: "_", suffix: "_", placeholder: "强调")
        case .link: wrapSelection(prefix: "[", suffix: "](https://)", placeholder: "链接文字")
        case .code: wrapSelection(prefix: "`", suffix: "`", placeholder: "代码")
        case .quote: prefixCurrentLine("> ")
        case .list: prefixCurrentLine("- ")
        case .task: prefixCurrentLine("- [ ] ")
        }
    }

    private func setHeadingPrefix(_ prefix: String) {
        let nsText = text as NSString
        let safeLocation = min(selectedRange.location, nsText.length)
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
        let line = nsText.substring(with: lineRange)
        let hashCount = line.prefix(while: { $0 == "#" }).count
        let hasHeadingPrefix = (1...6).contains(hashCount) && line.dropFirst(hashCount).first == " "
        let oldPrefixLength = hasHeadingPrefix ? hashCount + 1 : 0
        let replacementRange = NSRange(location: lineRange.location, length: oldPrefixLength)
        text = nsText.replacingCharacters(in: replacementRange, with: prefix)

        let offsetInLine = max(0, selectedRange.location - lineRange.location)
        let adjustedOffset = max(0, offsetInLine - oldPrefixLength) + (prefix as NSString).length
        selectedRange.location = lineRange.location + adjustedOffset
    }

    private func wrapSelection(prefix: String, suffix: String, placeholder: String) {
        guard let range = Range(selectedRange, in: text) else { return }
        let selected = String(text[range])
        let content = selected.isEmpty ? placeholder : selected
        let replacement = prefix + content + suffix
        text.replaceSubrange(range, with: replacement)
        let prefixLength = (prefix as NSString).length
        let contentLength = (content as NSString).length
        selectedRange = NSRange(location: selectedRange.location + prefixLength, length: contentLength)
    }

    private func prefixCurrentLine(_ prefix: String) {
        let nsText = text as NSString
        let safeLocation = min(selectedRange.location, nsText.length)
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
        text = nsText.replacingCharacters(in: NSRange(location: lineRange.location, length: 0), with: prefix)
        selectedRange.location += (prefix as NSString).length
    }
}
