import Foundation
import Testing
@testable import Margin

struct LiveMarkdownDocumentTests {
    @Test func editableRegionsKeepUnicodeAndOriginalLineTerminators() {
        let source = "# 字🙂\r\n\r\n| A | B |\r\n| - | - |\r\n| 1 | 2 |\r\n\r\n$$\r\nx^2\r\n$$\r\n![alt](file.png)\r\n"
        let document = LiveMarkdownDocument(source: source)
        let text = source as NSString
        let rows = document.rows
        #expect(rows.map { text.substring(with: $0.range) } == [
            "# 字🙂", "", "| A | B |\r\n| - | - |\r\n| 1 | 2 |",
            "", "$$\r\nx^2\r\n$$", "![alt](file.png)", ""
        ])
        #expect(rows.compactMap(\.block) == MarkdownParser.parse(source))
        #expect(document.row(at: text.range(of: "1 | 2").location).id == 2)
        #expect(document.row(at: text.length).range == NSRange(location: text.length, length: 0))
        let edited = text.replacingCharacters(in: rows[2].range, with: "| updated | table |")
        #expect(edited == "# 字🙂\r\n\r\n| updated | table |\r\n\r\n$$\r\nx^2\r\n$$\r\n![alt](file.png)\r\n")
    }

    @Test func blankAndHiddenSourceRemainsEditable() {
        let empty = LiveMarkdownDocument(source: "").row(at: 0)
        #expect(empty.range == NSRange(location: 0, length: 0))
        #expect(empty.block == nil)
        let source = "<!-- hidden -->\n\n# Title"
        let comment = LiveMarkdownDocument(source: source).row(at: 3)
        #expect(comment.block == nil)
        #expect((source as NSString).substring(with: comment.range) == "<!-- hidden -->\n")
    }
}
