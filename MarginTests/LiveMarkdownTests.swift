import CoreText
import SwiftUI
import Testing
import UIKit
@testable import Margin

struct LiveMarkdownTests {
    @Test func draftWithDisplayMathOrCrossLineCodeStaysLiteral() {
        #expect(!LiveMarkdownLine.canFormatDraft("$$a*b*c$$"))
        #expect(!LiveMarkdownLine.canFormatDraft("  $$\r\na*b*c\r\n$$"))
        #expect(!LiveMarkdownLine.canFormatDraft("`first\n**literal**`"))
        #expect(LiveMarkdownLine.canFormatDraft("One `code` span"))
        #expect(LiveMarkdownLine.canFormatDraft("- **Emphasis**\n- Math $a*b*c$"))
    }

    @Test @MainActor func switchingEquivalentUnicodeRegionsLoadsExactTextBeforeSelection() {
        let decomposed = "Cafe\u{0301}!"
        let composed = "Caf\u{00E9}!"
        #expect(decomposed == composed)
        #expect(decomposed.utf16.count != composed.utf16.count)

        func editor(for text: String) -> NativeMarkdownTextView {
            NativeMarkdownTextView(
                text: .constant(text),
                selectedRange: .constant(NSRange(location: text.utf16.count, length: 0)),
                isFocused: .constant(false),
                findTrigger: 0,
                liveFormatting: true,
                theme: style(enabled: true).theme,
                readerTheme: .github,
                bodySize: 16,
                embedded: true,
                regionID: UUID()
            )
        }
        let view = UITextView(usingTextLayoutManager: false)
        view.text = decomposed
        let coordinator = NativeMarkdownTextView.Coordinator(parent: editor(for: decomposed))
        coordinator.parent = editor(for: composed)
        coordinator.synchronizeBackingText(in: view)

        #expect(view.text.utf16.elementsEqual(composed.utf16))
        #expect(view.selectedRange == NSRange(location: composed.utf16.count, length: 0))
        let inserted = (view.text as NSString).replacingCharacters(in: view.selectedRange, with: "?")
        #expect(inserted.utf16.elementsEqual((composed + "?").utf16))

        coordinator.parent = editor(for: decomposed)
        coordinator.synchronizeBackingText(in: view)
        #expect(view.text.utf16.elementsEqual(decomposed.utf16))
        #expect(view.selectedRange == NSRange(location: decomposed.utf16.count, length: 0))
    }

