import Testing
import UIKit
@testable import Margin

struct AnnotationSegmenterTests {
    @Test func splitsMarkedRunFromPlainText() {
        let segments = AnnotationSegmenter.segments(in: "A ==marked== tail")

        #expect(segments.count == 3)
        #expect(segments[0].text == "A ")
        #expect(segments[0].annotation == nil)
        #expect(segments[1].text == "marked")
        #expect(segments[1].annotation != nil)
        #expect(segments[2].text == " tail")
    }

    @Test func readsStyleAndNoteFromComment() {
        let annotation = MarginAnnotation(style: .circle, note: "look here", groupID: "abc123")
        let source = "A ==marked==\(annotation.comment) tail"

        let segments = AnnotationSegmenter.segments(in: source)
        let parsed = segments.compactMap(\.annotation).first

        #expect(parsed == annotation)
        #expect(AnnotationSegmenter.strippedText(in: source) == "A marked tail")
    }

    @Test func bareHighlightGetsStableDerivedGroupID() {
        let first = AnnotationSegmenter.segments(in: "a ==x== b").compactMap(\.annotation).first
        let second = AnnotationSegmenter.segments(in: "c ==x== d").compactMap(\.annotation).first

        #expect(first?.groupID == second?.groupID)
        #expect(first?.style == .underline)
        #expect(first?.note == "")
    }

    @Test func leavesNonMarkerEqualsAlone() {
        // Spaced comparisons, longer runs, code spans and escapes are all text.
        for source in ["a == b", "a ===x=== b", "`a ==x== b`", "a \\==x== b", "a ==unclosed"] {
            let segments = AnnotationSegmenter.segments(in: source)
            #expect(segments.allSatisfy { $0.annotation == nil }, "unexpected annotation in \(source)")
            #expect(AnnotationSegmenter.strippedText(in: source) == source)
        }
    }

    @Test func malformedCommentStaysLiteral() {
        let source = "a ==x==<!--margin:{not json}--> b"
        let segments = AnnotationSegmenter.segments(in: source)

        // The marker still applies, but the unparseable comment is left as text
        // rather than being silently swallowed.
        #expect(segments.contains { $0.annotation != nil })
        #expect(AnnotationSegmenter.strippedText(in: source) == "a x<!--margin:{not json}--> b")
    }
}

struct InlinePlainTextTests {
    @Test func rendersWithoutInlineOrAnnotationSyntax() {
        let annotation = MarginAnnotation(style: .wavy, note: "n", groupID: "g1")
        let source = "Some **bold** and ==marked==\(annotation.comment) text"

        #expect(InlinePlainText.render(source) == "Some bold and marked text")
    }

    @Test func mapsRenderedOffsetsOntoSourceCharacters() {
        let source = "Some **bold** text"
        let map = InlinePlainText.map(source)
        let rendered = Array(InlinePlainText.render(source))

        #expect(map.count == rendered.count)

        // "bold" renders at offsets 5..<9 and lives inside the ** markers.
        let characters = Array(source)
        let start = map[5].start
        let end = map[8].end
        #expect(String(characters[start..<end]) == "bold")
    }

    @Test func inlineMathCollapsesToASingleRenderedCharacter() {
        let source = "before $x^2$ after"
        let rendered = InlinePlainText.render(source)
        let map = InlinePlainText.map(source)

        #expect(rendered == "before \u{FFFC} after")
        #expect(map.count == rendered.count)

        let characters = Array(source)
        let formula = map[7]
        #expect(String(characters[formula.start..<formula.end]) == "$x^2$")
    }
}

struct SourceLinesTests {
    @Test func preservesMixedLineEndings() {
        for source in ["a\nb\nc", "a\r\nb\r\nc", "a\nb\r\nc\n", ""] {
            #expect(SourceLines.join(SourceLines.split(source)) == source)
        }
    }

    @Test func numbersLinesLikeTheParser() {
        // CharacterSet.newlines treats CR and LF separately, so CRLF yields an
        // empty line between — the parser's convention, which line-indexed
        // block IDs depend on.
        #expect(SourceLines.split("a\r\nb").map(\.text) == ["a", "", "b"])
        #expect(SourceLines.split("a\r\nb").map(\.text) == "a\r\nb".components(separatedBy: .newlines))
    }
}

struct AnnotationWriterTests {
    private let annotation = MarginAnnotation(style: .wavy, note: "note", groupID: "g1")

