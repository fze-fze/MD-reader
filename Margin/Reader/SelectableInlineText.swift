import SwiftUI
import UIKit

// The reader's body text, drawn by a UITextView so it can be selected.
//
// SwiftUI's `Text` can render this content but cannot report *what* the user
// selected and cannot contribute items to the selection menu, so annotating a
// span is impossible on that path. A non-scrolling, non-editable UITextView
// gives us `selectedRange`, a customizable edit menu, and the text segment
// rectangles the hand-drawn marks are drawn over.
//
// Only the block kinds that can be annotated use this; tables and image
// captions stay on `InlineMarkdownText`.
struct SelectableInlineText: UIViewRepresentable {
    let source: String
    let fonts: InlineMarkdownUIFonts
    // Numeric size backing `fonts`; inline math renders at this size so
    // formulas match the surrounding text.
    let mathFontSize: Double
    let foregroundColor: UIColor
    let theme: MarkdownTheme
    var searchText = ""
    var activeOccurrenceIndex: Int?
    var occurrenceOffset = 0
    var lineSpacing: Double = 0
    // Whether spans in this text can be annotated. Paragraphs, headings,
    // quotes and list items opt in; table cells are selectable/copyable but
    // out of the v1 annotation scope, so they opt out. The annotate menu item
    // (Phase C) keys off this.
    var allowsAnnotation = true
    // Table cells size to their content rather than filling a proposed width.
    // A Grid measures its children by proposing an unspecified width first, so
    // the cell has to report its natural width or the column collapses.
    var sizingMode: SizingMode = .fillWidth

    enum SizingMode {
        case fillWidth
        case intrinsic
    }

    func makeUIView(context: Context) -> ReaderTextView {
        let textView = ReaderTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.dataDetectorTypes = []
        textView.adjustsFontForContentSizeCategory = false
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        return textView
    }

    func updateUIView(_ uiView: ReaderTextView, context: Context) {
        uiView.tintColor = UIColor(theme.accent)

        let rendered = InlineMarkdownUIText.rendered(
            source: source,
            fonts: fonts,
            mathFontSize: mathFontSize,
            foregroundColor: foregroundColor,
            theme: theme,
            searchText: searchText,
            activeOccurrenceIndex: activeOccurrenceIndex,
            occurrenceOffset: occurrenceOffset,
            lineSpacing: lineSpacing
        )
        // Reassigning the text drops any live selection, so skip the write when
        // nothing actually changed — updateUIView runs on every scroll pass.
        if uiView.attributedText != rendered.text {
            uiView.attributedText = rendered.text
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: ReaderTextView,
        context: Context
    ) -> CGSize? {
        // Intrinsic (table cells) or an unspecified width proposal: size to the
        // content in both dimensions.
        guard sizingMode == .fillWidth,
              let width = proposal.width,
              width > 0,
              width < .greatestFiniteMagnitude else {
            let fitted = uiView.sizeThatFits(
                CGSize(
                    width: CGFloat.greatestFiniteMagnitude,
                    height: CGFloat.greatestFiniteMagnitude
                )
            )
            return CGSize(width: ceil(fitted.width), height: ceil(fitted.height))
        }
        let fitted = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: ceil(fitted.height))
    }
}

// A UITextView that behaves like a paragraph of a document rather than a text
// field: no scrolling of its own, and no keyboard-related affordances.
final class ReaderTextView: UITextView {
    // A selectable UITextView installs its own pan gesture for text dragging,
    // which competes with the reader's ScrollView. Letting the scroll view win
    // keeps flicking through a document from turning into a text drag.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIPanGestureRecognizer, selectedRange.length == 0 {
            return false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}
