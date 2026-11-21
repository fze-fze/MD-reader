import CoreText
import Testing
import UIKit
@testable import Margin

struct ReaderFontChoiceTests {
    private func fontName(for text: String, in font: UIFont) -> String {
        let resolved = CTFontCreateForString(
            font as CTFont,
            text as CFString,
            CFRange(location: 0, length: (text as NSString).length)
        )
        return CTFontCopyPostScriptName(resolved) as String
    }

    private func weightAxis(of font: UIFont) -> Double? {
        let variation = CTFontCopyVariation(font as CTFont) as? [NSNumber: NSNumber]
        return variation?[NSNumber(value: 0x7767_6874)]?.doubleValue
    }

    @Test func eachThemeKeepsItsOwnFaceUntilTheUserPicksOne() {
        #expect(ReaderFontChoice.themeDefault.typeface(for: .claude) == .anthropicSerif)
        #expect(ReaderFontChoice.themeDefault.typeface(for: .github) == .systemSans)
        #expect(ReaderFontChoice.sans.typeface(for: .claude) == .anthropicSans)
        #expect(ReaderFontChoice.serif.typeface(for: .claude) == .anthropicSerif)
        #expect(ReaderFontChoice.serif.typeface(for: .github) == .systemSerif)
        #expect(ReaderFontChoice.sans.typeface(for: .github) == .systemSans)

        let theme = MarkdownTheme(
            readerTheme: .claude,
            colorScheme: .light,
            bodyFont: .sans,
            headingFont: .themeDefault
        )
        #expect(theme.bodyTypeface == .anthropicSans)
        #expect(theme.headingTypeface == .anthropicSerif)
    }

    @Test func anthropicSansIsBundledAndUsedForLatin() {
        let font = MarkdownTypography.documentUIFont(typeface: .anthropicSans, size: 16)
        #expect(fontName(for: "Margin", in: font).hasPrefix("AnthropicSans"))
        #expect(!fontName(for: "Margin", in: MarkdownTypography.documentUIFont(typeface: .anthropicSerif, size: 16))
            .hasPrefix("AnthropicSans"))
    }

    @Test func anthropicSansWeightsComeFromTheVariableAxis() {
        #expect(MarkdownTypography.anthropicSansWeight(for: .regular) == 400)
        #expect(MarkdownTypography.anthropicSansWeight(for: .semibold) == 600)
        #expect(MarkdownTypography.anthropicSansWeight(for: .bold) == 700)
        #expect(MarkdownTypography.anthropicSansWeight(for: .black) == 800)

        let regular = MarkdownTypography.documentUIFont(typeface: .anthropicSans, size: 16)
        let heading = MarkdownTypography.documentUIFont(typeface: .anthropicSans, size: 28, weight: .semibold)
        let strong = MarkdownTypography.inlineStrongUIFont(typeface: .anthropicSans, size: 16, weight: .bold)
        #expect(weightAxis(of: heading) == 600)
        #expect(weightAxis(of: strong) == 700)
        // The same glyphs set wider in a heavier weight: proof the axis took.
        let sample = "Markdown reader" as NSString
        let regularWidth = sample.size(withAttributes: [.font: regular]).width
        let strongWidth = sample.size(withAttributes: [.font: strong]).width
        #expect(strongWidth > regularWidth)
    }

    @Test func sansFacesFallBackToSansChinese() {
        for typeface in [DocumentTypeface.anthropicSans, .systemSans] {
            let font = MarkdownTypography.documentUIFont(typeface: typeface, size: 16)
            let name = fontName(for: "阅读", in: font)
            #expect(!name.contains("Serif") && !name.contains("Songti"), "\(typeface): \(name)")
        }
        for typeface in [DocumentTypeface.anthropicSerif, .systemSerif] {
            let font = MarkdownTypography.documentUIFont(typeface: typeface, size: 16)
            let name = fontName(for: "阅读", in: font)
            #expect(name.contains("Serif") || name.contains("Songti"), "\(typeface): \(name)")
        }
    }

    @Test func sansHeadingsKeepTheirWeightInChinese() {
        let regular = MarkdownTypography.documentUIFont(typeface: .anthropicSans, size: 24)
        let heading = MarkdownTypography.documentUIFont(typeface: .anthropicSans, size: 24, weight: .semibold)
        let regularCJK = CTFontCreateForString(regular as CTFont, "阅读" as CFString, CFRange(location: 0, length: 2))
        let headingCJK = CTFontCreateForString(heading as CTFont, "阅读" as CFString, CFRange(location: 0, length: 2))
        let regularTraits = CTFontCopyTraits(regularCJK) as? [String: Any]
        let headingTraits = CTFontCopyTraits(headingCJK) as? [String: Any]
        let regularWeight = (regularTraits?[kCTFontWeightTrait as String] as? NSNumber)?.doubleValue ?? 0
        let headingWeight = (headingTraits?[kCTFontWeightTrait as String] as? NSNumber)?.doubleValue ?? 0
        #expect(headingWeight > regularWeight)
    }

    @Test func exportFollowsTheChoiceWithSystemFonts() {
        let source = "# Title\n\nBody"
        let defaults = MarkdownPrintRenderer.html(source: source, title: "t", theme: .claude)
        #expect(defaults.contains("body { color: #2b2621; font-family: ui-serif"))

        let mixed = MarkdownPrintRenderer.html(
            source: source,
            title: "t",
            theme: .claude,
            bodyFont: .sans,
            headingFont: .serif
        )
        #expect(mixed.contains("body { color: #2b2621; font-family: -apple-system"))
        #expect(mixed.contains("h1, h2, h3, h4, h5, h6 { color: #1c1815; font-family: ui-serif"))
        #expect(!mixed.contains("Anthropic"))

        let github = MarkdownPrintRenderer.html(source: source, title: "t", theme: .github, headingFont: .serif)
        #expect(github.contains("font-family: -apple-system"))
        #expect(github.contains("h1, h2, h3, h4, h5, h6 { color: #24292f; font-family: ui-serif"))
    }
}
