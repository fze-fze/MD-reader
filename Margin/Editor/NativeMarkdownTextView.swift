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
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text {
            view.text = text
        }
        if view.selectedRange != selectedRange, selectedRange.location <= (view.text as NSString).length {
            view.selectedRange = selectedRange
        }
        view.backgroundColor = UIColor(theme.canvas)
        view.textColor = UIColor(theme.textPrimary)
        view.tintColor = UIColor(theme.accent)
        view.font = documentFont
        applyTypography(to: view)

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

        init(parent: NativeMarkdownTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.selectedRange = textView.selectedRange
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }
    }
}
