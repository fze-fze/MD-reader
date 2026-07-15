import SwiftUI
import UIKit

struct NativeMarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var isFocused: Bool
    let theme: MarkdownTheme
    let readerTheme: ReaderTheme
    let bodySize: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = UIColor(theme.canvas)
        view.textColor = UIColor(theme.textPrimary)
        view.tintColor = UIColor(theme.accent)
        view.font = documentFont
        view.adjustsFontForContentSizeCategory = true
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        view.textContainerInset = UIEdgeInsets(top: 24, left: 16, bottom: 36, right: 16)
        view.textContainer.lineFragmentPadding = 4
        view.smartDashesType = .no
        view.smartQuotesType = .no
        view.smartInsertDeleteType = .no
        view.accessibilityLabel = L10n.string("editor.accessibility_label")
        view.text = text
        applyTypography(to: view)
        context.coordinator.recordTypography(
            readerTheme: readerTheme,
            bodySize: bodySize,
            textColor: UIColor(theme.textPrimary)
        )
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        let hasMarkedText = view.markedTextRange != nil
        var replacedText = false
        if !hasMarkedText, view.text != text {
            view.text = text
            replacedText = true
        }
        if !hasMarkedText,
           view.selectedRange != selectedRange,
           selectedRange.location <= (view.text as NSString).length {
            view.selectedRange = selectedRange
        }
        view.backgroundColor = UIColor(theme.canvas)
        view.textColor = UIColor(theme.textPrimary)
        view.tintColor = UIColor(theme.accent)
        let typographyChanged = context.coordinator.typographyChanged(
            readerTheme: readerTheme,
            bodySize: bodySize,
            textColor: UIColor(theme.textPrimary)
        )
        if !hasMarkedText, replacedText || typographyChanged {
            view.font = documentFont
            applyTypography(to: view)
            context.coordinator.recordTypography(
                readerTheme: readerTheme,
                bodySize: bodySize,
                textColor: UIColor(theme.textPrimary)
            )
        }

        if isFocused != view.isFirstResponder {
            Task { @MainActor in
                if isFocused {
                    view.becomeFirstResponder()
                } else {
                    view.resignFirstResponder()
                }
            }
        }
    }

    private var documentFont: UIFont {
        MarkdownTypography.documentUIFont(theme: readerTheme, size: bodySize)
    }

    private func applyTypography(to view: UITextView) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.36

        let attributes: [NSAttributedString.Key: Any] = [
            .font: documentFont,
            .foregroundColor: UIColor(theme.textPrimary),
            .paragraphStyle: paragraphStyle
        ]
        view.typingAttributes = attributes

        guard view.textStorage.length > 0 else { return }
        view.textStorage.addAttributes(
            attributes,
            range: NSRange(location: 0, length: view.textStorage.length)
        )
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NativeMarkdownTextView
        private var lastReaderTheme: ReaderTheme?
        private var lastBodySize: Double?
        private var lastTextColor: UIColor?

        init(parent: NativeMarkdownTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            synchronizeCommittedText(from: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            if parent.text != textView.text {
                parent.text = textView.text
            }
            parent.selectedRange = textView.selectedRange
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            synchronizeCommittedText(from: textView)
            parent.isFocused = false
        }

        func typographyChanged(
            readerTheme: ReaderTheme,
            bodySize: Double,
            textColor: UIColor
        ) -> Bool {
            lastReaderTheme != readerTheme
                || lastBodySize != bodySize
                || lastTextColor?.isEqual(textColor) != true
        }

        func recordTypography(
            readerTheme: ReaderTheme,
            bodySize: Double,
            textColor: UIColor
        ) {
            lastReaderTheme = readerTheme
            lastBodySize = bodySize
            lastTextColor = textColor
        }

        private func synchronizeCommittedText(from textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            parent.text = textView.text
            parent.selectedRange = textView.selectedRange
        }
    }
}
