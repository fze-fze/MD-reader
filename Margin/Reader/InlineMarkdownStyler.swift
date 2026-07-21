import SwiftUI

enum InlineMarkdownStyler {
    // The base styled string (fonts + code-span colors, before any search
    // highlighting) is a pure function of source, fonts, and the theme's code
    // colors. Scrolling a long document re-evaluates each visible block's body,
    // and `AttributedString(markdown:)` parsing dominates that cost — so cache
    // the result keyed by everything that affects it.
    private struct CacheKey: Hashable {
        let source: String
        let fonts: InlineMarkdownFonts
        let readerTheme: ReaderTheme
        let colorScheme: ColorScheme
    }

    @MainActor
    private static var cache: [CacheKey: AttributedString] = [:]

    @MainActor
    static func attributedString(
        source: String,
        fonts: InlineMarkdownFonts,
        theme: MarkdownTheme
    ) -> AttributedString {
        let key = CacheKey(
            source: source,
            fonts: fonts,
            readerTheme: theme.readerTheme,
            colorScheme: theme.colorScheme
        )
        if let cached = cache[key] {
            return cached
        }

        let styled = buildAttributedString(source: source, fonts: fonts, theme: theme)
        if cache.count > 500 {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = styled
        return styled
    }

    private static func buildAttributedString(
        source: String,
        fonts: InlineMarkdownFonts,
        theme: MarkdownTheme
    ) -> AttributedString {
        var attributed = (try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(source)

        for run in attributed.runs {
            let intent = run.inlinePresentationIntent
            if intent?.contains(.stronglyEmphasized) == true,
               intent?.contains(.emphasized) == true {
                attributed[run.range].font = fonts.strongEmphasis
            } else if intent?.contains(.stronglyEmphasized) == true {
                attributed[run.range].font = fonts.strong
            } else if intent?.contains(.emphasized) == true {
                attributed[run.range].font = fonts.emphasized
            }

            if intent?.contains(.code) == true {
                attributed[run.range].foregroundColor = theme.inlineCodeText
                attributed[run.range].backgroundColor = theme.inlineCodeFill
            }
        }
        return attributed
    }
}
