import SwiftUI
import UIKit

struct NativeMarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var isFocused: Bool
    let findTrigger: Int
    let liveFormatting: Bool
    let theme: MarkdownTheme
    let readerTheme: ReaderTheme
    let bodySize: Double
    var embedded = false
    var regionID: UUID? = nil
    var isComposing: Binding<Bool>? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var textInsets: UIEdgeInsets {
        if embedded { return UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0) }
        let padding = MarkdownTypography.columnPadding(compact: horizontalSizeClass == .compact)
        return UIEdgeInsets(top: padding.top, left: padding.leading, bottom: 36, right: padding.trailing)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        // TextKit 1 on purpose. TextKit 2 estimates the height of text it has
        // not laid out, and after a jump into the middle of a long document
        // it draws one passage while resolving taps against another — the
        // caret lands sections away from where the user touched.
        let view = UITextView(usingTextLayoutManager: false)
        view.delegate = context.coordinator
        view.backgroundColor = UIColor(theme.canvas)
        view.textColor = UIColor(theme.textPrimary)
        view.tintColor = UIColor(theme.accent)
        view.font = documentFont
        view.adjustsFontForContentSizeCategory = true
        view.isScrollEnabled = !embedded
        view.alwaysBounceVertical = !embedded
        view.keyboardDismissMode = .interactive
        view.textContainerInset = textInsets
        view.textContainer.lineFragmentPadding = 0
        view.smartDashesType = .no
        view.smartQuotesType = .no
        view.smartInsertDeleteType = .no
        view.isFindInteractionEnabled = !embedded
        view.accessibilityLabel = L10n.string("editor.accessibility_label")
        view.text = text
        if selectedRange.location > 0, NSMaxRange(selectedRange) <= view.textStorage.length {
            view.selectedRange = selectedRange
            if !embedded { scrollToSelection(in: view) }
        }
        context.coordinator.styler.attach(to: view, style: editorStyle)
        return view
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard embedded, let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitting.height))
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.textContainerInset != textInsets {
            view.textContainerInset = textInsets
        }
        context.coordinator.synchronizeBackingText(in: view)
        if context.coordinator.lastTheme != theme {
            context.coordinator.lastTheme = theme
            view.backgroundColor = UIColor(theme.canvas)
            view.tintColor = UIColor(theme.accent)
        }
        context.coordinator.styler.updateStyle(editorStyle)

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

    // Puts the line holding the caret at the top of the editor once the view
    // has a size, so an editor opened part-way through a document shows the
    // passage the reader was showing. Everything above the caret is laid out
    // first, so the offset is measured rather than estimated.
    private func scrollToSelection(in view: UITextView) {
        Task { @MainActor in
            await Task.yield()
            view.layoutIfNeeded()
            view.layoutManager.ensureLayout(
                forCharacterRange: NSRange(location: 0, length: view.selectedRange.location)
            )
            guard let caretPosition = view.selectedTextRange?.start else { return }
            let caret = view.caretRect(for: caretPosition)
            guard !caret.isNull, !caret.isInfinite else { return }
            let top = -view.adjustedContentInset.top
            let bottom = max(
                top,
                view.contentSize.height - view.bounds.height + view.adjustedContentInset.bottom
            )
            let target = caret.minY - view.textContainerInset.top - view.adjustedContentInset.top
            view.setContentOffset(
                CGPoint(x: view.contentOffset.x, y: min(max(target, top), bottom)),
                animated: false
            )
        }
    }

    private var documentFont: UIFont {
        MarkdownTypography.documentUIFont(theme: readerTheme, size: bodySize)
    }

    private var editorStyle: LiveMarkdownStyler.Style {
        .init(enabled: liveFormatting, theme: theme, bodySize: bodySize)
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

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NativeMarkdownTextView
        let styler = LiveMarkdownStyler()
        var lastFindTrigger = 0
        var lastTheme: MarkdownTheme?
        private var regionID: UUID?
        private var isSynchronizing = false
        // The text last exchanged with the binding, in either direction.
        private var syncedText: String
        // Set when an edit could not be reported yet because an input method
        // was still composing.
        private var hasUnreportedEdit = false

        init(parent: NativeMarkdownTextView) {
            self.parent = parent
            syncedText = parent.text
            lastTheme = parent.theme
            regionID = parent.regionID
        }

        func synchronizeBackingText(in view: UITextView) {
            guard view.markedTextRange == nil else { return }
            isSynchronizing = true
            defer { isSynchronizing = false }
            let text = parent.text
            if regionID != parent.regionID {
                regionID = parent.regionID
                view.undoManager?.removeAllActions()
                // Canonically equivalent strings can have different UTF-16 offsets.
                if !text.utf16.elementsEqual(syncedText.utf16) {
                    view.textStorage.replaceCharacters(
                        in: NSRange(location: 0, length: view.textStorage.length),
                        with: text
                    )
                }
                syncedText = text
            } else if text != syncedText {
                // Keep in-place updates incremental to avoid jumping the viewport.
                let change = NativeMarkdownTextView.changedRange(from: view.text ?? "", to: text)
                view.textStorage.replaceCharacters(in: change.range, with: change.replacement)
                syncedText = text
            }
            let selection = parent.selectedRange
            if view.selectedRange != selection, NSMaxRange(selection) <= view.textStorage.length {
                view.selectedRange = selection
                styler.scheduleRefresh()
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isSynchronizing else { return }
            hasUnreportedEdit = true
            synchronizeCommittedText(from: textView)
        }

        // Return inside a list item or quote continues it on the next line.
        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard text == "\n",
                  textView.markedTextRange == nil,
                  let edit = MarkdownLineEditing.continuingList(in: textView.text ?? "", selection: range),
                  let start = textView.position(from: textView.beginningOfDocument, offset: edit.range.location),
                  let end = textView.position(from: start, offset: edit.range.length),
                  let textRange = textView.textRange(from: start, to: end) else {
                return true
            }
            // Through UITextInput so the edit lands on the undo stack.
            textView.replace(textRange, withText: edit.replacement)
            textView.selectedRange = edit.selection
            hasUnreportedEdit = true
            synchronizeCommittedText(from: textView)
            return false
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isSynchronizing else { return }
            let composing = textView.markedTextRange != nil
            updateComposition(composing)
            guard !composing else { return }
            styler.scheduleRefresh()
            if hasUnreportedEdit {
                reportText(from: textView)
            }
            if parent.selectedRange != textView.selectedRange {
                parent.selectedRange = textView.selectedRange
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            synchronizeCommittedText(from: textView)
            parent.isFocused = false
        }

        private func synchronizeCommittedText(from textView: UITextView) {
            let composing = textView.markedTextRange != nil
            updateComposition(composing)
            guard !composing else { return }
            styler.scheduleRefresh()
            reportText(from: textView)
            parent.selectedRange = textView.selectedRange
        }

        private func updateComposition(_ composing: Bool) {
            if let binding = parent.isComposing, binding.wrappedValue != composing {
                binding.wrappedValue = composing
            }
        }

        private func reportText(from textView: UITextView) {
            let current = textView.text ?? ""
            hasUnreportedEdit = false
            syncedText = current
            parent.text = current
        }
    }
}
