import Foundation

// Where the user is in the document, shared between the reader and the editor
// so switching modes keeps their place. A plain reference type on purpose:
// both sides write to it while scrolling or moving the caret, and none of
// those writes should invalidate a view.
@MainActor
final class ReadingPosition {
    // Blocks currently on screen in the reader, by block ID (source line).
    var visibleBlockIDs: [Int] = []
    // UTF-16 offset of the editor's caret.
    var editorCaretLocation = 0
    // A source line the reader should bring on screen once it has blocks for
    // the current text.
    var pendingLine: Int?

    var topVisibleLine: Int? {
        visibleBlockIDs.min()
    }
}
