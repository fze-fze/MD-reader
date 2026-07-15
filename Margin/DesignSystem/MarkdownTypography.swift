import SwiftUI
import UIKit

enum MarkdownTypography {
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

    private static func claudeFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let fallback = UIFont.systemFont(ofSize: size, weight: weight)
        let baseDescriptor = UIFont(
            name: "AnthropicSerifWebVariable-TextRegular",
            size: size
        )?.fontDescriptor ?? fallback.fontDescriptor.withDesign(.serif) ?? fallback.fontDescriptor

        let descriptor = baseDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight.rawValue],
            .cascadeList: [cjkSerifDescriptor(size: size, weight: weight)]
        ])
        return UIFont(descriptor: descriptor, size: size)
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
