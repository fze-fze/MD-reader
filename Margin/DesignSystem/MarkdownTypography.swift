import CoreText
import SwiftUI
import UIKit

enum MarkdownTypography {
    static func columnPadding(compact: Bool) -> EdgeInsets {
        let horizontal: CGFloat = compact ? 20 : 32
        return EdgeInsets(top: compact ? 24 : 32, leading: horizontal, bottom: 0, trailing: horizontal)
    }

    private struct InlineFontCacheKey: Hashable {
        let typeface: DocumentTypeface
        let size: Double
        let weight: Double
    }

    @MainActor
    private static var inlineFontCache: [InlineFontCacheKey: InlineMarkdownFonts] = [:]

    @MainActor
    private static var inlineUIFontCache: [InlineFontCacheKey: InlineMarkdownUIFonts] = [:]

    static func documentFont(
        typeface: DocumentTypeface,
        size: Double,
        weight: UIFont.Weight = .regular
    ) -> Font {
        Font(documentUIFont(typeface: typeface, size: size, weight: weight))
    }

    static func documentUIFont(
        typeface: DocumentTypeface,
        size: Double,
        weight: UIFont.Weight = .regular
    ) -> UIFont {
        let pointSize = CGFloat(size)
        switch typeface {
        case .anthropicSerif:
            return claudeFont(size: pointSize, weight: weight)
        case .anthropicSans:
            return UIFont(descriptor: anthropicSansDescriptor(size: pointSize, weight: weight), size: pointSize)
        case .systemSerif:
            return UIFont(descriptor: systemSerifDescriptor(size: pointSize, weight: weight), size: pointSize)
        case .systemSans:
            return UIFont.systemFont(ofSize: pointSize, weight: weight)
        }
    }

    @MainActor
    static func inlineFonts(
        typeface: DocumentTypeface,
        size: Double,
        weight: UIFont.Weight = .regular
    ) -> InlineMarkdownFonts {
        let cacheKey = InlineFontCacheKey(
            typeface: typeface,
            size: size,
            weight: weight.rawValue
        )
        if let cachedFonts = inlineFontCache[cacheKey] {
            return cachedFonts
        }

        let strongWeight = weight.rawValue >= UIFont.Weight.bold.rawValue
            ? weight
            : .bold
        let fonts = InlineMarkdownFonts(
            regular: documentFont(typeface: typeface, size: size, weight: weight),
            emphasized: Font(inlineItalicUIFont(
                typeface: typeface,
                size: size,
                weight: weight
            )),
            strong: Font(inlineStrongUIFont(
                typeface: typeface,
                size: size,
                weight: strongWeight
            )),
            strongEmphasis: Font(inlineItalicUIFont(
                typeface: typeface,
                size: size,
                weight: strongWeight
            ))
        )
        inlineFontCache[cacheKey] = fonts
        return fonts
    }

    // UIFont twin of `inlineFonts`, for the UITextView-backed reader path.
    // Same cascade and the same synthesized oblique — only the wrapper differs.
    @MainActor
    static func inlineUIFonts(
        typeface: DocumentTypeface,
        size: Double,
        weight: UIFont.Weight = .regular
    ) -> InlineMarkdownUIFonts {
        let cacheKey = InlineFontCacheKey(
            typeface: typeface,
            size: size,
            weight: weight.rawValue
        )
        if let cachedFonts = inlineUIFontCache[cacheKey] {
            return cachedFonts
        }

        let strongWeight = weight.rawValue >= UIFont.Weight.bold.rawValue
            ? weight
            : .bold
        let fonts = InlineMarkdownUIFonts(
            regular: documentUIFont(typeface: typeface, size: size, weight: weight),
            emphasized: inlineItalicUIFont(typeface: typeface, size: size, weight: weight),
            strong: inlineStrongUIFont(typeface: typeface, size: size, weight: strongWeight),
            strongEmphasis: inlineItalicUIFont(typeface: typeface, size: size, weight: strongWeight)
        )
        inlineUIFontCache[cacheKey] = fonts
        return fonts
    }

    @MainActor
    static func purgeFontCaches() {
        inlineFontCache.removeAll()
        inlineUIFontCache.removeAll()
    }

    static func inlineStrongUIFont(
        typeface: DocumentTypeface,
        size: Double,
        weight: UIFont.Weight
    ) -> UIFont {
        let pointSize = CGFloat(size)
        switch typeface {
        case .anthropicSerif, .systemSerif:
            // The bundled Anthropic Serif is a single regular weight, so its
            // bold comes from New York.
            return UIFont(descriptor: systemSerifDescriptor(size: pointSize, weight: weight), size: pointSize)
        case .anthropicSans:
            return UIFont(descriptor: anthropicSansDescriptor(size: pointSize, weight: weight), size: pointSize)
        case .systemSans:
            return UIFont.systemFont(ofSize: pointSize, weight: weight)
        }
    }

