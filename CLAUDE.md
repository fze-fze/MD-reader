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
- `DocumentRenamer` coordinates a move with `NSFileCoordinator` and reports it with `item(at:didMoveTo:)`, allowing the `DocumentGroup` file presenter to follow the new URL.
- `DocumentWorkspaceView` must continue to receive `file.$document.text` rather than copying it into independent state.

### Reader pipeline and the block-ID invariant

`source: String` → `MarkdownParser.parse` (hand-rolled, line-based, block-level only) → `[MarkdownBlock]` → `LazyVStack` of `MarkdownBlockView`.

**`MarkdownBlock.id` (and `MarkdownListItem.id`) is the 0-based source line index**, not a sequence number. This invariant is what makes outline jump (`scrollTarget` → `proxy.scrollTo(id)`) and task-toggling (`MarkdownTaskToggler.toggledSource(_:taskAtLine:)` edits the source line in place) work without a separate mapping. Preserve it in any parser change.

Inline markdown (`**bold**`, `` `code` ``, links) is *not* parsed by `MarkdownParser` — it's handed to `AttributedString(markdown:)` with `.inlineOnlyPreservingWhitespace` inside `InlineMarkdownText` / `MarkdownBlock.inlinePlainText`.

Parsing and search indexing run off the main actor via `Task.detached` in `MarkdownReaderView.task(id: source)`; the model types are `nonisolated` + `Sendable` for this reason.

### Search

`DocumentSearchIndex` is built from each block's `searchableFragments` (markdown syntax stripped, so `**` never matches). A `Match` is `(blockID, occurrenceIndex)` where `occurrenceIndex` counts occurrences *within the block*, across its fragments in order. Views then re-derive an `occurrenceOffset` per fragment (list item / table cell) so the "active" match can be highlighted in the right cell — fragment order in `searchableFragments` must stay in lockstep with render order in `MarkdownBlockView`.

`DocumentSearchMatcher` is the single matching primitive (case-, diacritic-, width-insensitive).

Search UI is an on-demand bottom `DocumentSearchBar` presented from the toolbar magnifier through a stable `safeAreaInset`; do not attach `.searchable` to the document workspace because the navigation drawer becomes permanently visible and can recreate the reader. `DocumentSearchSession` owns the debounced query, result count, current match, and navigation. Typing updates highlights and the count without moving the document; Return or the arrow buttons navigate results, and only matching blocks receive the effective query.

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

`DocumentPrinter` → `MarkdownPrintRenderer.html(source:title:)` produces standalone styled HTML (escaping is hand-rolled and tested) → `UIPrintInteractionController`.

## Tests

`MarginTests/MarkdownParserTests.swift` — swift-testing (`import Testing`, `@Test`, `#expect`), one file that currently covers the parser, statistics, search index, typography cascade, quick action, task toggler, share, and print renderer. Tests that touch `DocumentSharePresenter` etc. need `@MainActor`.

## Conventions

- Swift 6 language mode with `SWIFT_APPROACHABLE_CONCURRENCY`. Pure model/parsing types are marked `nonisolated`; UIKit controllers are `@MainActor`.
- `docs/` and `output/` hold QA reports, audits, and screenshots from previous sessions — useful history, not build inputs.
