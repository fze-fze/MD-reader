import SwiftUI
import UIKit

struct InlineMarkdownText: View {
    let source: String
    let fonts: InlineMarkdownFonts
    // Numeric size backing `fonts`; inline math renders at this size so
    // formulas match the surrounding text.
    let mathFontSize: Double
    let foregroundStyle: Color
    let theme: MarkdownTheme
    var searchText = ""
    var activeOccurrenceIndex: Int?
    var occurrenceOffset = 0

    var body: some View {
        content
            .font(fonts.regular)
            .foregroundStyle(foregroundStyle)
            .tint(theme.accent)
    }

    private var content: Text {
        let segments = InlineMathSegmenter.segments(in: source)
        let hasMath = segments.contains { segment in
            if case .math = segment { return true }
            return false
        }
        guard hasMath else {
            return Text(styledText(source, occurrenceOffset: occurrenceOffset))
        }

        // Each text segment is highlighted independently; occurrence offsets
        // accumulate across segments so the active-match index keeps lining up
        // with the searchable fragment (math spans count as U+FFFC there).
        var accumulatedMatches = 0
        var result = Text(verbatim: "")
        for segment in segments {
            switch segment {
            case let .text(part):
                let styled = InlineMarkdownStyler.attributedString(
                    source: part,
                    fonts: fonts,
                    theme: theme
                )
                let highlighted = SearchHighlighting.apply(
                    to: styled,
                    query: searchText,
                    activeOccurrenceIndex: activeOccurrenceIndex,
                    occurrenceOffset: occurrenceOffset + accumulatedMatches,
                    theme: theme
                )
                accumulatedMatches += DocumentSearchMatcher.ranges(
                    in: String(styled.characters),
                    query: searchText
                ).count
                result = result + Text(highlighted)
            case let .math(latex, isDisplay):
                if let formula = MathRenderer.formula(
                    latex: latex,
                    fontSize: mathFontSize,
                    textColor: UIColor(foregroundStyle),
                    display: isDisplay,
                    readerTheme: theme.readerTheme
                ) {
                    result = result + Text(Image(uiImage: formula.image))
                        .baselineOffset(-formula.descent)
                } else {
                    let raw = isDisplay ? "$$\(latex)$$" : "$\(latex)$"
                    result = result + Text(verbatim: raw)
                }
            }
        }
        return result
    }

    private func styledText(_ part: String, occurrenceOffset: Int) -> AttributedString {
        let styled = InlineMarkdownStyler.attributedString(
            source: part,
            fonts: fonts,
            theme: theme
        )
        return SearchHighlighting.apply(
            to: styled,
            query: searchText,
            activeOccurrenceIndex: activeOccurrenceIndex,
            occurrenceOffset: occurrenceOffset,
            theme: theme
        )
    }
}
