import SwiftMath
import UIKit

@MainActor
enum MathRenderer {
    struct RenderedFormula {
        let image: UIImage
        // Points the formula extends below the text baseline; inline images
        // are shifted down by this amount so fractions and subscripts sit on
        // the surrounding line's baseline.
        let descent: CGFloat
    }

    private static var cache: [String: RenderedFormula] = [:]
    private static var failedKeys: Set<String> = []

    static func formula(
        latex: String,
        fontSize: CGFloat,
        textColor: UIColor,
        display: Bool,
        readerTheme: ReaderTheme
    ) -> RenderedFormula? {
        let key = cacheKey(
            latex: latex,
            fontSize: fontSize,
            textColor: textColor,
            display: display,
            readerTheme: readerTheme
        )
        if let cached = cache[key] { return cached }
        if failedKeys.contains(key) { return nil }

        guard let rendered = render(
            latex: latex,
            fontSize: fontSize,
            textColor: textColor,
            display: display,
            readerTheme: readerTheme
        ) else {
            failedKeys.insert(key)
            return nil
        }

        if cache.count > 400 { cache.removeAll() }
        cache[key] = rendered
        return rendered
    }

    // SwiftMath covers most of AMS math but misses a handful of very common
    // commands; one unknown command fails the whole formula, so map them to
    // supported equivalents before parsing. The negative lookahead keeps
    // longer command names (e.g. \verta) untouched.
    nonisolated private static let commandAliases: [(unsupported: String, replacement: String)] = [
        ("lVert", "\\Vert"),
        ("rVert", "\\Vert"),
        ("lvert", "\\vert"),
        ("rvert", "\\vert"),
        ("dfrac", "\\frac"),
        ("tfrac", "\\frac"),
        ("operatorname", "\\mathrm"),
        ("implies", "\\Rightarrow"),
        ("impliedby", "\\Leftarrow"),
        ("coloneqq", ":=")
    ]

    nonisolated static func normalizedLatex(_ latex: String) -> String {
        guard latex.contains("\\") else { return latex }
        var normalized = latex
        for alias in commandAliases where normalized.contains("\\\(alias.unsupported)") {
            guard let expression = try? NSRegularExpression(
                pattern: "\\\\\(alias.unsupported)(?![a-zA-Z])"
            ) else { continue }
            normalized = expression.stringByReplacingMatches(
                in: normalized,
                range: NSRange(normalized.startIndex..., in: normalized),
                withTemplate: NSRegularExpression.escapedTemplate(for: alias.replacement)
            )
        }
        return normalized
    }

    static func purgeCache() {
        cache.removeAll()
        failedKeys.removeAll()
    }

    private static func render(
        latex: String,
        fontSize: CGFloat,
        textColor: UIColor,
        display: Bool,
        readerTheme: ReaderTheme
    ) -> RenderedFormula? {
        var mathImage = MathImage(
            latex: normalizedLatex(latex),
            fontSize: fontSize,
            textColor: textColor,
            labelMode: display ? .display : .text,
            textAlignment: .left
        )
        mathImage.font = mathFont(for: readerTheme)
        let (error, image, layout) = mathImage.asImage()
        guard error == nil, let image else { return nil }
        return RenderedFormula(image: image, descent: layout?.descent ?? 0)
    }

    private static func mathFont(for readerTheme: ReaderTheme) -> MathFont {
        switch readerTheme {
        case .claude:
            // TeX Gyre Termes matches the Claude theme's Times-flavored serif.
            .termesFont
        case .github:
            .latinModernFont
        }
    }

    private static func cacheKey(
        latex: String,
        fontSize: CGFloat,
        textColor: UIColor,
        display: Bool,
        readerTheme: ReaderTheme
    ) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        textColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return "\(readerTheme.rawValue)|\(display)|\(fontSize)|\(red),\(green),\(blue),\(alpha)|\(latex)"
    }
}
