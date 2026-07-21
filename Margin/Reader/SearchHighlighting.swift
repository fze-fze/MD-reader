import SwiftUI

enum SearchHighlighting {
    static func apply(
        to attributedText: AttributedString,
        query: String,
        activeOccurrenceIndex: Int?,
        occurrenceOffset: Int,
        theme: MarkdownTheme
    ) -> AttributedString {
        // The reader passes an empty query to every non-matching block on each
        // render; skip the character-string allocation and matcher on that path.
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return attributedText
        }

        var attributedText = attributedText
        let visibleText = String(attributedText.characters)
        let matches = DocumentSearchMatcher.ranges(in: visibleText, query: query)

        for (localIndex, match) in matches.enumerated() {
            guard let lowerBound = AttributedString.Index(match.lowerBound, within: attributedText),
                  let upperBound = AttributedString.Index(match.upperBound, within: attributedText) else {
                continue
            }

            let isActive = occurrenceOffset + localIndex == activeOccurrenceIndex
            attributedText[lowerBound..<upperBound].backgroundColor = isActive
                ? theme.accent.opacity(0.42)
                : theme.selection.opacity(0.72)
        }

        return attributedText
    }
}
