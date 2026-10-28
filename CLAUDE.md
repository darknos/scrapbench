# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Scrapbench: a macOS-only menu bar app (Swift Package, no `.xcodeproj`), a workbench for text
scraps: one plain-text file edited in a floating panel. Each open appends a timestamped separator
line; `Esc` saves and hides. The design spec in `docs/specs/2026-10-26-daily-notes-design.md` is the
authority on behaviour; update it when behaviour changes.

## Commands

```sh
make app                                    # release build → build/Scrapbench.app (ad-hoc signed)
make app SIGN="Developer ID Application: …" # sign with a real identity (hardened runtime)
make run                                    # build + open the app
make test                                   # = swift test (ScrapbenchCore only)
swift test --filter ScrapFormatterTests                      # one suite
swift test --filter ScrapFormatterTests/openOnEmptyText      # one test
make sample                                 # ~5 MB build/sample-scraps.md for load testing
```

Tests use Swift Testing (`@Test`, `#expect`), not XCTest. The app target has no tests; UI behaviour
is verified by running the app.

## Manual testing of the app

- `build/Scrapbench.app/Contents/MacOS/Scrapbench --open` shows the panel immediately.
- Always `pkill -x Scrapbench` before relaunching; two instances fight over the file and hotkey.
- Point the app at a scratch file instead of the real scrap file with
  `defaults write org.nosenko.Scrapbench filePath /path/to/file.md`; restore with
  `defaults delete org.nosenko.Scrapbench filePath`. Preferences live in that domain
  (file path, font, window frame, hotkey).
- The "Take to Scrapbench" service is found through LaunchServices. After a rebuild in `build/`,
  register it with
  `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f build/Scrapbench.app`
  and `/System/Library/CoreServices/pbs -update`. It can be invoked without the UI from a
  small Swift tool calling `NSPerformService("Take to Scrapbench", pasteboard)`.

- Script transformers live in `~/Library/Application Support/Scrapbench/Transformers/`; put a
  few throwaway scripts there (`sleep 5; tr a-z A-Z`, `exit 3`) to check the asynchronous path.

## Architecture

Two targets with different language modes (see `Package.swift`):

- `ScrapbenchCore` (Swift 6 mode, pure Foundation, fully unit-tested): everything that can be
  reasoned about without AppKit.
  - `Separator` — the `--------------------< yyyy-MM-dd HH:mm >--------------------` line format.
  - `ScrapFormatter` — `open` / `newScrap` / `finalize`. It tracks only the separators *this
    session* appended; `finalize` strips those left empty and never touches older ones. The
    separator goes directly on the line after existing text (no blank line).
  - `ScrapStore` — load/save with a SHA-256 fingerprint; a save against a file that changed on
    disk writes a `.conflict-*` file instead of overwriting; daily backups (7 kept); rescue copies
    on failed writes.
  - `Transformers/` — `Transformer` protocol (`canApply` is cheap and never throws; `apply` throws
    `TransformError` with a short lower-case message), `TransformerRegistry.builtIn` in palette
    order, `FuzzyMatcher` for the palette. Line-based transformers go through `Lines`, which owns
    the trailing-newline and CRLF rules. `Calculator` wraps the `Expression` package (the only
    dependency of Core); JSON pretty/minify is a token-level reformatter so key order survives.
    Spec: `docs/specs/2026-10-27-transformers-design.md`.
  - `Highlighting/` — `SyntaxHighlighter` returns `Token`s (UTF-16 `NSRange` + `TokenKind`) for a
    range. `MarkdownHighlighter` runs Markdown-lite rules outside fenced blocks and delegates
    fenced blocks to a `CodeGrammar` picked by language (`Grammars/`).
    `Transformers/Scripts/`: `ScriptHeader` parses the `# @key value` lines, `ScriptRegistry.scan`
    lists executable files in a folder as `ScriptTransformer`s (`canApply` is always true;
    `apply` throws, the app runs the file), `PendingTransform` keeps the target range in step
    with edits while a script runs. Spec: `docs/specs/2026-10-28-script-transformers-design.md`. `CodeBlockMap` locates
    fences with one pass and supports `shifted(after:by:)` so the app can avoid rescanning on
    plain edits. Tokens carry no colours; `TokenKind` → attributes is the app's job.

