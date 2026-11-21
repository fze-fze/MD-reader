import Foundation
import Testing
@testable import Margin

struct MarkdownLineEditingTests {
    // Applies an edit the way the text view does and marks the caret with "|".
    private func applying(_ edit: MarkdownLineEditing.Edit?, to text: String) -> String? {
        guard let edit else { return nil }
        let result = NSMutableString(string: (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement))
        result.insert("|", at: edit.selection.location)
        return result as String
    }

    private func pressingReturn(in marked: String) -> String? {
        let location = (marked as NSString).range(of: "|").location
        let text = marked.replacingOccurrences(of: "|", with: "")
        return applying(
            MarkdownLineEditing.continuingList(in: text, selection: NSRange(location: location, length: 0)),
            to: text
        )
    }

    private func toggling(_ prefix: MarkdownLineEditing.Prefix, in marked: String) -> String? {
        let location = (marked as NSString).range(of: "|").location
        let text = marked.replacingOccurrences(of: "|", with: "")
        return applying(
            MarkdownLineEditing.togglingPrefix(prefix, in: text, selection: NSRange(location: location, length: 0)),
            to: text
        )
    }

    @Test func returnContinuesBulletsTasksNumbersAndQuotes() {
        #expect(pressingReturn(in: "- one|") == "- one\n- |")
        #expect(pressingReturn(in: "  * one|\nnext") == "  * one\n  * |\nnext")
        #expect(pressingReturn(in: "- [x] done|") == "- [x] done\n- [ ] |")
        #expect(pressingReturn(in: "9. nine|") == "9. nine\n10. |")
        #expect(pressingReturn(in: "1) one|") == "1) one\n2) |")
        #expect(pressingReturn(in: "> quoted|") == "> quoted\n> |")
        // Splitting an item carries the rest of the line into the new one.
        #expect(pressingReturn(in: "- one| two") == "- one\n- | two")
    }

    @Test func returnOnAnEmptyItemEndsTheList() {
        #expect(pressingReturn(in: "- one\n- |") == "- one\n|")
        #expect(pressingReturn(in: "- [ ] |\nnext") == "|\nnext")
        #expect(pressingReturn(in: "3. |") == "|")
    }

    @Test func returnElsewhereIsLeftToTheTextView() {
        #expect(pressingReturn(in: "plain text|") == nil)
        #expect(pressingReturn(in: "-not a list|") == nil)
        #expect(pressingReturn(in: "3.14 is pi|") == nil)
        // A caret inside the marker is not inside the item yet.
        #expect(pressingReturn(in: "|- one") == nil)
    }

    @Test func returnKeepsTheDocumentsLineEndings() {
        #expect(pressingReturn(in: "- one|\r\n- two") == "- one\r\n- |\r\n- two")
    }

    @Test func togglingAPrefixAddsRemovesAndConverts() {
        #expect(toggling(.list, in: "it|em") == "- it|em")
        #expect(toggling(.list, in: "- it|em") == "it|em")
        #expect(toggling(.task, in: "- it|em") == "- [ ] it|em")
        #expect(toggling(.task, in: "- [x] it|em") == "it|em")
        #expect(toggling(.list, in: "- [ ] it|em") == "- it|em")
        #expect(toggling(.quote, in: "it|em") == "> it|em")
        #expect(toggling(.quote, in: "> it|em") == "it|em")
        #expect(toggling(.quote, in: "- it|em") == "> - it|em")
    }

    @Test func togglingAPrefixKeepsIndentationAndOtherLines() {
        #expect(toggling(.task, in: "first\n  - it|em\nlast") == "first\n  - [ ] it|em\nlast")
        #expect(toggling(.list, in: "|") == "- |")
        #expect(toggling(.list, in: "|- item") == "|item")
    }

    @Test func convertsBetweenLinesAndTextViewOffsets() {
        let source = "a\r\n你好\n\nlast"

        #expect(SourceLines.utf16Offset(ofLine: 0, in: source) == 0)
        #expect(SourceLines.utf16Offset(ofLine: 1, in: source) == 3)
        #expect(SourceLines.utf16Offset(ofLine: 3, in: source) == 7)
        #expect(SourceLines.utf16Offset(ofLine: 99, in: source) == (source as NSString).length)

        #expect(SourceLines.lineIndex(atUTF16Offset: 0, in: source) == 0)
        #expect(SourceLines.lineIndex(atUTF16Offset: 4, in: source) == 1)
        #expect(SourceLines.lineIndex(atUTF16Offset: 7, in: source) == 3)
        #expect(SourceLines.lineIndex(atUTF16Offset: 999, in: source) == 3)
    }
}
