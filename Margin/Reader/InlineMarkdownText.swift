import SwiftUI

struct InlineMarkdownText: View {
    let source: String
    let font: Font
    let foregroundStyle: Color
    let theme: MarkdownTheme
    var searchText = ""
    var activeOccurrenceIndex: Int?
    var occurrenceOffset = 0

    var body: some View {
        Text(attributedText)
            .font(font)
            .foregroundStyle(foregroundStyle)
            .tint(theme.accent)
    }

    private var attributedText: AttributedString {
        var attributed = (try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(source)

        for run in attributed.runs {
            guard run.inlinePresentationIntent?.contains(.code) == true else { continue }
            attributed[run.range].foregroundColor = theme.inlineCodeText
            attributed[run.range].backgroundColor = theme.inlineCodeFill
        }
        return SearchHighlighting.apply(
            to: attributed,
            query: searchText,
            activeOccurrenceIndex: activeOccurrenceIndex,
            occurrenceOffset: occurrenceOffset,
            theme: theme
        )
    }
}
