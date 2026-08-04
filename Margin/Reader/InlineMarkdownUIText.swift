import SwiftUI
import UIKit

// Builds the NSAttributedString the UITextView-backed reader draws.
//
// The UIKit twin of `InlineMarkdownText` + `InlineMarkdownStyler`: same
// segmentation (annotations, then inline math, then inline Markdown), same
// search highlighting, same baseline treatment for formulas. It exists
// separately because SwiftUI's `Font` and `Color` have no NSAttributedString
// representation — writing them into one silently falls back to the system
// face. Keep the two in step: the character sequences must stay identical, or
// search offsets and `InlinePlainText.map` drift apart from what is drawn.
@MainActor
enum InlineMarkdownUIText {
    struct AnnotationRun: Equatable {
        let annotation: MarginAnnotation
        let range: NSRange
    }

    struct Rendered {
        let text: NSAttributedString
        let annotations: [AnnotationRun]
    }

    // The base styled string, before search highlighting — a pure function of
    // the source, the fonts and the theme's colors, and the dominant cost on
    // the render path. Cached exactly like `InlineMarkdownStyler`.
    private struct CacheKey: Hashable {
        let source: String
        let fonts: InlineMarkdownUIFonts
        let readerTheme: ReaderTheme
        let colorScheme: ColorScheme
        let foregroundColor: UIColor
        let mathFontSize: Double
    }

    private static var cache: [CacheKey: NSAttributedString] = [:]

    static func purgeCache() {
        cache.removeAll()
    }

    static func rendered(
        source: String,
        fonts: InlineMarkdownUIFonts,
        mathFontSize: Double,
        foregroundColor: UIColor,
        theme: MarkdownTheme,
        searchText: String = "",
        activeOccurrenceIndex: Int? = nil,
        occurrenceOffset: Int = 0,
        lineSpacing: Double = 0,
        paragraphAlignment: NSTextAlignment = .natural
    ) -> Rendered {
        let result = NSMutableAttributedString()
        var annotations: [AnnotationRun] = []
        var accumulatedMatches = 0

        for segment in AnnotationSegmenter.segments(in: source) {
            let segmentStart = result.length

            for mathSegment in InlineMathSegmenter.segments(in: segment.text) {
                switch mathSegment {
                case let .text(part):
                    let styled = styledText(
                        part,
                        fonts: fonts,
                        foregroundColor: foregroundColor,
                        theme: theme,
                        mathFontSize: mathFontSize
                    )
                    let highlighted = NSMutableAttributedString(attributedString: styled)
                    accumulatedMatches += highlight(
                        highlighted,
                        query: searchText,
                        activeOccurrenceIndex: activeOccurrenceIndex,
                        occurrenceOffset: occurrenceOffset + accumulatedMatches,
                        theme: theme
                    )
                    result.append(highlighted)

                case let .math(latex, isDisplay):
                    result.append(
                        formula(
                            latex: latex,
                            isDisplay: isDisplay,
                            fonts: fonts,
                            mathFontSize: mathFontSize,
                            foregroundColor: foregroundColor,
                            theme: theme
                        )
                    )
                }
            }

            if let annotation = segment.annotation, result.length > segmentStart {
                annotations.append(
                    AnnotationRun(
                        annotation: annotation,
                        range: NSRange(location: segmentStart, length: result.length - segmentStart)
                    )
                )
            }
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.alignment = paragraphAlignment
        result.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: result.length)
        )