    @Test func headingAndInlineStylesUseOriginalUTF16Offsets() {
        let source = "## 你好🙂 **bold** and *斜体* ##"
        let line = LiveMarkdownLine(source: source)
        let original = source as NSString
        #expect(line.block == .heading(2))
        #expect(line.hidden.sorted { $0.location < $1.location }.map { original.substring(with: $0) }
            == ["## ", "**", "**", "*", "*", " ##"])
        #expect(line.inline.map { original.substring(with: $0.range) } == ["bold", "斜体"])
        #expect(line.inline.map(\.intent) == [.stronglyEmphasized, .emphasized])
    }

    @Test func linksHideTheirDestinationButImagesAndMalformedMarkdownStayLiteral() {
        let source = #"[docs](https://example.com/a_(b)) ![alt](sample.png) \*literal* **unfinished"#
        let line = LiveMarkdownLine(source: source)
        let original = source as NSString
        #expect(line.hidden.map { original.substring(with: $0) } == ["[", "](https://example.com/a_(b))"])
        #expect(line.inline.filter(\.isLink).map { original.substring(with: $0.range) } == ["docs"])
    }

    @Test func checkboxesAndCodeHaveDistinctPresentation() {
        let source = "  - [x] `*literal*` $a_b_c$ ~~old~~"
        let line = LiveMarkdownLine(source: source)
        #expect(line.marker?.symbol == "☑")
        #expect(line.marker?.range == NSRange(location: 2, length: 5))
        #expect(line.inline.map(\.intent) == [.code, .strikethrough])
        let fenced = LiveMarkdownLine(source: "# **literal**", code: true)
        #expect(fenced.block == .code(fence: false))
        #expect(fenced.hidden.isEmpty)
        #expect(fenced.inline.isEmpty)
    }

    @Test @MainActor func changingActiveLineAndModeDoesNotChangeSourceOrSelection() async {
        let source = "# Head\r\n**bold**\r\n"
        let (view, styler) = makeEditor(source)
        let heading = NSRange(location: 0, length: 0)
        let bold = NSRange(location: 10, length: 4)
        #expect(!isHidden(in: view, at: 0))
        #expect(isHidden(in: view, at: 8))

        view.selectedRange = bold
        await refresh(styler)
        #expect(isHidden(in: view, at: 0))
        #expect(!isHidden(in: view, at: 8))
        #expect(view.text == source)
        #expect(view.selectedRange == bold)

        styler.updateStyle(style(enabled: false))
        await refresh(styler)
        #expect(!isHidden(in: view, at: 0))
        #expect(!isHidden(in: view, at: 8))
        #expect(view.text == source)
        #expect(view.selectedRange == bold)

        view.selectedRange = heading
        styler.updateStyle(style(enabled: true))
        await refresh(styler)
        #expect(!isHidden(in: view, at: 0))
        #expect(isHidden(in: view, at: 8))
    }

    @Test @MainActor func checkboxesUseGlyphsFromTheTextKitFont() {
        let source = "Tasks\n- [ ] First\n- [x] Second"
        let (view, styler) = makeEditor(source)
        withExtendedLifetime(styler) {
            for (location, symbol) in [(6, "☐"), (18, "☑")] {
                let range = NSRange(location: location, length: 1)
                let layout = view.layoutManager
                layout.ensureGlyphs(forCharacterRange: range)
                guard let font = view.textStorage.attribute(.font, at: location, effectiveRange: nil) as? UIFont else {
                    Issue.record("Missing editor font")
                    return
                }
                var character = symbol.utf16.first ?? 0
                var expected: CGGlyph = 0
                #expect(CTFontGetGlyphsForCharacters(font as CTFont, &character, &expected, 1))
                #expect(layout.glyph(at: layout.glyphIndexForCharacter(at: location)) == expected)
                #expect(isHidden(in: view, at: location + 1))
            }
            #expect(view.text == source)
        }
    }

    @Test @MainActor func editingAnOpeningFenceRestylesFollowingLines() async {
        let source = "```\n**code**\n```\n**body**"
        let (view, styler) = makeEditor(source)
        #expect(!isHidden(in: view, at: 4))
        #expect(isHidden(in: view, at: 17))

        view.textStorage.replaceCharacters(in: NSRange(location: 0, length: 3), with: "abc")
        view.selectedRange = NSRange(location: 3, length: 0)
        await refresh(styler)
        #expect(isHidden(in: view, at: 4))
        #expect(!isHidden(in: view, at: 17))
        #expect(view.text == "abc\n**code**\n```\n**body**")
    }

    @Test @MainActor func insertedMarkdownFormatsAfterTheCaretMovesAway() async {
        let (view, styler) = makeEditor("Today:\nNext line")
        let markup = " **field notes**"
        view.textStorage.replaceCharacters(in: NSRange(location: 6, length: 0), with: markup)
        view.selectedRange = NSRange(location: 6 + markup.utf16.count, length: 0)
        await refresh(styler)
        #expect(!isHidden(in: view, at: 7))
        #expect(!isHidden(in: view, at: 20))

        view.selectedRange = NSRange(location: 6 + markup.utf16.count + 1, length: 0)
        await refresh(styler)
        #expect(isHidden(in: view, at: 7))
        #expect(isHidden(in: view, at: 20))
        #expect(view.text == "Today: **field notes**\nNext line")
    }

    @MainActor private func makeEditor(_ text: String) -> (UITextView, LiveMarkdownStyler) {
        let view = UITextView(usingTextLayoutManager: false)
        view.text = text
        view.selectedRange = NSRange(location: 0, length: 0)
        let styler = LiveMarkdownStyler()
        styler.attach(to: view, style: style(enabled: true))
        return (view, styler)
    }

    @MainActor private func style(enabled: Bool) -> LiveMarkdownStyler.Style {
        .init(enabled: enabled, theme: MarkdownTheme(readerTheme: .github, colorScheme: .light), bodySize: 16)
    }

    @MainActor private func refresh(_ styler: LiveMarkdownStyler) async {
        styler.scheduleRefresh()
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    @MainActor private func isHidden(in view: UITextView, at character: Int) -> Bool {
        let layout = view.layoutManager
        layout.ensureGlyphs(forCharacterRange: NSRange(location: character, length: 1))
        return layout.propertyForGlyph(at: layout.glyphIndexForCharacter(at: character)).contains(.null)
    }
}
