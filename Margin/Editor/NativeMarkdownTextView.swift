import SwiftUI
import UIKit

struct NativeMarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var isFocused: Bool
    let findTrigger: Int
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
        view.isFindInteractionEnabled = true
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
        if !hasMarkedText, view.text != text {
            replaceChangedRange(in: view, with: text)
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
        if !hasMarkedText, typographyChanged {
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

        if findTrigger != context.coordinator.lastFindTrigger {
            context.coordinator.lastFindTrigger = findTrigger
            if !view.isFirstResponder {
                view.becomeFirstResponder()
            }
            view.findInteraction?.presentFindNavigator(showingReplace: false)
        }
    }

    private var documentFont: UIFont {
        MarkdownTypography.documentUIFont(theme: readerTheme, size: bodySize)
    }

    // Assigning `UITextView.text` moves the caret to the end of the document
    // and schedules an auto-scroll to it on the next layout pass, so a whole-
    // text assignment jumps the viewport no matter what is restored afterwards.
    // Replacing only the changed region in the text storage leaves the caret
    // and scroll position alone.
    private func replaceChangedRange(in view: UITextView, with newText: String) {
        let change = Self.changedRange(from: view.text, to: newText)
        view.textStorage.replaceCharacters(in: change.range, with: change.replacement)
        applyTypography(
            to: view,
            range: NSRange(
                location: change.range.location,
                length: (change.replacement as NSString).length
            )
        )
    }

    nonisolated static func changedRange(
        from oldText: String,
        to newText: String
    ) -> (range: NSRange, replacement: String) {
        let oldValue = oldText as NSString
        let newValue = newText as NSString
        let minLength = min(oldValue.length, newValue.length)

        var prefixLength = 0
        while prefixLength < minLength,
              oldValue.character(at: prefixLength) == newValue.character(at: prefixLength) {
            prefixLength += 1
        }

        var suffixLength = 0
        while suffixLength < minLength - prefixLength,
              oldValue.character(at: oldValue.length - 1 - suffixLength)
                == newValue.character(at: newValue.length - 1 - suffixLength) {
            suffixLength += 1
        }

        let range = NSRange(
            location: prefixLength,
            length: oldValue.length - prefixLength - suffixLength
        )
        let replacement = newValue.substring(
            with: NSRange(
                location: prefixLength,
                length: newValue.length - prefixLength - suffixLength
            )
        )
        return (range, replacement)
    }

    private func applyTypography(to view: UITextView) {
        applyTypography(
            to: view,
            range: NSRange(location: 0, length: view.textStorage.length)
        )
    }

    private func applyTypography(to view: UITextView, range: NSRange) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.36

        let attributes: [NSAttributedString.Key: Any] = [
            .font: documentFont,
            .foregroundColor: UIColor(theme.textPrimary),
            .paragraphStyle: paragraphStyle
        ]
        view.typingAttributes = attributes

        guard range.length > 0 else { return }
        view.textStorage.addAttributes(attributes, range: range)
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NativeMarkdownTextView
        var lastFindTrigger = 0
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