    @Test func insertsMarkersAroundASingleLineSelection() {
        let source = "Alpha bravo charlie"
        let fragment = AnnotationWriter.Fragment(lines: [0], kind: .paragraph(source))

        let updated = AnnotationWriter.inserting(
            annotation,
            into: source,
            fragment: fragment,
            renderedRange: 6..<11
        )

        #expect(updated == "Alpha ==bravo==\(annotation.comment) charlie")
        #expect(InlinePlainText.render(updated ?? "") == source)
    }

    @Test func splitsASelectionThatSpansTwoParagraphLines() {
        let source = "Alpha bravo\ncharlie delta"
        let fragment = AnnotationWriter.Fragment(lines: [0, 1], kind: .paragraph(source))

        // Rendered text is "Alpha bravo charlie delta"; select "bravo charlie".
        let updated = AnnotationWriter.inserting(
            annotation,
            into: source,
            fragment: fragment,
            renderedRange: 6..<19
        )
        let lines = SourceLines.split(updated ?? "").map(\.text)

        #expect(lines[0] == "Alpha ==bravo==\(annotation.comment)")
        #expect(lines[1] == "==charlie==\(annotation.comment) delta")
        // Both pieces carry the same group, so they read back as one annotation.
        let groups = Set(lines.flatMap { AnnotationSegmenter.segments(in: $0).compactMap(\.annotation?.groupID) })
        #expect(groups == ["g1"])
    }

    @Test func skipsBlockMarkersWhenMappingOffsets() {
        let heading = "## Alpha bravo"
        let updated = AnnotationWriter.inserting(
            annotation,
            into: heading,
            fragment: AnnotationWriter.Fragment(lines: [0], kind: .heading(level: 2, text: "Alpha bravo")),
            renderedRange: 6..<11
        )
        #expect(updated == "## Alpha ==bravo==\(annotation.comment)")

        let task = "- [x] Alpha bravo"
        let updatedTask = AnnotationWriter.inserting(
            annotation,
            into: task,
            fragment: AnnotationWriter.Fragment(lines: [0], kind: .taskList([])),
            renderedRange: 0..<5
        )
        #expect(updatedTask == "- [x] ==Alpha==\(annotation.comment) bravo")
    }

    @Test func refusesToNestInsideAnExistingAnnotation() {
        let source = "Alpha ==bravo==\(annotation.comment) charlie"
        let fragment = AnnotationWriter.Fragment(lines: [0], kind: .paragraph(source))

        let updated = AnnotationWriter.inserting(
            MarginAnnotation(style: .circle, note: "", groupID: "g2"),
            into: source,
            fragment: fragment,
            renderedRange: 0..<11
        )
        #expect(updated == nil)
    }

    @Test func refusesAnEmptySelection() {
        #expect(
            AnnotationWriter.inserting(
                annotation,
                into: "Alpha",
                fragment: AnnotationWriter.Fragment(lines: [0], kind: .paragraph("Alpha")),
                renderedRange: 2..<2
            ) == nil
        )
    }

    @Test func updatesAndRemovesByGroupID() {
        let source = "Alpha ==bravo==\(annotation.comment) charlie"

        let updated = AnnotationWriter.updating(
            groupID: "g1",
            style: .circle,
            note: "changed",
            in: source
        )
        let reparsed = AnnotationSegmenter.segments(in: updated ?? "").compactMap(\.annotation).first
        #expect(reparsed?.style == .circle)
        #expect(reparsed?.note == "changed")

        let removed = AnnotationWriter.removing(groupID: "g1", from: source)
        #expect(removed == "Alpha bravo charlie")

        #expect(AnnotationWriter.removing(groupID: "missing", from: source) == nil)
    }

    @Test func removingRestoresTheOriginalSourceExactly() {
        let source = "Alpha bravo\ncharlie delta"
        let fragment = AnnotationWriter.Fragment(lines: [0, 1], kind: .paragraph(source))

        let annotated = AnnotationWriter.inserting(
            annotation,
            into: source,
            fragment: fragment,
            renderedRange: 6..<19
        )
        #expect(AnnotationWriter.removing(groupID: "g1", from: annotated ?? "") == source)
    }
}

struct AnnotatedBlockTests {
    @Test func searchIndexIgnoresAnnotationSyntax() {
        let annotation = MarginAnnotation(style: .wavy, note: "a private note", groupID: "g1")
        let source = "Alpha ==bravo==\(annotation.comment) charlie"

        let blocks = MarkdownParser.parse(source)
        #expect(blocks.first?.searchableFragments == ["Alpha bravo charlie"])

        // The note lives in a comment, so it must not be searchable document text.
        let index = DocumentSearchIndex(blocks: blocks)
        #expect(index.matches(for: "private").isEmpty)
        #expect(!index.matches(for: "bravo").isEmpty)
    }

