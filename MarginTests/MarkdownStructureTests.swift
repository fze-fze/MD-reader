import Testing
@testable import Margin

// Block structure the line-based parser has to get right for real-world
// documents: Windows line endings, ragged tables, nested lists, long fences.
struct MarkdownStructureTests {
    private func kinds(_ source: String) -> [MarkdownBlock.Kind] {
        MarkdownParser.parse(source).map(\.kind)
    }

    @Test func parsesWindowsLineEndingsLikeUnixOnes() {
        let unix = "line one\nline two\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n```swift\nlet a = 1\nlet b = 2\n```\n"
        let windows = unix.replacingOccurrences(of: "\n", with: "\r\n")

        #expect(MarkdownParser.parse(windows) == MarkdownParser.parse(unix))
        #expect(kinds(windows) == [
            .paragraph("line one line two"),
            .table(headers: ["a", "b"], rows: [["1", "2"]]),
            .code(language: "swift", source: "let a = 1\nlet b = 2")
        ])
        #expect(DocumentStatistics(source: "a\r\nb\r\nc").lines == 3)
    }

    @Test func keepsATableWhoseRowsAreRagged() {
        let source = "| a | b | c |\n|---|---|---|\n| 1 | 2 |\n| 1 | 2 | 3 | 4 |\nafter"

        #expect(kinds(source) == [
            .table(headers: ["a", "b", "c"], rows: [["1", "2", ""], ["1", "2", "3"]]),
            .paragraph("after")
        ])
    }

    @Test func keepsEscapedAndCodePipesInsideTheirCell() {
        let source = "| a | b |\n|---|---|\n| x \\| y | `p|q` |"

        #expect(kinds(source) == [
            .table(headers: ["a", "b"], rows: [["x | y", "`p|q`"]])
        ])
    }

    @Test func parsesSingleColumnAndColonAlignedTables() {
        #expect(kinds("| a |\n|---|\n| 1 |") == [.table(headers: ["a"], rows: [["1"]])])
        #expect(kinds("a | b\n:-: | -:\n1 | 2") == [.table(headers: ["a", "b"], rows: [["1", "2"]])])
        // A line with a pipe is not a table without its delimiter row.
        #expect(kinds("a | b\nplain") == [.paragraph("a | b plain")])
    }

    @Test func recordsListNestingAndNumbering() {
        let source = "1. one\n   - sub a\n   - sub b\n2. two\n   1. deep"
        guard case let .orderedList(items) = kinds(source).first else {
            Issue.record("expected an ordered list")
            return
        }

        #expect(items.map(\.id) == [0, 1, 2, 3, 4])
        #expect(items.map(\.level) == [0, 1, 1, 0, 1])
        #expect(items.map(\.ordinal) == [1, nil, nil, 2, 1])
    }

    @Test func numbersOrderedListsFromTheirFirstItem() {
        guard case let .orderedList(items) = kinds("5. five\n5. six\n\n5. seven").first else {
            Issue.record("expected an ordered list")
            return
        }

        #expect(items.map(\.ordinal) == [5, 6, 7])
        #expect(items.map(\.id) == [0, 1, 3])
    }

    @Test func joinsIndentedContinuationLinesIntoTheirListItem() {
        let blocks = MarkdownParser.parse("- item one\n  continued\n- item two\nparagraph")

        #expect(blocks.map(\.kind) == [
            .unorderedList([
                MarkdownListItem(id: 0, text: "item one continued", isChecked: nil),
                MarkdownListItem(id: 2, text: "item two", isChecked: nil)
            ]),
            .paragraph("paragraph")
        ])
        #expect(blocks.map(\.sourceLines) == [0..<3, 3..<4])
    }

    @Test func separatesListsOfDifferentKindsAcrossABlankLine() {
        let blocks = MarkdownParser.parse("- a\n\n- b\n\n1. c\n\ntext")

        #expect(blocks.map(\.id) == [0, 4, 6])
        #expect(blocks.map(\.sourceLines) == [0..<3, 4..<5, 6..<7])
    }

    @Test func acceptsParenthesisAndTabListMarkers() {
        #expect(kinds("1) one\n2) two") == [
            .orderedList([
                MarkdownListItem(id: 0, text: "one", isChecked: nil, ordinal: 1),
                MarkdownListItem(id: 1, text: "two", isChecked: nil, ordinal: 2)
            ])
        ])
        #expect(kinds("-\titem") == [.unorderedList([MarkdownListItem(id: 0, text: "item", isChecked: nil)])])
        // Prose that merely starts with a number or a dash stays prose.
        #expect(kinds("3.14 is pi") == [.paragraph("3.14 is pi")])
        #expect(kinds("-not a list") == [.paragraph("-not a list")])
    }

    @Test func treatsALeadingDividerAsADividerNotFrontMatter() {
        #expect(kinds("---\n# Title\ntext\n\n---\n\nmore") == [
            .divider,
            .heading(level: 1, text: "Title"),
            .paragraph("text"),
            .divider,
            .paragraph("more")
        ])
        #expect(kinds("---\ntitle: x\ntags:\n  - a\n---\n# H") == [
            .frontMatter("title: x\ntags:\n  - a"),
            .heading(level: 1, text: "H")
        ])
    }

    @Test func closesAFenceOnlyWithAMatchingFence() {
        #expect(kinds("````md\n```swift\ncode\n```\n````\nafter") == [
            .code(language: "md", source: "```swift\ncode\n```"),
            .paragraph("after")
        ])
        #expect(kinds("~~~\n```\ninner\n~~~") == [.code(language: nil, source: "```\ninner")])
        // Indentation inside a fence is content.
        #expect(kinds("```\n  indented\n```") == [.code(language: nil, source: "  indented")])
    }

    @Test func stripsClosingHashesFromHeadings() {
        #expect(kinds("## Title ##") == [.heading(level: 2, text: "Title")])
        #expect(kinds("# C#") == [.heading(level: 1, text: "C#")])
        #expect(kinds("#NoSpace") == [.paragraph("#NoSpace")])
    }

    @Test func recognizesDividersOfAnyLength() {
        #expect(kinds("-----\n* * * *\n___") == [.divider, .divider, .divider])
        #expect(kinds("--") == [.paragraph("--")])
    }

    @Test func keepsHardLineBreaksInParagraphs() {
        #expect(kinds("line one  \nline two\nline three") == [
            .paragraph("line one\nline two line three")
        ])
    }

    @Test func hidesStandaloneHTMLComments() {
        #expect(kinds("<!-- hidden -->\ntext") == [.paragraph("text")])
        #expect(kinds("<!--\nhidden\n-->\ntext") == [.paragraph("text")])
        // An unterminated comment must not swallow the document.
        #expect(kinds("<!-- open\ntext") == [.paragraph("<!-- open text")])
    }

    @Test @MainActor func printsNestedListsAsNestedMarkup() {
        let html = MarkdownPrintRenderer.html(
            source: "3. one\n   - sub\n4. two\n\n- [x] done\n  - note",
            title: "Lists",
            theme: .claude
        )

        #expect(html.contains("<ol start=\"3\"><li>one<ul><li>sub</li></ul></li><li>two</li></ol>"))
        #expect(html.contains("<ul class=\"task-list\">"))
        #expect(html.contains("<ul><li>note</li></ul></li></ul>"))
    }
}
