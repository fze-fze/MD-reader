import Testing
import SwiftUI
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

    @Test @MainActor func documentSearchWaitsForExplicitNavigationBeforeMoving() async {
        let blocks = MarkdownParser.parse("# Alpha\n\nAlpha beta alpha")
        let session = DocumentSearchSession()
        session.replaceIndex(DocumentSearchIndex(blocks: blocks))
        session.activate()
        session.query = "alpha"

        await session.performSearch()

        #expect(session.matches.count == 3)
        #expect(session.activeMatch == nil)
        #expect(session.matchedBlockIDs == [0, 2])

        session.moveToNext()
        #expect(session.activeMatch == .init(blockID: 0, occurrenceIndex: 0))

        session.moveToPrevious()
        #expect(session.activeMatch == .init(blockID: 2, occurrenceIndex: 1))

        session.deactivate()
        #expect(session.query == "alpha")
        #expect(session.matches.isEmpty)

        session.clear()
        #expect(session.matches.isEmpty)
        #expect(session.effectiveQuery.isEmpty)
    }

    @Test @MainActor func closingSearchDiscardsAnInFlightQuery() async {
        let blocks = MarkdownParser.parse("Alpha beta alpha")
        let session = DocumentSearchSession()
        session.replaceIndex(DocumentSearchIndex(blocks: blocks))
        session.activate()
        session.query = "alpha"

        let search = Task { await session.performSearch() }
        await Task.yield()
        session.deactivate()
        await search.value

        #expect(session.matches.isEmpty)
        #expect(session.effectiveQuery.isEmpty)
        #expect(!session.isActive)
    }

    @Test @MainActor func searchKeepsPreviousHighlightsUntilReplacementIsReady() async throws {
        let blocks = MarkdownParser.parse("Alpha alpha beta")
        let session = DocumentSearchSession()
        session.replaceIndex(DocumentSearchIndex(blocks: blocks))
        session.activate()
        session.query = "alpha"
        await session.performSearch()

        #expect(session.matches.count == 2)
        #expect(session.effectiveQuery == "alpha")

        session.query = "beta"
        let replacementSearch = Task { await session.performSearch() }
        try await Task.sleep(for: .milliseconds(20))

        #expect(session.isSearching)
        #expect(session.matches.count == 2)
        #expect(session.effectiveQuery == "alpha")

        await replacementSearch.value
        #expect(!session.isSearching)
        #expect(session.matches.count == 1)
        #expect(session.effectiveQuery == "beta")
    }

    @Test @MainActor func cancellingCurrentSearchStopsProgress() async {
        let blocks = MarkdownParser.parse("Alpha beta")
        let session = DocumentSearchSession()
        session.replaceIndex(DocumentSearchIndex(blocks: blocks))
        session.activate()
        session.query = "alpha"

        let search = Task { await session.performSearch() }
        await Task.yield()
        search.cancel()
        await search.value

        #expect(!session.isSearching)
        #expect(session.matches.isEmpty)
    }

    @Test func parsesDisplayMathBlocks() {
        let source = """
        # 公式

        $$
        E = mc^2
        $$

        中间段落

        $$\\sum_{i=1}^n i$$

        \\[
        \\frac{1}{2}
        \\]
        """

        let blocks = MarkdownParser.parse(source)
        let mathBlocks = blocks.compactMap { block -> (id: Int, source: String)? in
            guard case let .math(source) = block.kind else { return nil }
            return (block.id, source)
        }

        #expect(mathBlocks.count == 3)
        #expect(mathBlocks[0] == (2, "E = mc^2"))
        #expect(mathBlocks[1].source == "\\sum_{i=1}^n i")
        #expect(mathBlocks[2].source == "\\frac{1}{2}")
        #expect(blocks.contains { if case .paragraph("中间段落") = $0.kind { true } else { false } })
        // Math blocks are searchable by their raw LaTeX source.
        #expect(mathBlocks[0].id == 2)
        let firstMath = blocks.first { $0.id == 2 }
        #expect(firstMath?.searchableFragments == ["E = mc^2"])
    }

    @Test func leavesUnterminatedDisplayMathAsParagraph() {
        let blocks = MarkdownParser.parse("$$\n没有闭合的公式")
        #expect(!blocks.contains { if case .math = $0.kind { true } else { false } })
    }

    @Test func segmentsInlineMathWithHeuristics() {
        #expect(InlineMathSegmenter.segments(in: "质能关系 $E=mc^2$ 成立") == [
            .text("质能关系 "),
            .math(latex: "E=mc^2", isDisplay: false),
            .text(" 成立")
        ])
        #expect(InlineMathSegmenter.segments(in: "价格 $5 和 $10 都可以") == [
            .text("价格 $5 和 $10 都可以")
        ])
        #expect(InlineMathSegmenter.segments(in: "转义 \\$5 不是公式") == [
            .text("转义 \\$5 不是公式")
        ])
        #expect(InlineMathSegmenter.segments(in: "`code $x$` 之外 $y$") == [
            .text("`code $x$` 之外 "),
            .math(latex: "y", isDisplay: false)
        ])
        #expect(InlineMathSegmenter.segments(in: "括号式 \\(a+b\\) 行内") == [
            .text("括号式 "),
            .math(latex: "a+b", isDisplay: false),
            .text(" 行内")
        ])
        #expect(InlineMathSegmenter.segments(in: "展示式 $$\\int_0^1 x$$ 嵌入") == [
            .text("展示式 "),
            .math(latex: "\\int_0^1 x", isDisplay: true),
            .text(" 嵌入")
        ])
    }

    @Test func replacesInlineMathWithPlaceholderInSearchableFragments() {
        let blocks = MarkdownParser.parse("alpha $x^2$ beta")
        #expect(blocks.count == 1)
        #expect(blocks[0].searchableFragments == ["alpha \u{FFFC} beta"])
    }

    @Test @MainActor func rendersCommonLatexFormulas() {
        let formula = MathRenderer.formula(
            latex: "\\frac{a}{b} + \\sqrt{x^2} = \\sum_{i=1}^{n} i",
            fontSize: 17,
            textColor: .black,
            display: true,
            readerTheme: .claude
        )
        #expect(formula != nil)
        #expect((formula?.image.size.width ?? 0) > 0)
        #expect((formula?.image.size.height ?? 0) > 0)

        let subscripted = MathRenderer.formula(
            latex: "x_{i}",
            fontSize: 17,
            textColor: .black,
            display: false,
            readerTheme: .claude
        )
        #expect((subscripted?.descent ?? 0) > 0)

        let invalid = MathRenderer.formula(
            latex: "\\notarealcommand{x}",
            fontSize: 17,
            textColor: .black,
            display: true,
            readerTheme: .claude
        )
        #expect(invalid == nil)
    }

    @Test func computesMinimalEditorTextReplacements() {
        let cases: [(old: String, new: String)] = [
            ("Line one\nLine two", "Line one\n**Line** two"),
            ("# 标题\n正文段落", "# 标题\n正文一段落"),
            ("Alpha beta gamma", "Alpha gamma"),
            ("Plain", "**Plain**"),
            ("😀 emoji", "😁 emoji"),
            ("", "Fresh document"),
            ("Old contents", ""),
            ("Same", "Same")
        ]

        for testCase in cases {
            let change = NativeMarkdownTextView.changedRange(
                from: testCase.old,
                to: testCase.new
            )
            let applied = (testCase.old as NSString).replacingCharacters(
                in: change.range,
                with: change.replacement
            )
            #expect(applied == testCase.new)
        }

        let insertion = NativeMarkdownTextView.changedRange(
            from: "Hello world",
            to: "Hello brave world"
        )
        #expect(insertion.range == NSRange(location: 6, length: 0))
        #expect(insertion.replacement == "brave ")
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

    @Test @MainActor func findsDocumentBrowserUsedByDocumentViewController() {
        let rootController = UIViewController()
        let documentController = UIDocumentViewController(document: nil)
        rootController.addChild(documentController)
        documentController.didMove(toParent: rootController)

        #expect(
            DocumentRenamer.documentBrowser(in: rootController) ===
                documentController.launchOptions.browserViewController
        )
    }

    @Test @MainActor func validatesDocumentNamesBeforeRenaming() {
        #expect(DocumentRenamer.isValidName("Notes"))
        #expect(!DocumentRenamer.isValidName("   "))
        #expect(!DocumentRenamer.isValidName("Folder/Notes"))
    }

    @Test func includesSeparatedEnglishAndSimplifiedChineseResources() throws {
        let appBundle = try #require(Bundle(identifier: "com.fze.margin"))
        let english = try localizedBundle(language: "en", in: appBundle)
        let chinese = try localizedBundle(language: "zh-Hans", in: appBundle)

        #expect(appBundle.developmentLocalization == "en")
        #expect(appBundle.localizations.contains("en"))
        #expect(appBundle.localizations.contains("zh-Hans"))
        #expect(english.localizedString(forKey: "workspace.search", value: nil, table: nil) == "Search")
        #expect(chinese.localizedString(forKey: "workspace.search", value: nil, table: nil) == "搜索")
        #expect(english.localizedString(forKey: "settings.title", value: nil, table: nil) == "Reading Settings")
        #expect(chinese.localizedString(forKey: "settings.title", value: nil, table: nil) == "阅读设置")

        let englishTemplate = try localizedTemplate(in: english)
        let chineseTemplate = try localizedTemplate(in: chinese)
        #expect(englishTemplate.hasPrefix("# Welcome to Margin"))
        #expect(chineseTemplate.hasPrefix("# 欢迎使用 Margin"))
    }

    @Test @MainActor func rendersStrongEmphasisAndCombinedEmphasisWithConcreteFonts() {
        let fonts = MarkdownTypography.inlineFonts(
            theme: .claude,
            size: 16
        )
        let attributed = InlineMarkdownStyler.attributedString(
            source: "Plain **bold** and *italic* and ***both***.",
            fonts: fonts,
            theme: MarkdownTheme(readerTheme: .claude, colorScheme: .light)
        )
        let strongRuns = attributed.runs.filter {
            $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
        }
        let emphasizedRuns = attributed.runs.filter {
            $0.inlinePresentationIntent?.contains(.emphasized) == true
        }
        let regularCJK = renderedMarkdown(
            "中文强调",
            fonts: fonts
        )
        let italicCJK = renderedMarkdown(
            "*中文强调*",
            fonts: fonts
        )
        let boldCJK = renderedMarkdown(
            "**中文强调**",
            fonts: fonts
        )
        let italicUIFont = MarkdownTypography.inlineItalicUIFont(
            theme: .claude,
            size: 16,
            weight: .regular
        )
        let italicCascade = italicUIFont.fontDescriptor.object(forKey: .cascadeList)
            as? [UIFontDescriptor]
        let strongUIFont = MarkdownTypography.inlineStrongUIFont(
            theme: .claude,
            size: 16,
            weight: .bold
        )
        let strongCascade = strongUIFont.fontDescriptor.object(forKey: .cascadeList)
            as? [UIFontDescriptor]

        #expect(strongRuns.count == 2)
        #expect(emphasizedRuns.count == 2)
        #expect(strongRuns.allSatisfy { $0.font != nil })
        #expect(emphasizedRuns.allSatisfy { $0.font != nil })
        #expect(regularCJK != nil)
        #expect(italicCJK != regularCJK)
        #expect(boldCJK != regularCJK)
        #expect(italicUIFont.fontDescriptor.symbolicTraits.contains(.traitItalic))
        #expect(italicCascade?.contains { $0.postscriptName.contains("Kaiti") } == true)
        #expect(strongUIFont.fontDescriptor.withDesign(.serif) != nil)
        #expect(
            strongCascade?.contains { $0.postscriptName == "NotoSerifSC-SemiBold" }
                == true
        )
    }

    @MainActor
    private func renderedMarkdown(
        _ source: String,
        fonts: InlineMarkdownFonts
    ) -> Data? {
        let theme = MarkdownTheme(readerTheme: .claude, colorScheme: .light)
        let attributed = InlineMarkdownStyler.attributedString(
            source: source,
            fonts: fonts,
            theme: theme
        )
        let renderer = ImageRenderer(
            content: Text(attributed)
                .font(fonts.regular)
                .foregroundStyle(.black)
                .padding(8)
        )
        renderer.scale = 2
        return renderer.uiImage?.pngData()
    }

    private func localizedBundle(language: String, in appBundle: Bundle) throws -> Bundle {
        let path = try #require(appBundle.path(forResource: language, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    private func localizedTemplate(in bundle: Bundle) throws -> String {
        let url = try #require(bundle.url(forResource: "DefaultDocument", withExtension: "md"))
        return try String(contentsOf: url, encoding: .utf8)
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
