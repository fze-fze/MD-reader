import SwiftUI

// The reader setting for body and heading type: the theme's own face, or
// serif / sans regardless of theme.
enum ReaderFontChoice: String, CaseIterable, Hashable, Identifiable, Sendable {
    case themeDefault
    case serif
    case sans

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .themeDefault: "font.theme_default"
        case .serif: "font.serif"
        case .sans: "font.sans"
        }
    }

    func isSerif(in theme: ReaderTheme) -> Bool {
        switch self {
        case .themeDefault: theme == .claude
        case .serif: true
        case .sans: false
        }
    }

    // Each theme has one serif and one sans: Claude pairs the bundled
    // Anthropic faces, GitHub stays on the system's.
    func typeface(for theme: ReaderTheme) -> DocumentTypeface {
        switch (theme, isSerif(in: theme)) {
        case (.claude, true): .anthropicSerif
        case (.claude, false): .anthropicSans
        case (.github, true): .systemSerif
        case (.github, false): .systemSans
        }
    }
}

// A concrete font stack `MarkdownTypography` knows how to build.
enum DocumentTypeface: Hashable, Sendable {
    // Bundled Anthropic Serif, CJK in bundled Noto Serif SC.
    case anthropicSerif
    // Bundled Anthropic Sans (variable), CJK in PingFang.
    case anthropicSans
    // New York, CJK in bundled Noto Serif SC.
    case systemSerif
    // San Francisco, CJK in PingFang.
    case systemSans
}
