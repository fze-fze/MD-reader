import Testing
import UIKit
@testable import Margin

struct MarkdownParserTests {
    @Test func parsesCoreBlockTypes() {
        let source = """
        ---
        title: Test
        ---
        # Heading

        Paragraph with **bold** text.

        > A quote

        - [x] Finished
        - [ ] Next

        | Name | Value |
        | --- | --- |
        | One | 1 |

        ![A sample](images/sample.png)

        ```swift
        let value = 1
        ```
        """

        let blocks = MarkdownParser.parse(source)

        #expect(blocks.contains { if case .frontMatter = $0.kind { true } else { false } })
        #expect(blocks.contains { if case .heading(level: 1, text: "Heading") = $0.kind { true } else { false } })
        #expect(blocks.contains { if case .taskList = $0.kind { true } else { false } })
        #expect(blocks.contains { if case .table = $0.kind { true } else { false } })
        #expect(blocks.contains { if case .image(alt: "A sample", source: "images/sample.png") = $0.kind { true } else { false } })
        #expect(blocks.contains { if case .code(language: "swift", source: _) = $0.kind { true } else { false } })
    }

    @Test func buildsStableOutlineIdentifiers() {
        let source = "# First\n\nText\n\n## Second"
        let headings = MarkdownParser.headings(in: source)

        #expect(headings.map(\.text) == ["First", "Second"])
        #expect(headings.map(\.level) == [1, 2])
        #expect(headings.map(\.id) == [0, 4])
    }

    @Test func countsMixedLanguageDocuments() {
        let statistics = DocumentStatistics(source: "Hello world，你好。")

        #expect(statistics.words == 4)
        #expect(statistics.lines == 1)
        #expect(statistics.readingMinutes == 1)
    }

    @Test func searchReturnsEveryOccurrenceAndItsPositionWithinTheBlock() {
        let blocks = MarkdownParser.parse("# Alpha\n\nAlpha beta alpha\n\n- beta\n- gamma beta")
        let index = DocumentSearchIndex(blocks: blocks)

        #expect(index.matches(for: "alpha") == [
            .init(blockID: 0, occurrenceIndex: 0),
            .init(blockID: 2, occurrenceIndex: 0),
            .init(blockID: 2, occurrenceIndex: 1),
        ])
        #expect(index.matches(for: " beta ") == [
            .init(blockID: 2, occurrenceIndex: 0),
            .init(blockID: 4, occurrenceIndex: 0),
            .init(blockID: 4, occurrenceIndex: 1),
        ])
        #expect(index.matches(for: "   ").isEmpty)
    }

    @Test func searchIgnoresMarkdownFormattingCharacters() {
        let blocks = MarkdownParser.parse("A **bold** value and another bold value.")
        let index = DocumentSearchIndex(blocks: blocks)

        #expect(index.matches(for: "bold").count == 2)
        #expect(index.matches(for: "**").isEmpty)
    }

    @Test func claudeThemeUsesAnthropicSerifWithBundledCJKSerifFallback() {
        let font = MarkdownTypography.documentUIFont(theme: .claude, size: 16)
        let cascade = font.fontDescriptor.object(forKey: .cascadeList)
            as? [UIFontDescriptor]

        #expect(font.fontName.contains("AnthropicSerif"))
        #expect(UIFont(name: "NotoSerifSC-Regular", size: 16) != nil)
        #expect(cascade?.contains { $0.postscriptName == "NotoSerifSC-Regular" } == true)
    }

    @Test func includesClaudeAndGitHubThemes() {
        #expect(ReaderTheme.allCases == [.claude, .github])
    }

    @Test func togglesMarkdownTasksWithoutRewritingTheDocument() {
        let source = "- [ ] First\r\n  * [X] Second\r\nParagraph"
        let blocks = MarkdownParser.parse(source)
        let taskLines = blocks.flatMap { block -> [Int] in
            guard case let .taskList(items) = block.kind else { return [] }
            return items.map(\.id)
        }

        #expect(taskLines == [0, 2])
        #expect(MarkdownTaskToggler.toggledSource(source, taskAtLine: taskLines[0]) ==
            "- [x] First\r\n  * [X] Second\r\nParagraph")
        #expect(MarkdownTaskToggler.toggledSource(source, taskAtLine: taskLines[1]) ==
            "- [ ] First\r\n  * [ ] Second\r\nParagraph")
        #expect(MarkdownTaskToggler.toggledSource(source, taskAtLine: 4) == source)
    }

    @Test @MainActor func createsAShareableMarkdownCopyWithCurrentContents() throws {
        let sharedFile = try DocumentSharePresenter.makeTemporaryFile(
            markdown: "# Current\n\nLatest contents.",
            suggestedName: "A/B: Document"
        )
        defer {
            try? FileManager.default.removeItem(at: sharedFile.deletingLastPathComponent())
        }

        #expect(sharedFile.pathExtension == "md")
        #expect(sharedFile.lastPathComponent == "A-B-Document.md")
        #expect(try String(contentsOf: sharedFile, encoding: .utf8) ==
            "# Current\n\nLatest contents.")
    }

    @Test func printRendererProducesStyledHTMLAndEscapesContent() {
        let source = """
        # Heading

        A **bold** value with `code`, [link](https://example.com?a=1&b=2), and <unsafe>.

        - First
        - Second

        | Name | Value |
        | --- | --- |
        | One | 1 |

        ```swift
        let value = 1 < 2
        ```
        """
        let html = MarkdownPrintRenderer.html(source: source, title: "Test & Print")

        #expect(html.contains("<h1>Heading</h1>"))
        #expect(html.contains("<strong>bold</strong>"))
        #expect(html.contains("<code>code</code>"))
        #expect(html.contains("href=\"https://example.com?a=1&amp;b=2\""))
        #expect(!html.contains("&amp;amp;"))
        #expect(html.contains("&lt;unsafe&gt;"))
        #expect(html.contains("<table>"))
        #expect(html.contains("table-header-group"))
        #expect(html.contains("table { width: 100%;"))
        #expect(html.contains("break-inside: auto; page-break-inside: auto;"))
        #expect(html.contains("tr { break-inside: avoid; page-break-inside: avoid;"))
        #expect(!html.contains("table { width: 100%; border-collapse: collapse; margin: .8em 0; font-size: .93em; break-inside: avoid;"))
        #expect(html.contains("<pre><code class=\"language-swift\">"))
        #expect(!html.contains("# Heading"))
        #expect(!html.contains("**bold**"))
    }
}
