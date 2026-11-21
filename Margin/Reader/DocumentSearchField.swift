import SwiftUI
import UIKit

// The query field of the document search bar. A UITextField rather than a
// SwiftUI TextField because Return has to step to the next match with the
// keyboard staying where it is: SwiftUI's field resigns on submit, and the
// reader then resizes underneath the jump it just made.
struct DocumentSearchField: UIViewRepresentable {
    @Binding var text: String
    let theme: MarkdownTheme
    let onReturn: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> FocusingTextField {
        let field = FocusingTextField()
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged(_:)),
            for: .editingChanged
        )
        field.placeholder = L10n.string("workspace.search_prompt")
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.returnKeyType = .search
        field.enablesReturnKeyAutomatically = true
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.text = text
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: FocusingTextField, context: Context) {
        context.coordinator.parent = self
        field.textColor = UIColor(theme.textPrimary)
        field.tintColor = UIColor(theme.accent)
        // Text still being composed (pinyin) is the field's to manage.
        if field.markedTextRange == nil, field.text != text {
            field.text = text
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FocusingTextField, context: Context) -> CGSize? {
        let fitting = uiView.sizeThatFits(
            CGSize(width: UIView.layoutFittingExpandedSize.width, height: UIView.layoutFittingCompressedSize.height)
        )
        return CGSize(width: proposal.width ?? fitting.width, height: fitting.height)
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DocumentSearchField

        init(_ parent: DocumentSearchField) {
            self.parent = parent
        }

        @objc func textChanged(_ field: UITextField) {
            let updated = field.text ?? ""
            if parent.text != updated {
                parent.text = updated
            }
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onReturn()
            return false
        }

        // A query left from the last search is selected, so typing replaces
        // it instead of adding to it.
        func textFieldDidBeginEditing(_ field: UITextField) {
            guard field.text?.isEmpty == false else { return }
            Task { @MainActor in
                field.selectAll(nil)
            }
        }
    }
}

// Takes the keyboard as soon as it is on screen: the bar is only ever shown
// to be typed into.
final class FocusingTextField: UITextField {
    private var hasFocusedOnce = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !hasFocusedOnce else { return }
        hasFocusedOnce = true
        Task { @MainActor in
            self.becomeFirstResponder()
        }
    }
}
