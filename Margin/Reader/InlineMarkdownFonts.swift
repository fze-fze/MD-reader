import SwiftUI
import UIKit

struct InlineMarkdownFonts: Hashable {
    let regular: Font
    let emphasized: Font
    let strong: Font
    let strongEmphasis: Font
}

// The same four faces as `InlineMarkdownFonts`, as UIFonts. Text the reader
// draws through a UITextView needs real UIFonts: SwiftUI's `Font` has no
// representation in an NSAttributedString, so it would silently fall back to
// the system face.
struct InlineMarkdownUIFonts: Hashable {
    let regular: UIFont
    let emphasized: UIFont
    let strong: UIFont
    let strongEmphasis: UIFont
}
