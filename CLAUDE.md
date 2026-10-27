# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Scrapbench: a macOS-only menu bar app (Swift Package, no `.xcodeproj`), a workbench for text
scraps: one plain-text file edited in a floating panel. Each open appends a timestamped separator
line; `Esc` saves and hides. The design spec in `docs/superpowers/specs/2026-10-26-daily-notes-design.md` is the
authority on behaviour; update it when behaviour changes.

## Commands

```sh
make app                                    # release build → build/Scrapbench.app (ad-hoc signed)
make app SIGN="Developer ID Application: …" # sign with a real identity (hardened runtime)
make run                                    # build + open the app
make test                                   # = swift test (ScrapbenchCore only)
swift test --filter EntryFormatterTests                      # one suite
swift test --filter EntryFormatterTests/openOnEmptyText      # one test
make sample                                 # ~5 MB build/sample-notes.md for load testing
```

Tests use Swift Testing (`@Test`, `#expect`), not XCTest. The app target has no tests; UI behaviour
is verified by running the app.

## Manual testing of the app

- `build/Scrapbench.app/Contents/MacOS/Scrapbench --open` shows the panel immediately.
- Always `pkill -x Scrapbench` before relaunching; two instances fight over the file and hotkey.
- Point the app at a scratch file instead of the real notes with
  `defaults write org.nosenko.Scrapbench filePath /path/to/file.md`; restore with
  `defaults delete org.nosenko.Scrapbench filePath`. Preferences live in that domain
  (file path, font, window frame, hotkey).

## Architecture

Two targets with different language modes (see `Package.swift`):

- `ScrapbenchCore` (Swift 6 mode, pure Foundation, fully unit-tested): everything that can be
  reasoned about without AppKit.
  - `Separator` — the `--------------------< yyyy-MM-dd HH:mm >--------------------` line format.
  - `EntryFormatter` — `open` / `newEntry` / `finalize`. It tracks only the separators *this
    session* appended; `finalize` strips those left empty and never touches older ones. The
    separator goes directly on the line after existing text (no blank line).
  - `NoteStore` — load/save with a SHA-256 fingerprint; a save against a file that changed on
    disk writes a `.conflict-*` file instead of overwriting; daily backups (7 kept); rescue copies
    on failed writes.
  - `Highlighting/` — `SyntaxHighlighter` returns `Token`s (UTF-16 `NSRange` + `TokenKind`) for a
    range. `MarkdownHighlighter` runs Markdown-lite rules outside fenced blocks and delegates
    fenced blocks to a `CodeGrammar` picked by language (`Grammars/`). `CodeBlockMap` locates
    fences with one pass and supports `shifted(after:by:)` so the app can avoid rescanning on
    plain edits. Tokens carry no colours; `TokenKind` → attributes is the app's job.

- `ScrapbenchApp` (Swift 5 mode, AppKit + a SwiftUI settings form, depends on
  `KeyboardShortcuts`):
  - `SessionController` owns the open → edit → close flow: loads the file, runs the formatter,
    shows the panel, autosaves 2 s after typing, flushes on focus loss and `⌘S`, finalizes and
    saves on close. All save errors surface in `BannerView` inside the panel.
  - `NotePanel` is a non-activating floating `NSPanel`, so the previous app keeps its menu bar.
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
- Highlighter grammars list comment and string rules first; earlier rules win on overlap.
