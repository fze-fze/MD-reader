import SwiftUI

// The inputs that change how a diagram looks. Kept free of UIKit so it can be
// compared and used as a cache key; the renderer turns it into a mermaid
// configuration, resolving the theme tokens to colors as it goes.
struct MermaidStyle: Equatable {
    let readerTheme: ReaderTheme
    let colorScheme: ColorScheme
    let fontSize: Double

    init(theme: MarkdownTheme, fontSize: Double) {
        readerTheme = theme.readerTheme
        colorScheme = theme.colorScheme
        // Text scaling moves in small steps; rounding keeps the render cache
        // from filling up with visually identical entries.
        self.fontSize = (fontSize * 4).rounded() / 4
    }

    var identity: String {
        "\(readerTheme.rawValue)|\(colorScheme == .dark ? "dark" : "light")|\(fontSize)"
    }
}
