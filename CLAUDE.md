# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Margin — a native iOS/iPadOS Markdown reader & editor (Swift 6, iOS 26 deployment target, Xcode 26.6+). The reading experience is a port of the user's Typora "Claude-like" theme; see `docs/claude-like-theme-spec.md`.

## Commands

```sh
# Build
xcodebuild -project Margin.xcodeproj -scheme Margin -sdk iphonesimulator build

# Test (swift-testing; the target needs a host app, so a simulator destination is required)
xcodebuild test -project Margin.xcodeproj -scheme Margin \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'

# Single test
xcodebuild test -project Margin.xcodeproj -scheme Margin \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:MarginTests/MarkdownParserTests/parsesCoreBlockTypes
```

The project uses **file-system-synchronized groups** (`PBXFileSystemSynchronizedRootGroup`, objectVersion 77). New files under `Margin/` or `MarginTests/` are picked up automatically — never hand-edit `project.pbxproj` to add sources.

## Architecture

### App lifecycle and document ownership

`MDReaderApp` is the SwiftUI `@main` entry point. Its `DocumentGroup` supplies the system document browser, one `MarkdownDocument` (`FileDocument`) value per open file, file coordination, external-change handling, and autosave. `DocumentWorkspaceView` edits `file.$document.text` directly. Do not add a parallel `UIDocument`, session cache, or second file presenter for the same URL.

`MarginAppDelegate` is attached with `@UIApplicationDelegateAdaptor` only to receive the Home Screen Quick Action. `QuickActionDocumentCreator` creates a blank file in the app Documents directory and asks the system to open its URL; the pending path is consumed when the corresponding `DocumentGroup` workspace appears.

### Document operations

- `MarkdownDocument` is the sole open-document model and is also reused by `fileExporter` for "save a copy".
- `DocumentRenamer` renames through `UIDocumentBrowserViewController.renameDocument` (found via `AppPresentationAnchor` traversal) because the app lacks parent-directory permission for provider-owned files. The document stays open: the coordinated move keeps DocumentGroup's internal presenter (autosave) on track, but the published `fileURL` stays stale until reopen, so `DocumentWorkspaceView` tracks the post-rename URL in `renamedFileURL` and derives name/actions from it.
- Like Pages, the navigation bar shows no title text: the toolbar's document icon opens the document menu (`PagesWorkspaceToolbar.documentMenu`) whose topmost section header is the file name, above outline/info and the file actions.
- `DocumentWorkspaceView` must continue to receive `file.$document.text` rather than copying it into independent state.

### Reader pipeline and the block-ID invariant

`source: String` → `MarkdownParser.parse` (hand-rolled, line-based, block-level only) → `[MarkdownBlock]` → `LazyVStack` of `MarkdownBlockView`.

**`MarkdownBlock.id` (and `MarkdownListItem.id`) is the 0-based source line index**, not a sequence number. This invariant is what makes outline jump (`scrollTarget` → `proxy.scrollTo(id)`) and task-toggling (`MarkdownTaskToggler.toggledSource(_:taskAtLine:)` edits the source line in place) work without a separate mapping. Preserve it in any parser change.

Inline markdown (`**bold**`, `` `code` ``, links) is *not* parsed by `MarkdownParser` — it's handed to `AttributedString(markdown:)` with `.inlineOnlyPreservingWhitespace` inside `InlineMarkdownText` / `MarkdownBlock.inlinePlainText`.

Parsing and search indexing run off the main actor via `Task.detached` in `MarkdownReaderView.task(id: source)`; the model types are `nonisolated` + `Sendable` for this reason.

### Math (LaTeX)

Delimiters are `$` only, by design: display math is a standalone `$$…$$` line or a multi-line `$$` fence (`MarkdownBlock.Kind.math`; an unterminated opener stays a paragraph), inline math is `$…$` split out by `InlineMathSegmenter`. `\(…\)`, `\[…\]`, and mid-sentence `$$` are intentionally plain text. Inline code spans and `\$` escapes win over `$`, and a `$` span needs non-space-adjacent delimiters with no digit after the closer (so “$5 和 $10” stays text).

