import SwiftUI

struct SearchablePlainText: View {
    let source: String
    let font: Font
    let foregroundStyle: Color
    let theme: MarkdownTheme
    let searchText: String
    let activeOccurrenceIndex: Int?
    let occurrenceOffset: Int

    var body: some View {
        Text(attributedText)
            .font(font)
            .foregroundStyle(foregroundStyle)
    }

    private var attributedText: AttributedString {
        SearchHighlighting.apply(
            to: AttributedString(source),
            query: searchText,
            activeOccurrenceIndex: activeOccurrenceIndex,
            occurrenceOffset: occurrenceOffset,
            theme: theme
        )
    }
}
