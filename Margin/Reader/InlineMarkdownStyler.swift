import SwiftUI

enum InlineMarkdownStyler {
    static func attributedString(
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