        return Rendered(text: result, annotations: annotations)
    }

    // MARK: - Inline Markdown

    private static func styledText(
        _ source: String,
        fonts: InlineMarkdownUIFonts,
        foregroundColor: UIColor,
        theme: MarkdownTheme,
        mathFontSize: Double
    ) -> NSAttributedString {
        let key = CacheKey(
            source: source,
            fonts: fonts,
            readerTheme: theme.readerTheme,
            colorScheme: theme.colorScheme,
            foregroundColor: foregroundColor,
            mathFontSize: mathFontSize
        )
        if let cached = cache[key] {
            return cached
        }

        let styled = buildStyledText(
            source,
            fonts: fonts,
            foregroundColor: foregroundColor,
            theme: theme
        )
        if cache.count > 500 {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = styled
        return styled
    }

    private static func buildStyledText(
        _ source: String,
        fonts: InlineMarkdownUIFonts,
        foregroundColor: UIColor,
        theme: MarkdownTheme
    ) -> NSAttributedString {
        let parsed = (try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(source)

        let result = NSMutableAttributedString(string: String(parsed.characters))
        let whole = NSRange(location: 0, length: result.length)
        result.addAttribute(.font, value: fonts.regular, range: whole)
        result.addAttribute(.foregroundColor, value: foregroundColor, range: whole)

        for run in parsed.runs {
            let range = NSRange(run.range, in: parsed)
            guard range.location != NSNotFound, range.length > 0 else { continue }

            let intent = run.inlinePresentationIntent
            if intent?.contains(.stronglyEmphasized) == true,
               intent?.contains(.emphasized) == true {
                result.addAttribute(.font, value: fonts.strongEmphasis, range: range)
            } else if intent?.contains(.stronglyEmphasized) == true {
                result.addAttribute(.font, value: fonts.strong, range: range)
            } else if intent?.contains(.emphasized) == true {
                result.addAttribute(.font, value: fonts.emphasized, range: range)
            }

            if intent?.contains(.code) == true {
                result.addAttribute(.foregroundColor, value: UIColor(theme.inlineCodeText), range: range)
                result.addAttribute(.backgroundColor, value: UIColor(theme.inlineCodeFill), range: range)
            }

            if let link = run.link {
                result.addAttribute(.link, value: link, range: range)
            }
        }
        return result
    }

    // MARK: - Inline math

    private static func formula(
        latex: String,
        isDisplay: Bool,
        fonts: InlineMarkdownUIFonts,
        mathFontSize: Double,
        foregroundColor: UIColor,
        theme: MarkdownTheme
    ) -> NSAttributedString {
        guard let formula = MathRenderer.formula(
            latex: latex,
            fontSize: mathFontSize,
            textColor: foregroundColor,
            display: isDisplay,
            readerTheme: theme.readerTheme
        ) else {
            // Invalid LaTeX keeps its delimiters so the document still reads.
            let raw = isDisplay ? "$$\(latex)$$" : "$\(latex)$"
            return NSAttributedString(
                string: raw,
                attributes: [.font: fonts.regular, .foregroundColor: foregroundColor]
            )
        }

        let attachment = NSTextAttachment()
        attachment.image = formula.image
        // Dropping the image by its descent seats the formula on the
        // surrounding text's baseline — the UIKit equivalent of the SwiftUI
        // path's `Text(Image(…)).baselineOffset(-descent)`.
        attachment.bounds = CGRect(
            x: 0,
            y: -formula.descent,
            width: formula.image.size.width,
            height: formula.image.size.height
        )
        return NSAttributedString(attachment: attachment)
    }

    // MARK: - Search highlighting

    // Returns how many occurrences it found, so the caller can keep the
    // running occurrence offset aligned across segments.
    @discardableResult
    private static func highlight(
        _ text: NSMutableAttributedString,
        query: String,
        activeOccurrenceIndex: Int?,
        occurrenceOffset: Int,
        theme: MarkdownTheme
    ) -> Int {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return 0
        }

        let matches = DocumentSearchMatcher.ranges(in: text.string, query: query)
        for (localIndex, match) in matches.enumerated() {
            let range = NSRange(match, in: text.string)
            guard range.location != NSNotFound else { continue }

            let isActive = occurrenceOffset + localIndex == activeOccurrenceIndex
            text.addAttribute(
                .backgroundColor,
                value: UIColor(isActive ? theme.accent.opacity(0.42) : theme.selection.opacity(0.72)),
                range: range
            )
        }
        return matches.count
    }
}