    @Test func parserRecordsEveryLineABlockWasBuiltFrom() {
        let source = """
        # Title

        Alpha bravo
        charlie delta

        - one
        - two
        """

        let blocks = MarkdownParser.parse(source)
        let paragraph = blocks.first { if case .paragraph = $0.kind { true } else { false } }
        let list = blocks.first { if case .unorderedList = $0.kind { true } else { false } }

        #expect(paragraph?.id == 2)
        #expect(paragraph?.sourceLines == 2..<4)
        #expect(list?.sourceLines == 5..<7)
        // Single-line blocks still span exactly their own line.
        #expect(blocks.first?.sourceLines == 0..<1)
    }
}

@MainActor
struct SelectableInlineTextRenderingTests {
    private func fonts() -> InlineMarkdownUIFonts {
        MarkdownTypography.inlineUIFonts(theme: .claude, size: 16)
    }

    private var theme: MarkdownTheme {
        MarkdownTheme(readerTheme: .claude, colorScheme: .light)
    }

    // The invariant the whole feature rests on: what the UITextView draws must
    // be character-for-character what `InlinePlainText.render` predicts.
    // Search offsets and the writer's rendered→source mapping are both stated
    // in those coordinates, so any drift silently misplaces marks and edits.
    @Test func drawnCharactersMatchThePredictedPlainText() {
        let annotation = MarginAnnotation(style: .wavy, note: "note", groupID: "g1")
        let sources = [
            "Plain sentence.",
            "With **bold** and *emphasis* and `code`.",
            "A [link](https://example.com) inside.",
            "Formula $E = mc^2$ inline.",
            "An ==marked span==\(annotation.comment) here.",
            "==start==\(annotation.comment) of the line."
        ]

        for source in sources {
            let rendered = InlineMarkdownUIText.rendered(
                source: source,
                fonts: fonts(),
                mathFontSize: 16,
                foregroundColor: UIColor(theme.textPrimary),
                theme: theme
            )
            #expect(rendered.text.string == InlinePlainText.render(source), "mismatch for \(source)")
        }
    }

    @Test func annotationRunsCoverTheMarkedTextOnly() {
        let annotation = MarginAnnotation(style: .circle, note: "why", groupID: "g7")
        let source = "Before ==the marked bit==\(annotation.comment) after."

        let rendered = InlineMarkdownUIText.rendered(
            source: source,
            fonts: fonts(),
            mathFontSize: 16,
            foregroundColor: UIColor(theme.textPrimary),
            theme: theme
        )

        #expect(rendered.annotations.count == 1)
        let run = try! #require(rendered.annotations.first)
        #expect(run.annotation == annotation)
        #expect((rendered.text.string as NSString).substring(with: run.range) == "the marked bit")
    }

    @Test func strongRunsUseTheStrongFace() {
        let fonts = fonts()
        let rendered = InlineMarkdownUIText.rendered(
            source: "a **bold** b",
            fonts: fonts,
            mathFontSize: 16,
            foregroundColor: UIColor(theme.textPrimary),
            theme: theme
        )

        let boldRange = (rendered.text.string as NSString).range(of: "bold")
        let font = rendered.text.attribute(.font, at: boldRange.location, effectiveRange: nil) as? UIFont
        #expect(font == fonts.strong)

        let plainFont = rendered.text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        #expect(plainFont == fonts.regular)
    }

    // Inline formulas are attachments, and the reader seats them on the text
    // baseline by dropping them by the formula's descent — the UIKit stand-in
    // for the SwiftUI path's `.baselineOffset(-descent)`.
    @Test func inlineFormulaAttachmentIsOffsetByItsDescent() {
        let rendered = InlineMarkdownUIText.rendered(
            source: "before $x_1$ after",
            fonts: fonts(),
            mathFontSize: 16,
            foregroundColor: UIColor(theme.textPrimary),
            theme: theme
        )

        let formula = try! #require(
            MathRenderer.formula(
                latex: "x_1",
                fontSize: 16,
                textColor: UIColor(theme.textPrimary),
                display: false,
                readerTheme: .claude
            )
        )
        let location = (rendered.text.string as NSString).range(of: "\u{FFFC}").location
        let attachment = rendered.text.attribute(
            .attachment,
            at: location,
            effectiveRange: nil
        ) as? NSTextAttachment

        #expect(attachment != nil)
        #expect(attachment?.bounds.origin.y == -formula.descent)
    }
}