- `ScrapbenchApp` (Swift 5 mode, AppKit + a SwiftUI settings form, depends on
  `KeyboardShortcuts`):
  - `SessionController` owns the open → edit → close flow: loads the file, runs the formatter,
    shows the panel, autosaves 2 s after typing, flushes on focus loss and `⌘S`, finalizes and
    saves on close. All save errors surface in `BannerView` inside the panel.
  - `TransformController` resolves the target (selection, else the current scrap, selected in
    place), applies a transformer through `EditorTextView.replace` (one undo step) and reports
    `TransformError` with `BannerView.flash` (auto-hides, unlike save banners). A
    `ScriptTransformer` goes to `ScriptRunner` (`Process` with a timeout, pipes read through
    `readabilityHandler`, completion on the main thread) and the result is applied when it
    arrives: in place if `PendingTransform` says the target is intact, else appended as a new
    scrap via `SessionController.appendResult`. The app never modifies script files (no
    `chmod`). The palette is a
    `PaletteView` inside the panel driven by `PaletteController` (rows come from Core's
    `PaletteRows`: `Recent` first, last-used wins ties); `BenchPanel.sendEvent` closes it on a
    click outside, `resignKey` on focus loss. `HeaderView` holds the file name, save status and
    the Transform button; `PaletteController` must be created after the header is in the view
    tree, or its constraints throw and the panel never shows.
  - `BenchPanel` is a non-activating floating `NSPanel`, so the previous app keeps its menu bar.
    Because of that, `MainMenu` builds a never-shown main menu purely so `⌘C/V/X/A/Z/F` reach the
    text view. `⌘N` and `⌘S` are handled in `EditorTextView.keyDown` by `keyCode` (45 and 1) so
    they work under non-Latin layouts. The panel overrides `close()` to route the title bar
    close button through the session's save path.
  - `EditorTextView` is a TextKit 2 `NSTextView`. Non-obvious parts, all there for a reason:
    - `bottomPadding` (half the view height, via an asymmetric `textContainerInset` and
      `textContainerOrigin`) lets the document end sit at the centre on open. Do not use scroll
      view `contentInsets` for this: AppKit routes mouse events in the inset area to a private
      background view, so clicks and selection below the middle stop working.
      `scrollToVisible`/`scrollRangeToVisible` are overridden for minimal scrolling so typing
      flows down to the real bottom edge; the caret rect comes from TextKit 2 after
      `ensureLayout`, because `firstRect(forCharacterRange:)` is zero right after an edit.
    - `centerEnd` runs over several run-loop passes and re-runs on text-width changes while
      `anchorsEnd` is set, because TextKit 2 estimates heights of unlaid-out text and macOS
      switches the scroller style (and thus the text width) only after the first display.
    - `drawBackground` paints full-width code block backgrounds from the coordinator's
      `CodeBlockMap`; `TokenKind.codeBlockBackground` itself maps to no attributes.
    - `wrapsLines` switches the text container between tracking the view width and an unbounded
      width with a horizontal scroller; `scrollToVisible` also scrolls sideways and `drawBackground`
      paints code block backgrounds over `visibleRect`, not `bounds`, so both modes look right.
    - `replaceTail(with:)` applies a whole-document replacement as a minimal undoable edit so
      `⌘N` does not reload or re-layout the file.
  - `HighlightCoordinator` is an `NSTextStorageDelegate` that colours lazily: only the viewport
    (plus a margin) is highlighted, tracked in an `IndexSet`; edits shift the set and the code
    block map rather than rescanning. Eager whole-file highlighting is quadratic in
    `NSTextStorage` and was removed on purpose; keep highlighting viewport-driven.
  - `Theme` maps `TokenKind` → `NSAttributedString` attributes. Fonts are monospace everywhere;
    emphasis is colour/weight only.

## Conventions specific to this repo

- `Resources/Info.plist` is copied verbatim into the bundle by the Makefile; `LSUIElement` keeps
  the app out of the Dock. Bundle id is `org.nosenko.Scrapbench`.
- `docs/demo.gif` is recorded by `Scripts/record-demo.sh` (drives the built app with
  `Scripts/demo-driver.swift`, needs `gifski`, `ffmpeg` and accessibility access for the terminal).
  Place the panel first; the script captures it where it is and restores the file path afterwards.
- Icons are SVGs in `Resources/Icon/`; `make app` renders them with `Scripts/make-icons.sh`
  (needs `rsvg-convert` from `brew install librsvg`) into `build/icons/` and copies the `.icns`
  and the menu bar template PNGs into the bundle. Edit the SVGs, never the rendered files.
- Highlighter grammars list comment and string rules first; earlier rules win on overlap.

## Brand and naming

`docs/style.md` is the authority on name, vocabulary, voice and visual boundaries; read it
before touching UI copy, README, icons or anything user-facing. `docs/internal/` (git-ignored)
holds the full brand brief and the implementation plans. The parts that affect code:

- The name is `Scrapbench` — one word, capital S only. Never `ScrapBench`, never `SB`.
- Vocabulary: *scrap* = one fragment between separators, *bench* = the panel, *tool* /
  *transformer* = an action on selected text. Use these in UI strings and type names; do not
  call the product or its scraps "notes" / "journal" in user-facing text.
- Voice in UI copy, errors, README and release notes: short sentences, no exclamation marks,
  state what happens and what does not.
- Fully open source (MIT), no monetisation. Authorship is deliberate: author name,
  `sergey@nosenko.org` and GitHub handle are spelled identically in README, About,
  `CODEOWNERS`, SECURITY.md. Nothing that looks commercial (pricing, "Pro", waitlist).
- Fonts are monospace everywhere in the app; emphasis is colour/weight only (see `Theme`).