Rendering is native via the **SwiftMath** SPM package (the project's only dependency) in `MathRenderer` (`@MainActor`), which caches by theme/size/color/latex and returns the baseline **descent** so inline formulas sit on the surrounding text baseline (`Text(Image).baselineOffset(-descent)`). `MathRenderer.normalizedLatex` rewrites common commands SwiftMath lacks (`\lVert`/`\rVert`, `\dfrac`, `\operatorname`, `\implies`, …) into supported equivalents before parsing — one unknown command otherwise fails the whole formula; extend `commandAliases` when users hit new ones. Claude theme uses the Termes math font, GitHub uses Latin Modern. Invalid LaTeX falls back to raw source (code styling at block level; `$…$` literal inline).

Search: inline math becomes U+FFFC in `searchableFragments` so index match counts stay aligned with per-segment highlighting; block math is searchable by its raw LaTeX. Print embeds formulas as base64 `<img>` data URIs (`MarkdownPrintRenderer.mathImageTag`, sized in `pt`, inline images baseline-shifted by the descent); invalid LaTeX prints as raw `$$…$$`.

### Search

`DocumentSearchIndex` is built from each block's `searchableFragments` (markdown syntax stripped, so `**` never matches). A `Match` is `(blockID, occurrenceIndex)` where `occurrenceIndex` counts occurrences *within the block*, across its fragments in order. Views then re-derive an `occurrenceOffset` per fragment (list item / table cell) so the "active" match can be highlighted in the right cell — fragment order in `searchableFragments` must stay in lockstep with render order in `MarkdownBlockView`.

`DocumentSearchMatcher` is the single matching primitive (case-, diacritic-, width-insensitive).

Search UI is an on-demand bottom `DocumentSearchBar` presented from the toolbar magnifier (in edit mode the same magnifier presents `UITextView`'s system find panel via a `findTrigger` counter instead) through a stable `safeAreaInset`; do not attach `.searchable` to the document workspace because the navigation drawer becomes permanently visible and can recreate the reader. `DocumentSearchSession` owns the debounced query, result count, current match, and navigation. Typing updates highlights and the count without moving the document; Return or the arrow buttons navigate results, and only matching blocks receive the effective query.

### Theming

`ReaderTheme` (`.claude` / `.github`, user-selectable) × `ColorScheme` → `MarkdownTheme`, a token struct of computed `Color`s (hex literal pairs) plus `headingScale(level:)` and `contentMaxWidth`. All colors and fonts must come from `MarkdownTheme` / `MarkdownTypography` — no ad-hoc `Color(...)` in views.

`MarkdownTypography` builds the Claude serif stack: bundled `AnthropicSerifWebText` for Latin with a `.cascadeList` fallback to bundled `NotoSerifSC` (then system Songti) for CJK. Fonts are registered via `UIAppFonts` in `Info.plist`.

Persistence is three `@AppStorage` keys, declared in `DocumentWorkspaceView`: `readerAppearance`, `readerTextScale`, `readerTheme`.

### Localization

`en` is the Xcode **development language** and `zh-Hans` is a complete translation. There is no in-app language switch; iOS chooses the best available localization from the user's preferred languages.

- SwiftUI: pass semantic keys as `LocalizedStringKey` literals (`Button("workspace.search", …)`).
- UIKit / plain `String`: `L10n.string("key")` / `L10n.format("key", args…)`.
- Info.plist values (`CFBundleTypeName`, `UTTypeDescription`, `UIApplicationShortcutItemTitle`) are localized through `InfoPlist.strings`, not by editing `Info.plist`.

**Every new user-facing string must be added to both `Margin/zh-Hans.lproj/Localizable.strings` and `Margin/en.lproj/Localizable.strings`** — the two files must stay key-for-key identical. Nothing enforces this automatically.

### Printing

`DocumentPrinter` → `MarkdownPrintRenderer.html(source:title:theme:)` produces standalone styled HTML (escaping is hand-rolled and tested) → `UIPrintInteractionController`. The HTML follows the current `ReaderTheme` — per-theme `Palette` drives fonts, colors, and heading scale, and math images render with the theme's math font; print always uses the light palette.

## Tests

`MarginTests/MarkdownParserTests.swift` — swift-testing (`import Testing`, `@Test`, `#expect`), one file that currently covers the parser, statistics, search index, typography cascade, quick action, task toggler, share, and print renderer. Tests that touch `DocumentSharePresenter` etc. need `@MainActor`.

## Conventions

- Swift 6 language mode with `SWIFT_APPROACHABLE_CONCURRENCY`. Pure model/parsing types are marked `nonisolated`; UIKit controllers are `@MainActor`.
- `docs/` and `output/` hold QA reports, audits, and screenshots from previous sessions — useful history, not build inputs.
