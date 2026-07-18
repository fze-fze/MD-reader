import SwiftUI

struct MarkdownTheme {
    let readerTheme: ReaderTheme
    let colorScheme: ColorScheme

    var canvas: Color { color(claude: (0xFAF9F5, 0x1B1B19), github: (0xFFFFFF, 0x0D1117)) }
    var windowSurface: Color { color(claude: (0xF6F3ED, 0x22211F), github: (0xFAFAFA, 0x161B22)) }
    var sidebarSurface: Color { color(claude: (0xF5F2EC, 0x1F1F1D), github: (0xFAFAFA, 0x161B22)) }
    var textPrimary: Color { color(claude: (0x2B2621, 0xD8D2C5), github: (0x333333, 0xC9D1D9)) }
    var textStrong: Color { color(claude: (0x1C1815, 0xF2EEE7), github: (0x24292F, 0xF0F6FC)) }
    var textSecondary: Color { color(claude: (0x72695E, 0x9F998F), github: (0x777777, 0x8B949E)) }
    var accent: Color { color(claude: (0xBC6A3A, 0xD97855), github: (0x4183C4, 0x58A6FF)) }
    var selection: Color { color(claude: (0xE8DDD0, 0xD37854), github: (0xDDEEFF, 0x1F6FEB)).opacity(colorScheme == .dark ? 0.36 : 1) }
    var separator: Color { color(claude: (0xDDD5CA, 0x34322E), github: (0xEEEEEE, 0x30363D)) }
    var quoteFill: Color { color(claude: (0xF3EDE5, 0x22211F), github: (0xFFFFFF, 0x0D1117)) }
    var quoteRule: Color { color(claude: (0xD8CBBB, 0x51463D), github: (0xDFE2E5, 0x3B434B)) }
    var quoteText: Color { color(claude: (0x625950, 0xCFC6B8), github: (0x777777, 0x8B949E)) }
    var codeFill: Color { color(claude: (0xFCFCFA, 0x24231F), github: (0xF8F8F8, 0x161B22)) }
    var codeText: Color { color(claude: (0x1C1815, 0xE9E1D5), github: (0x333333, 0xC9D1D9)) }
    var codeBorder: Color { color(claude: (0xE9E2D8, 0x393733), github: (0xE7EAED, 0x30363D)) }
    var inlineCodeFill: Color { color(claude: (0xF2EEEA, 0x292622), github: (0xF3F4F4, 0x161B22)) }
    var inlineCodeText: Color { color(claude: (0xB14A40, 0xF0A17F), github: (0x333333, 0xC9D1D9)) }
    var tableStrongRule: Color { color(claude: (0xCBB9A6, 0x48443E), github: (0xDFE2E5, 0x30363D)) }
    var tableRowRule: Color { color(claude: (0x72695E, 0xD8D2C5), github: (0xDFE2E5, 0x30363D)).opacity(colorScheme == .dark ? 0.52 : 0.4) }
    var frontMatterFill: Color { color(claude: (0xF6F1EA, 0x22211F), github: (0xF7F7F7, 0x161B22)) }
    var navigationControl: Color { color(claude: (0x262422, 0xFFFFFF), github: (0x24292F, 0xF0F6FC)) }
    var navigationSurface: Color {
        color(claude: (0xF7F4EE, 0x292724), github: (0xFFFFFF, 0x0D1117))
            .opacity(colorScheme == .dark ? 0.58 : 0.64)
    }
    var navigationGlassTint: Color {
        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18)
    }

    var codeFont: Font.Design { .monospaced }
    var contentMaxWidth: CGFloat { readerTheme == .claude ? 780 : 860 }

    func headingScale(level: Int) -> Double {
        switch readerTheme {
        case .claude:
            [1: 1.84, 2: 1.48, 3: 1.24, 4: 1.12, 5: 1, 6: 1][level] ?? 1
        case .github:
            [1: 2.25, 2: 1.75, 3: 1.5, 4: 1.25, 5: 1, 6: 1][level] ?? 1
        }
    }

    private func color(
        claude: (light: UInt, dark: UInt),
        github: (light: UInt, dark: UInt)
    ) -> Color {
        let pair = readerTheme == .claude ? claude : github
        return Color(hex: colorScheme == .dark ? pair.dark : pair.light)
    }
}

extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
