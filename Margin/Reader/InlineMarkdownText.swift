import SwiftUI

struct InlineMarkdownText: View {
    let source: String
    let fonts: InlineMarkdownFonts
    let foregroundStyle: Color
    let theme: MarkdownTheme
    var searchText = ""
    var activeOccurrenceIndex: Int?
    var occurrenceOffset = 0

    var body: some View {
        Text(attributedText)
            .font(fonts.regular)
            .foregroundStyle(foregroundStyle)
            .tint(theme.accent)
    }

    private var attributedText: AttributedString {
        let attributed = InlineMarkdownStyler.attributedString(
            source: source,
            fonts: fonts,
            theme: theme
        )
        return SearchHighlighting.apply(
            to: attributed,
            query: searchText,
            activeOccurrenceIndex: activeOccurrenceIndex,
            occurrenceOffset: occurrenceOffset,
            theme: theme
        )
    }
}