    static func inlineItalicUIFont(
        typeface: DocumentTypeface,
        size: Double,
        weight: UIFont.Weight
    ) -> UIFont {
        let pointSize = CGFloat(size)
        let descriptor: UIFontDescriptor
        switch typeface {
        case .anthropicSerif:
            descriptor = claudeDescriptor(size: pointSize, weight: weight)
        case .anthropicSans:
            descriptor = anthropicSansDescriptor(size: pointSize, weight: weight)
        case .systemSerif:
            descriptor = systemSerifDescriptor(size: pointSize, weight: weight)
        case .systemSans:
            descriptor = UIFont.systemFont(ofSize: pointSize, weight: weight)
                .fontDescriptor
                .addingAttributes([
                    .cascadeList: [cjkSerifDescriptor(size: pointSize, weight: weight)]
                ])
        }
        // `.traitItalic` is useless here: neither the bundled Anthropic serif nor
        // any CJK face ships an italic variant, so the trait resolves back to the
        // upright font and emphasis renders identically to body text. Synthesize
        // the slant with a shear matrix instead — the whole cascade inherits it,
        // which is what makes CJK emphasis actually lean (the same oblique a
        // browser synthesizes for `font-style: italic`).
        return obliqueFont(descriptor: descriptor, size: pointSize)
    }

    /// Slant applied to synthesized obliques, as tan(θ) for θ ≈ 12°.
    private static let obliqueSlant: CGFloat = 0.21

    private static func obliqueFont(
        descriptor: UIFontDescriptor,
        size: CGFloat
    ) -> UIFont {
        var shear = CGAffineTransform(a: 1, b: 0, c: obliqueSlant, d: 1, tx: 0, ty: 0)
        let font = CTFontCreateWithFontDescriptor(descriptor as CTFontDescriptor, size, &shear)
        return unsafeBitCast(font, to: UIFont.self)
    }

    private static func claudeFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFont(descriptor: claudeDescriptor(size: size, weight: weight), size: size)
    }

    private static func claudeDescriptor(
        size: CGFloat,
        weight: UIFont.Weight
    ) -> UIFontDescriptor {
        let fallback = UIFont.systemFont(ofSize: size, weight: weight)
        let baseDescriptor = UIFont(
            name: "AnthropicSerifWebVariable-TextRegular",
            size: size
        )?.fontDescriptor ?? fallback.fontDescriptor.withDesign(.serif) ?? fallback.fontDescriptor

        return baseDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight.rawValue],
            .cascadeList: [cjkSerifDescriptor(size: size, weight: weight)]
        ])
    }

    private static func systemSerifDescriptor(
        size: CGFloat,
        weight: UIFont.Weight
    ) -> UIFontDescriptor {
        let system = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        return (system.withDesign(.serif) ?? system).addingAttributes([
            .cascadeList: [cjkSerifDescriptor(size: size, weight: weight)]
        ])
    }

    static let anthropicSansPostScriptName = "AnthropicSansWebWeb-TextRegular"

    // Anthropic Sans is one variable file: weight and optical size are axes,
    // not separate faces, so they are set as variations. CJK has to be named
    // in the cascade too — left to the default fallback it comes out regular
    // weight under a semibold heading.
    private static func anthropicSansDescriptor(
        size: CGFloat,
        weight: UIFont.Weight
    ) -> UIFontDescriptor {
        let system = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        guard let base = UIFont(name: anthropicSansPostScriptName, size: size)?.fontDescriptor else {
            return system
        }
        let variation = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        return base.addingAttributes([
            variation: [
                fourCharCode("wght"): anthropicSansWeight(for: weight),
                fourCharCode("opsz"): Double(min(max(size, 16), 48))
            ],
            .cascadeList: [system]
        ])
    }

    // UIFont.Weight is -1...1; the font's axis runs 300 (light) to 800.
    static func anthropicSansWeight(for weight: UIFont.Weight) -> Double {
        let stops: [(UIFont.Weight, Double)] = [
            (.light, 300), (.regular, 400), (.medium, 500),
            (.semibold, 600), (.bold, 700), (.heavy, 800)
        ]
        let nearest = stops.min { abs($0.0.rawValue - weight.rawValue) < abs($1.0.rawValue - weight.rawValue) }
        return nearest?.1 ?? 400
    }

    private static func fourCharCode(_ tag: String) -> Int {
        tag.utf8.reduce(0) { ($0 << 8) | Int($1) }
    }

    private static func cjkSerifDescriptor(
        size: CGFloat,
        weight: UIFont.Weight
    ) -> UIFontDescriptor {
        let bundledFontName = notoSerifPostScriptName(weight: weight)
        if UIFont(name: bundledFontName, size: size) != nil {
            return UIFontDescriptor(name: bundledFontName, size: size)
        }
        return UIFontDescriptor(name: songtiPostScriptName(weight: weight), size: size)
    }

    private static func notoSerifPostScriptName(weight: UIFont.Weight) -> String {
        if weight.rawValue >= UIFont.Weight.semibold.rawValue {
            "NotoSerifSC-SemiBold"
        } else if weight.rawValue <= UIFont.Weight.light.rawValue {
            "NotoSerifSC-Light"
        } else {
            "NotoSerifSC-Regular"
        }
    }

    private static func songtiPostScriptName(weight: UIFont.Weight) -> String {
        if weight.rawValue >= UIFont.Weight.semibold.rawValue {
            "STSongti-SC-Bold"
        } else if weight.rawValue <= UIFont.Weight.light.rawValue {
            "STSongti-SC-Light"
        } else {
            "STSongti-SC-Regular"
        }
    }
}
