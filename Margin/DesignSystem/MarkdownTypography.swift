import CoreText
import SwiftUI
import UIKit

enum MarkdownTypography {
    private struct InlineFontCacheKey: Hashable {
        let theme: ReaderTheme
        let size: Double
        let weight: Double
    }

    @MainActor
    private static var inlineFontCache: [InlineFontCacheKey: InlineMarkdownFonts] = [:]

    static func documentFont(
        theme: ReaderTheme,
        size: Double,
        weight: UIFont.Weight = .regular
    ) -> Font {
        Font(documentUIFont(theme: theme, size: size, weight: weight))
    }

    static func documentUIFont(
        theme: ReaderTheme,
        size: Double,
        weight: UIFont.Weight = .regular
    ) -> UIFont {
        let pointSize = CGFloat(size)
        switch theme {
        case .claude:
            return claudeFont(size: pointSize, weight: weight)
        case .github:
            return UIFont.systemFont(ofSize: pointSize, weight: weight)
        }
    }

    @MainActor
    static func inlineFonts(
        theme: ReaderTheme,
        size: Double,
        weight: UIFont.Weight = .regular
    ) -> InlineMarkdownFonts {
        let cacheKey = InlineFontCacheKey(
            theme: theme,
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
            regular: documentFont(theme: theme, size: size, weight: weight),
            emphasized: Font(inlineItalicUIFont(
                theme: theme,
                size: size,
                weight: weight
            )),
            strong: Font(inlineStrongUIFont(
                theme: theme,
                size: size,
                weight: strongWeight
            )),
            strongEmphasis: Font(inlineItalicUIFont(
                theme: theme,
                size: size,
                weight: strongWeight
            ))
        )
        inlineFontCache[cacheKey] = fonts
        return fonts
    }

    static func inlineStrongUIFont(
        theme: ReaderTheme,
        size: Double,
        weight: UIFont.Weight
    ) -> UIFont {
        let pointSize = CGFloat(size)
        let systemFont = UIFont.systemFont(ofSize: pointSize, weight: weight)
        var descriptor = systemFont.fontDescriptor
        if theme == .claude {
            descriptor = descriptor.withDesign(.serif) ?? descriptor
            descriptor = descriptor.addingAttributes([
                .cascadeList: [cjkSerifDescriptor(size: pointSize, weight: weight)]
            ])
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }

    static func inlineItalicUIFont(
        theme: ReaderTheme,
        size: Double,
        weight: UIFont.Weight
    ) -> UIFont {
        let pointSize = CGFloat(size)
        let descriptor: UIFontDescriptor
        switch theme {
        case .claude:
            descriptor = claudeDescriptor(size: pointSize, weight: weight)
        case .github:
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
