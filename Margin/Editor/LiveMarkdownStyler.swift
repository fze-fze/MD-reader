import CoreText
import UIKit

@MainActor
final class LiveMarkdownStyler: NSObject, NSTextStorageDelegate, NSLayoutManagerDelegate {
    struct Style: Equatable {
        let enabled: Bool
        let theme: MarkdownTheme
        let bodySize: Double
    }

    private static let glyphKey = NSAttributedString.Key("Margin.liveGlyph")
    private static let fenceKey = NSAttributedString.Key("Margin.liveFence")

    private weak var view: UITextView?
    private var style: Style?
    private var appliedPalette: Palette?
    private var revealed: NSRange?
    private var dirty: NSRange?
    private var scheduled = false

    func attach(to view: UITextView, style: Style) {
        self.view = view
        self.style = style
        view.textStorage.delegate = self
        view.layoutManager.delegate = self
        refresh()
    }

    func updateStyle(_ style: Style) {
        guard style != self.style else { return }
        self.style = style
        scheduleRefresh()
    }

    func scheduleRefresh() {
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduled = false
            self.refresh()
        }
    }

    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorage.EditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters) else { return }
        revealed = revealed.map { Self.remapping($0, after: editedRange, delta: delta) }
        dirty = dirty.map { NSUnionRange(Self.remapping($0, after: editedRange, delta: delta), editedRange) }
            ?? editedRange
        scheduleRefresh()
    }

    private static func remapping(_ range: NSRange, after edit: NSRange, delta: Int) -> NSRange {
        let oldEnd = NSMaxRange(edit) - delta
        let start = range.location < edit.location ? range.location :
            (range.location >= oldEnd ? range.location + delta : edit.location)
        let end = NSMaxRange(range) <= edit.location ? NSMaxRange(range) :
            (NSMaxRange(range) >= oldEnd ? NSMaxRange(range) + delta : NSMaxRange(edit))
        return NSRange(location: start, length: max(0, end - start))
    }

    private func refresh() {
        guard let view, let style, view.markedTextRange == nil else { return }
        let storage = view.textStorage
        let source = storage.mutableString
        let fullRange = NSRange(location: 0, length: source.length)
        let selection = view.selectedRange
        let visibleSource = style.enabled && selection.location != NSNotFound
            ? source.lineRange(for: NSRange(
                location: min(selection.location, source.length),
                length: min(selection.length, max(0, source.length - selection.location))
            ))
            : nil
        let reset = style != appliedPalette?.style

        var ranges: [NSRange] = []
        if reset {
            ranges.append(fullRange)
        } else {
            if let dirty {
                // Include the line at the end of a deletion/paste. It may be
                // a previously styled line that is now joined to another.
                let start = source.lineRange(for: NSRange(location: dirty.location, length: 0))
                let end = source.lineRange(for: NSRange(location: NSMaxRange(dirty), length: 0))
                ranges.append(NSUnionRange(start, end))
            }
            if revealed != visibleSource {
                if let revealed {
                    let previous = source.lineRange(for: revealed)
                    ranges.append(contentsOf: Self.subtracting(visibleSource, from: previous))
                }
                if let visibleSource {
                    ranges.append(contentsOf: Self.subtracting(revealed, from: visibleSource))
                }
            }
        }
        let palette = appliedPalette.flatMap { $0.style == style ? $0 : nil } ?? Palette(style)
        appliedPalette = palette
        revealed = visibleSource
        dirty = nil

        // UIKit may inherit the previous run's style on selection change.
        view.typingAttributes = palette.base
        guard !ranges.isEmpty, source.length > 0 else { return }
        storage.beginEditing()
        var affected: [NSRange] = []
        if !style.enabled || reset {
            for range in ranges where range.length > 0 {
                storage.setAttributes(palette.base, range: range)
            }
        }
        if style.enabled {
            // Merge overlapping dirty and selection work, then propagate a
            // fence change only until the next line has the same state again.
            for range in Self.merged(ranges) {
                var start = max(range.location, affected.last.map(NSMaxRange) ?? 0)
                let target = NSMaxRange(range)
                var fence = start == 0 ? 0 : fenceState(in: storage, at: start - 1)
                var propagate = false
                let first = start
                while start < source.length, start < target || propagate {
                    var end = 0
                    var contentEnd = 0
                    source.getLineStart(nil, end: &end, contentsEnd: &contentEnd, for: NSRange(location: start, length: 0))
                    let line = NSRange(location: start, length: end - start)
                    let content = NSRange(location: start, length: contentEnd - start)
                    let oldFence = fenceState(in: storage, at: end - 1)
                    let text = source.substring(with: content)
                    let previousFence = fence
                    fence = Self.nextFence(after: text, fence: fence)

                    if !reset { storage.setAttributes(palette.base, range: line) }
                    if fence != 0 {
                        storage.addAttribute(Self.fenceKey, value: fence, range: NSRange(location: end - 1, length: 1))
                    }
                    if visibleSource.map({ NSIntersectionRange($0, line).length == 0 }) ?? true {
                        let isCode = previousFence != 0 || fence != 0
                        let model = LiveMarkdownLine(source: text, code: isCode, fence: previousFence != fence)
                        apply(model, palette: palette, to: storage, in: content)
                    }
                    propagate = oldFence != fence
                    start = end
                }
                if start > first { affected.append(NSRange(location: first, length: start - first)) }
            }
        } else {
            affected = ranges
        }
        storage.endEditing()
        for range in affected where range.length > 0 {
            // The custom glyph attribute is not one of TextKit's built-in
            // glyph invalidators (for example, when revealing a hidden '*').
            view.layoutManager.invalidateGlyphs(forCharacterRange: range, changeInLength: 0, actualCharacterRange: nil)
        }
    }

    private static func subtracting(_ other: NSRange?, from range: NSRange) -> [NSRange] {
        guard let other else { return [range] }
        let overlap = NSIntersectionRange(range, other)
        guard overlap.length > 0 else { return [range] }
        return [
            NSRange(location: range.location, length: overlap.location - range.location),
            NSRange(location: NSMaxRange(overlap), length: NSMaxRange(range) - NSMaxRange(overlap))
        ].filter { $0.length > 0 }
    }

    private static func merged(_ ranges: [NSRange]) -> [NSRange] {
        ranges.filter { $0.length > 0 }.sorted { $0.location < $1.location }.reduce(into: []) { result, range in
            if let last = result.last, NSMaxRange(last) >= range.location {
                result[result.count - 1] = NSUnionRange(last, range)
            } else {
                result.append(range)
            }
        }
    }

    private func fenceState(in storage: NSTextStorage, at location: Int) -> Int {
        storage.attribute(Self.fenceKey, at: location, effectiveRange: nil) as? Int ?? 0
    }

    private static func nextFence(after line: String, fence: Int) -> Int {
        guard let first = line.first(where: { !$0.isWhitespace }),
              first == "`" || first == "~" else { return fence }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if fence != 0 {
            let active = MarkdownParser.Fence(marker: fence > 0 ? "`" : "~", length: abs(fence), info: "")
            return MarkdownParser.closesFence(trimmed, active) ? 0 : fence
        }
        guard let opening = MarkdownParser.fenceOpening(trimmed) else { return 0 }
        return opening.marker == "`" ? opening.length : -opening.length
    }

    private func apply(_ model: LiveMarkdownLine, palette: Palette, to storage: NSTextStorage, in content: NSRange) {
        guard content.length > 0 else { return }
        let style = palette.style
        var weight: UIFont.Weight = .regular
        var size = style.bodySize
        switch model.block {
        case .body:
            break
        case let .heading(level):
            weight = .bold
            size *= style.theme.headingScale(level: level)
            storage.addAttributes([
                .font: MarkdownTypography.inlineUIFonts(theme: style.theme.readerTheme, size: size, weight: weight).strong,
                .foregroundColor: UIColor(style.theme.textStrong)
            ], range: content)
        case .quote:
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = 1.36
            paragraph.firstLineHeadIndent = size
            paragraph.headIndent = size
            storage.addAttributes([
                .foregroundColor: UIColor(style.theme.quoteText),
                .backgroundColor: UIColor(style.theme.quoteFill),
                .paragraphStyle: paragraph
            ], range: content)
        case let .code(fence):
            storage.addAttributes([
                .font: palette.monospace,
                .backgroundColor: UIColor(style.theme.codeFill),
                .foregroundColor: UIColor(fence ? style.theme.textSecondary : style.theme.codeText)
            ], range: content)
        }

        for run in model.inline {
            let range = NSRange(location: content.location + run.range.location, length: run.range.length)
            if run.intent.contains(.code) {
                storage.addAttributes([
                    .font: palette.monospace,
                    .foregroundColor: UIColor(style.theme.inlineCodeText),
                    .backgroundColor: UIColor(style.theme.inlineCodeFill)
                ], range: range)
            } else if run.intent.contains(.emphasized) || run.intent.contains(.stronglyEmphasized) {
                let fonts = MarkdownTypography.inlineUIFonts(theme: style.theme.readerTheme, size: size, weight: weight)
                let strong = run.intent.contains(.stronglyEmphasized) || weight == .bold
                let font = run.intent.contains(.emphasized)
                    ? (strong ? fonts.strongEmphasis : fonts.emphasized)
                    : fonts.strong
                storage.addAttribute(.font, value: font, range: range)
            }
            if run.intent.contains(.strikethrough) {
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            if run.isLink {
                // Leave the label editable, not a tappable URL.
                storage.addAttributes([
                    .foregroundColor: UIColor(style.theme.accent),
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ], range: range)
            }
        }
        for hidden in model.hidden {
            storage.addAttribute(
                Self.glyphKey,
                value: 0,
                range: NSRange(location: content.location + hidden.location, length: hidden.length)
            )
        }
        if let marker = model.marker {
            let first = content.location + marker.range.location
            let character = Array(marker.symbol.utf16)
            let fallback = CTFontCreateForString(palette.markerFont as CTFont, marker.symbol as CFString, CFRange(location: 0, length: 1))
            let font = fallback as UIFont
            var glyph: CGGlyph = 0
            if CTFontGetGlyphsForCharacters(fallback, character, &glyph, 1) {
                storage.addAttributes([
                    .font: font,
                    .foregroundColor: UIColor(style.theme.accent),
                    Self.glyphKey: Int(glyph)
                ], range: NSRange(location: first, length: 1))
                if marker.range.length > 1 {
                    storage.addAttribute(Self.glyphKey, value: 0, range: NSRange(location: first + 1, length: marker.range.length - 1))
                }
            }
        }
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes: UnsafePointer<Int>,
        font: UIFont,
        forGlyphRange glyphRange: NSRange
    ) -> Int {
        guard appliedPalette?.style.enabled == true, let storage = layoutManager.textStorage else { return 0 }
        var renderedGlyphs: [CGGlyph] = []
        var renderedProperties: [NSLayoutManager.GlyphProperty] = []
        var glyphOverride: Int?
        var effective = NSRange()
        for index in 0..<glyphRange.length {
            let character = characterIndexes[index]
            if !NSLocationInRange(character, effective) {
                glyphOverride = storage.attribute(Self.glyphKey, at: character, effectiveRange: &effective) as? Int
            }
            guard let glyphOverride else { continue }
            if renderedProperties.isEmpty {
                renderedGlyphs = Array(UnsafeBufferPointer(start: glyphs, count: glyphRange.length))
                renderedProperties = Array(UnsafeBufferPointer(start: properties, count: glyphRange.length))
            }
            if glyphOverride == 0 {
                renderedProperties[index].insert(.null)
            } else {
                renderedGlyphs[index] = CGGlyph(glyphOverride)
            }
        }
        guard !renderedProperties.isEmpty else { return 0 }
        layoutManager.setGlyphs(
            renderedGlyphs,
            properties: renderedProperties,
            characterIndexes: characterIndexes,
            font: font,
            forGlyphRange: glyphRange
        )
        return glyphRange.length
    }

    private struct Palette {
        let style: Style
        let base: [NSAttributedString.Key: Any]
        let monospace: UIFont
        let markerFont: UIFont

        init(_ style: Style) {
            self.style = style
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = 1.36
            base = [
                .font: MarkdownTypography.documentUIFont(theme: style.theme.readerTheme, size: style.bodySize),
                .foregroundColor: UIColor(style.theme.textPrimary),
                .paragraphStyle: paragraph
            ]
            monospace = UIFont.monospacedSystemFont(ofSize: style.bodySize, weight: .regular)
            markerFont = UIFont.systemFont(ofSize: style.bodySize)
        }
    }
}
