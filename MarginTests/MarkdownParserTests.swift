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

        // Only $$ delimits display math; \[…\] stays ordinary text.
        #expect(mathBlocks.count == 2)
        #expect(mathBlocks[0] == (2, "E = mc^2"))
        #expect(mathBlocks[1].source == "\\sum_{i=1}^n i")
        #expect(blocks.contains { if case .paragraph("中间段落") = $0.kind { true } else { false } })
        // Math blocks are searchable by their raw LaTeX source.
        let firstMath = blocks.first { $0.id == 2 }
        #expect(firstMath?.searchableFragments == ["E = mc^2"])
    }

    @Test func rendersMultilineAlignedFormulasAfterNormalization() {
        let source = """
        \\begin{aligned}
        \\mathcal{L}(\\theta)
        &= -\\sum_{i=1}^{n}
        \\left[
        y_i \\log \\sigma\\!\\left(f_\\theta(x_i)\\right)
        + (1-y_i)\\log\\!\\left(1-\\sigma\\!\\left(f_\\theta(x_i)\\right)\\right)
        \\right] \\\\
        &\\quad + \\lambda \\lVert \\theta \\rVert_2^2
        + \\mu \\sum_{j=1}^{m}
        \\left\\lVert
        \\frac{\\partial f_\\theta(x)}{\\partial x_j}
        \\right\\rVert_1,
        \\qquad
        \\sigma(z)=\\frac{1}{1+e^{-z}}.
        \\end{aligned}
        """

        let normalized = MathRenderer.normalizedLatex(source)
        #expect(!normalized.contains("\\lVert"))
        #expect(!normalized.contains("\\rVert"))
        #expect(normalized.contains("\\Vert"))
    }

    @Test @MainActor func rendersComplexAlignedFormulaToAnImage() {
        let formula = MathRenderer.formula(
            latex: """
            \\begin{aligned}
            \\mathcal{L}(\\theta)
            &= -\\sum_{i=1}^{n}
            \\left[
            y_i \\log \\sigma\\!\\left(f_\\theta(x_i)\\right)
            + (1-y_i)\\log\\!\\left(1-\\sigma\\!\\left(f_\\theta(x_i)\\right)\\right)
            \\right] \\\\
            &\\quad + \\lambda \\lVert \\theta \\rVert_2^2
            + \\mu \\sum_{j=1}^{m}
            \\left\\lVert
            \\frac{\\partial f_\\theta(x)}{\\partial x_j}
            \\right\\rVert_1,
            \\qquad
            \\sigma(z)=\\frac{1}{1+e^{-z}}.
            \\end{aligned}
            """,
            fontSize: 17,
            textColor: .black,
            display: true,
            readerTheme: .claude
        )
        #expect(formula != nil)
        #expect((formula?.image.size.width ?? 0) > 100)
        #expect((formula?.image.size.height ?? 0) > 40)
    }

    @Test func normalizesUnsupportedCommandsWithoutTouchingLongerNames() {
        #expect(MathRenderer.normalizedLatex("\\dfrac{a}{b}") == "\\frac{a}{b}")
        #expect(MathRenderer.normalizedLatex("\\operatorname{ReLU}(x)") == "\\mathrm{ReLU}(x)")
        #expect(MathRenderer.normalizedLatex("a \\implies b") == "a \\Rightarrow b")
        // A longer command that merely starts with an alias name is untouched.
        #expect(MathRenderer.normalizedLatex("\\lVerticalMade{x}") == "\\lVerticalMade{x}")
        #expect(MathRenderer.normalizedLatex("x + y") == "x + y")
    }

    @Test func leavesUnterminatedDisplayMathAsParagraph() {
        let blocks = MarkdownParser.parse("$$\n没有闭合的公式")
        #expect(!blocks.contains { if case .math = $0.kind { true } else { false } })
    }

    @Test @MainActor func loadsAndCachesDocumentRelativeImages() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: 24, height: 12),
            format: format
        )
        let pngData = renderer.pngData { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 12))
        }
        let imageURL = folder.appending(path: "local.png")
        try pngData.write(to: imageURL)

        // A document-relative image must load off the main thread through the
        // same cache the remote path uses, not decode inline in the view body.
        let loaded = try await ReaderImageLoader.shared.image(for: imageURL)
        #expect(loaded.size.width == 24)
        #expect(loaded.size.height == 12)

        // Second request is served from cache — same decoded instance.
        let cached = try await ReaderImageLoader.shared.image(for: imageURL)
        #expect(cached === loaded)

        // A missing file surfaces as an error rather than a blank image.
        let missingURL = folder.appending(path: "missing.png")
        await #expect(throws: (any Error).self) {
            try await ReaderImageLoader.shared.image(for: missingURL)
        }
    }

    @Test func segmenterCacheReturnsIdenticalResultsOnRepeatCalls() {
        let sources = [
            "质能关系 $E=mc^2$ 成立",
            "价格 $5 和 $10 都可以",
            "没有公式的纯文本",
            "`code $x$` 之外 $y$"
        ]
        // Second pass hits the memo; it must equal the freshly computed run.
        let first = sources.map { InlineMathSegmenter.segments(in: $0) }
        InlineMathSegmenter.purgeCache()
        let uncached = sources.map { InlineMathSegmenter.segments(in: $0) }
        let cached = sources.map { InlineMathSegmenter.segments(in: $0) }

        #expect(first == uncached)
        #expect(cached == uncached)
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
        // Only $…$ delimits inline math: \(…\) and mid-sentence $$ stay text.
        #expect(InlineMathSegmenter.segments(in: "括号式 \\(a+b\\) 行内") == [
            .text("括号式 \\(a+b\\) 行内")
        ])
        #expect(InlineMathSegmenter.segments(in: "展示式 $$\\int_0^1 x$$ 嵌入") == [
            .text("展示式 $$\\int_0^1 x$$ 嵌入")
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

    @Test @MainActor func writesExportedFilesWithTheirFormatExtension() throws {
        #expect(DocumentExportFormat.markdown.pathExtension == "md")
        #expect(DocumentExportFormat.pdf.pathExtension == "pdf")
        #expect(DocumentExportFormat.html.pathExtension == "html")

        let html = MarkdownPrintRenderer.html(
            source: "# 标题\n\n正文 $E=mc^2$",
            title: "导出",
            theme: .claude
        )
        let fileURL = try DocumentSharePresenter.makeTemporaryFile(
            data: Data(html.utf8),
            suggestedName: "导出/测试",
            pathExtension: DocumentExportFormat.html.pathExtension
        )
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        #expect(fileURL.pathExtension == "html")
        // Path separators in the document name must not create directories.
        #expect(fileURL.lastPathComponent == "导出-测试.html")
        let written = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(written == html)
        // Exported HTML is self-contained: the formula travels as a data URI.
        #expect(written.contains("data:image/png;base64,"))
    }

    @Test @MainActor func exportsDocumentAsAPaginatedPDF() async throws {
        let source = """
        # 导出测试

        正文有 **粗体** 与行内公式 $E=mc^2$。

        $$
        \\frac{a}{b}
        $$

        \(String(repeating: "很长的段落用来撑满至少一页。\n\n", count: 60))
        """

        let data = try await DocumentPDFExporter.pdfData(
            text: source,
            title: "导出测试",
            theme: .claude,
            baseURL: nil
        )

        #expect(data.starts(with: Array("%PDF".utf8)))

        let document = try #require(CGPDFDocument(CGDataProvider(data: data as CFData)!))
        // The filler paragraphs must paginate rather than clip to one page.
        #expect(document.numberOfPages > 1)
    }

    @Test @MainActor func stylerCacheStaysConsistentAcrossThemesAndFonts() {
        let source = "Plain **bold** with `code` span."
        let claudeLight = MarkdownTheme(readerTheme: .claude, colorScheme: .light)
        let claudeDark = MarkdownTheme(readerTheme: .claude, colorScheme: .dark)
        let bodyFonts = MarkdownTypography.inlineFonts(theme: .claude, size: 16)
        let headingFonts = MarkdownTypography.inlineFonts(
            theme: .claude,
            size: 24,
            weight: .semibold
        )

        // Repeated calls (cache hit) must equal a fresh build.
        let first = InlineMarkdownStyler.attributedString(
            source: source, fonts: bodyFonts, theme: claudeLight
        )
        let second = InlineMarkdownStyler.attributedString(
            source: source, fonts: bodyFonts, theme: claudeLight
        )
        #expect(first == second)

        // A different color scheme recolors the code span, so the cache must
        // not return the light-mode result for dark mode.
        let darkVariant = InlineMarkdownStyler.attributedString(
            source: source, fonts: bodyFonts, theme: claudeDark
        )
        #expect(darkVariant != first)

        // Larger, heavier fonts must not collide with the body-size entry.
        let headingVariant = InlineMarkdownStyler.attributedString(
            source: source, fonts: headingFonts, theme: claudeLight
        )
        #expect(headingVariant != first)
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
        // Emphasis is a synthesized oblique: no bundled face has an italic
        // variant, so the slant lives in the font matrix and the CJK cascade
        // stays on the body serif (it inherits the same shear).
        #expect(italicUIFont.pointSize == 16)
        #expect(CTFontGetMatrix(italicUIFont as CTFont).c > 0)
        #expect(
            italicCascade?.contains { $0.postscriptName == "NotoSerifSC-Regular" }
                == true
        )
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

    @Test func printRendererMatchesReaderForMathAndTasks() {
        let source = """
        行内 $E=mc^2$ 公式

        $$
        \\frac{a}{b}
        $$

        - [x] 已完成
        - [ ] 未完成

        $$\\notarealcommand{x}$$
        """

        let html = MarkdownPrintRenderer.html(source: source, title: "Math", theme: .claude)

        #expect(html.contains("<img class=\"inline-math\""))
        #expect(html.contains("<img class=\"math\""))
        #expect(html.contains("data:image/png;base64,"))
        #expect(html.contains("vertical-align:-"))
        // Task lists suppress the default bullet and draw the reader's
        // SF Symbol checkboxes as embedded images.
        #expect(html.contains("<ul class=\"task-list\">"))
        #expect(html.contains("<img class=\"task-marker\""))
        #expect(!html.contains("<span class=\"task-marker\">"))
        // Invalid LaTeX falls back to raw source between $$.
        #expect(html.contains("<pre class=\"math\">$$\\notarealcommand{x}$$</pre>"))
    }

    @Test func printRendererFollowsReaderTheme() {
        let source = "# Heading\n\n正文 $E=mc^2$ 内容"

        let claude = MarkdownPrintRenderer.html(source: source, title: "T", theme: .claude)
        let github = MarkdownPrintRenderer.html(source: source, title: "T", theme: .github)

        #expect(claude.contains("ui-serif"))
        #expect(claude.contains("#9d552d"))
        #expect(github.contains("-apple-system"))
        #expect(github.contains("#4183c4"))
        #expect(!github.contains("ui-serif"))
        // Math images are theme-specific renders, not shared bitmaps.
        #expect(claude != github)
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
        let html = MarkdownPrintRenderer.html(source: source, title: "Test & Print", theme: .claude)

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

    @Test func recognisesMermaidFencesByTheirInfostring() {
        let source = """
        ```mermaid
        graph TD
          A[Start] --> B[Done]
        ```

        ```swift
        let value = 1
        ```
        """
        let blocks = MarkdownParser.parse(source)
        let languages = blocks.compactMap { block -> String? in
            guard case let .code(language, _) = block.kind else { return nil }
            return language
        }

        #expect(languages == ["mermaid", "swift"])
        #expect(MermaidSupport.isMermaid(language: "mermaid"))
        #expect(MermaidSupport.isMermaid(language: "Mermaid"))
        // Extra words in the infostring still describe a diagram.
        #expect(MermaidSupport.isMermaid(language: "mermaid theme=dark"))
        #expect(!MermaidSupport.isMermaid(language: "swift"))
        #expect(!MermaidSupport.isMermaid(language: "mermaidjs"))
        #expect(!MermaidSupport.isMermaid(language: nil))
        // The diagram source stays searchable even though it renders as a picture.
        #expect(blocks.first?.searchableFragments.first?.contains("A[Start]") == true)
    }

    @Test @MainActor func diagramRenderKeysFollowThemeAppearanceAndTextSize() {
        let claudeLight = MermaidStyle(
            theme: MarkdownTheme(readerTheme: .claude, colorScheme: .light),
            fontSize: 16
        )
        let claudeDark = MermaidStyle(
            theme: MarkdownTheme(readerTheme: .claude, colorScheme: .dark),
            fontSize: 16
        )
        let gitHubLight = MermaidStyle(
            theme: MarkdownTheme(readerTheme: .github, colorScheme: .light),
            fontSize: 16
        )

        #expect(claudeLight != claudeDark)
        #expect(claudeLight != gitHubLight)
        #expect(claudeLight.identity != claudeDark.identity)
        #expect(
            claudeLight == MermaidStyle(
                theme: MarkdownTheme(readerTheme: .claude, colorScheme: .light),
                fontSize: 16
            )
        )
        // Text-size steps round together so the render cache is not fragmented
        // by sizes that produce the same picture.
        #expect(
            claudeLight == MermaidStyle(
                theme: MarkdownTheme(readerTheme: .claude, colorScheme: .light),
                fontSize: 16.1
            )
        )
    }

    @Test @MainActor func exportsADiagramAsAPaddedOpaquePNG() throws {
        let diagram = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }

        let data = try DiagramImageExporter.pngData(for: diagram, background: .white)
        let exported = try #require(UIImage(data: data))
        let padding = DiagramImageExporter.padding
        // Exports render at the diagram's own scale, never below 2x, and a PNG
        // decodes back at scale 1 — so the file is measured in pixels here.
        let renderScale = max(diagram.scale, 2)

        #expect(!data.isEmpty)
        #expect(exported.size.width == (40 + padding * 2) * renderScale)
        #expect(exported.size.height == (30 + padding * 2) * renderScale)
    }

    @Test func printCollectsMermaidSourcesAndRendersThemForTheLightPalette() {
        let source = """
        # Diagrams

        ```mermaid
        graph TD
          A --> B
        ```

        ```swift
        let value = 1
        ```

        ```mermaid theme=neutral
        pie title Blocks
          "Text" : 60
        ```
        """

        // Print warms exactly the blocks it is going to draw as pictures.
        #expect(
            MarkdownPrintRenderer.diagramSources(in: source) == [
                "graph TD\n  A --> B",
                "pie title Blocks\n  \"Text\" : 60"
            ]
        )
        // Print is always on the light palette, whatever the reader shows.
        #expect(
            MarkdownPrintRenderer.diagramStyle(for: .claude) == MermaidStyle(
                theme: MarkdownTheme(readerTheme: .claude, colorScheme: .light),
                fontSize: 15
            )
        )
        #expect(
            MarkdownPrintRenderer.diagramStyle(for: .github)
                != MarkdownPrintRenderer.diagramStyle(for: .claude)
        )

        let html = MarkdownPrintRenderer.html(source: source, title: "Diagrams", theme: .claude)

        #expect(html.contains("img.diagram"))
        // Nothing was rendered in this test, so the diagrams keep printing as
        // their source rather than leaving a hole in the page.
        #expect(html.contains("<pre><code class=\"language-mermaid\">"))
        #expect(html.contains("graph TD"))
        #expect(!html.contains("<img class=\"diagram\""))
    }

    @Test func bundlesTheMermaidRenderingResources() throws {
        let appBundle = try #require(Bundle(identifier: "com.fze.margin"))

        #expect(appBundle.url(forResource: "mermaid-host", withExtension: "html") != nil)
        #expect(appBundle.url(forResource: "mermaid.min", withExtension: "js") != nil)

        let hostURL = try #require(appBundle.url(forResource: "mermaid-host", withExtension: "html"))
        let host = try String(contentsOf: hostURL, encoding: .utf8)
        // The renderer loads the host page from the bundle, so mermaid.js has to
        // sit next to it rather than come off the network.
        #expect(host.contains("src=\"mermaid.min.js\""))
        #expect(host.contains("window.marginMermaid"))
    }
}
