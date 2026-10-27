# Daily Notes — design spec

Date: 2026-10-26
Status: approved in conversation, implementation in progress

## Purpose

A macOS-only menu bar app for jotting daily notes into a single plain-text
file. The whole workflow is: global hotkey → panel appears with a fresh
timestamped separator → type → `Esc` saves and hides. Success criterion:
under a second from hotkey to typing, and typed text is never lost.

The file is ordinary Markdown-ish text, so it stays greppable and syncable
(iCloud Drive, Dropbox, git).

## Scope of v1

In:
- Menu bar agent app (no Dock icon), Spotlight-style floating panel.
- Global hotkey (default `⌃⌥Space`, configurable) and "Open" menu item.
- Single notes file, default `~/Documents/daily-notes.md`, path configurable.
- Timestamped separator appended on open and on `⌘N`; empty session
  separators are removed on close.
- Syntax highlighting: Markdown-lite + fenced code blocks for
  `json`, `sql`, `bash/sh/zsh`, `yaml`, `go`, `js/ts`, `xml/html`.
- Plain-text paste only.
- Autosave while the panel is open, atomic writes, external-change
  detection, daily backups.
- Settings window: file path, hotkey, launch at login, font and size.

Out (explicitly deferred):
- Text transformers / plugins. The editor must not get in their way, but
  nothing is built for them.
- Themes beyond the single built-in light/dark pair.
- Multiple files, search across days, sync.

## Approach

Native AppKit, Swift Package (no `.xcodeproj`), regex-based highlighter.
Chosen over tree-sitter (build complexity not justified for notes) and
WKWebView + CodeMirror (slower cold start, non-native focus/Esc behaviour).

Single external dependency: `KeyboardShortcuts` (sindresorhus) for the
global hotkey and its recorder UI. Launch at login uses `SMAppService`.

## Architecture

### Build layout

```
Package.swift
Makefile                      # builds DailyNotes.app bundle, ad-hoc codesign
Sources/
  DailyNotesCore/             # pure logic, no AppKit UI, unit-tested
  DailyNotesApp/              # AppKit/SwiftUI UI, executable target
Tests/
  DailyNotesCoreTests/        # Swift Testing
Resources/
  Info.plist                  # LSUIElement=YES
```

`make app` runs `swift build -c release`, assembles
`build/DailyNotes.app` (Contents/MacOS binary, Info.plist, Resources) and
signs it ad-hoc. `make run` launches it. `swift test` runs the core tests.

### DailyNotesCore

**`Separator`** — formatting and recognition of the separator line:

```
--------------------< 2026-10-26 14:35 >--------------------
```

20 dashes, `< yyyy-MM-dd HH:mm >` in local time, 20 dashes. Provides
`make(date:)` and a regex that recognises any separator line.

**`EntryFormatter`** — pure functions over `String`:

- `open(text:, date:) -> (text, cursor)`: ensures the text ends with `\n`
  (unless empty), appends the separator and `\n`. Cursor at end. Records the appended separator as belonging to this session.
- `newEntry(text:, date:) -> (text, cursor)` (`⌘N`): if the current
  session entry is empty (nothing but whitespace after the last session
  separator), replaces that separator's timestamp instead of appending a
  new one. Otherwise appends like `open`. Always appends at end of file,
  regardless of cursor position.
- `finalize(text:) -> String`: walks session separators from the end;
  while the last one is followed only by whitespace, removes it and any
  trailing whitespace left behind. Separators from
  previous sessions are never touched. Edits above are preserved.

The formatter is a value type holding the list of session separator
strings; the app creates one per panel session.

**`NoteStore`** — file I/O for a single URL:

- `load() throws -> Snapshot` where `Snapshot = (text, fingerprint)`.
  Missing file → empty text, no error. Fingerprint = SHA-256 of bytes.
- `save(text:, expecting: Snapshot) throws`: re-reads the file; if its
  fingerprint differs from `expecting` → writes the new text to
  `<name>.conflict-<timestamp>.md` next to the file and throws
  `.externalChange(conflictURL)`. Otherwise atomic write (temp file +
  rename), returns the new fingerprint.
- `writeRescue(text:) -> URL`: writes to
  `~/Library/Application Support/DailyNotes/unsaved-<timestamp>.md`.
- `backupIfNeeded(today:)`: on the first call of a calendar day copies the
  file to `~/Library/Application Support/DailyNotes/backups/
  daily-notes-<yyyy-MM-dd>.md` and prunes to the newest 7.

Errors are typed (`NoteStoreError`) and carry a user-readable message.

**`Highlighting`**:

```swift
enum TokenKind { heading, bold, italic, inlineCode, link, listMarker,
                 quote, checkboxDone, separatorDashes, separatorDate,
                 codeFence, codeBlockBackground,
                 keyword, string, number, comment, literal, key }
struct Token { range: Range<String.Index>; kind: TokenKind }
protocol SyntaxHighlighter { func tokens(in text: String,
                                         range: Range<String.Index>) -> [Token] }
```

- `CodeBlockMap`: one line-by-line pass over the whole text finds fenced
  blocks (`lineRange`, `language`, open/closed). Unclosed fence extends to
  end of text. Rebuilt on edits that touch a line containing ```` ``` ````.
- `MarkdownHighlighter`: given the map, highlights Markdown regions with
  regexes and delegates code block bodies to the matching `CodeGrammar`.
- `CodeGrammar`: `language aliases`, ordered list of `(regex, TokenKind)`.
  Earlier rules win on overlap (comments and strings go first). One file
  per language in `Grammars/`. Unknown language → background only.

### DailyNotesApp

- **`AppDelegate`**: wires everything, builds an invisible `mainMenu`
  (App, Edit, Find) so `⌘C/V/X/A/Z/⇧⌘Z/⌘F/⌘,` work without a visible
  menu bar. Handles `⌘Q` → close session then terminate.
- **`StatusItemController`**: menu bar icon, menu: Open, Settings…, Quit.
- **`HotkeyController`**: `KeyboardShortcuts.Name.togglePanel`, toggles
  the panel.
- **`NotePanel`**: `NSPanel` with `.nonactivatingPanel`, `.titled` hidden,
  `.resizable`, `.fullSizeContentView`, floating level, `hidesOnDeactivate`
  off. `frameAutosaveName = "NotePanel"`. Default 720×480 centred.
  Resigning key (click outside) keeps the panel up and flushes pending
  edits to disk.
- **`EditorTextView`**: `NSTextView` (TextKit 2) subclass. Monospace font
  from settings. `cancelOperation(_:)` → close. `paste(_:)` →
  `pasteAsPlainText`. `⌘N` → new entry. `⌘S` → save now. `⌘⌥A` → select the
  current entry (`Separator.entry(containing:in:)`). `⌘`-click opens links. Spell
  check on, smart quotes/dashes/substitutions off.
- **`HighlightCoordinator`**: observes `NSTextStorage` edits, computes the
  dirty paragraph range (whole block if a fence was touched), asks the
  highlighter for tokens and applies `Theme` attributes. On open applies
  the last ~20 KB synchronously, the rest in chunks on the main queue
  between run-loop iterations.
- **`Theme`**: `TokenKind → (NSColor, font traits)` using dynamic colors.
- **`SessionController`**: owns the flow:
  - open: `backupIfNeeded`, `load`, `EntryFormatter.open`, show panel,
    scroll to end, start autosave timer (2 s debounce after each edit).
  - close: `finalize`, `save` if text ≠ loaded snapshot, hide panel. On
    save failure: keep panel open, show banner, `writeRescue`.
  - external change on save: banner with conflict path, panel stays open.
- **`BannerView`**: one-line message above the editor with optional
  "Open Settings" button; read-only editor when load failed.
- **`SettingsView`** (SwiftUI in an `NSWindow`): file path with "Choose…"
  (NSOpenPanel), `KeyboardShortcuts.Recorder`, Launch at login toggle
  (`SMAppService.mainApp`), font family/size. Stored in `UserDefaults`
  via `Settings` observable.

## Error handling

Principle: typed text is never lost.

| Situation | Behaviour |
|---|---|
| File missing | Not an error; empty buffer, file created on first save. |
| File unreadable (permissions, not UTF-8) | Banner with reason + "Open Settings"; editor read-only. |
| Write fails | Panel stays open, banner, copy written to rescue dir; next `Esc` retries. |
| External change detected on save | Our text saved as `.conflict-<ts>.md`, banner, panel stays open; no merge. |
| Hotkey already taken | Shown by `KeyboardShortcuts` recorder; menu bar Open still works. |
| Crash mid-session | At most ~2 s of text lost thanks to autosave; a stray empty separator may remain. |

## Testing

Unit tests (`swift test`, Swift Testing, written TDD-style) for
`DailyNotesCore`:

- `EntryFormatter`: empty file; file without trailing newline; `open`
  then `finalize` with no input removes the separator; with input keeps
  it; `⌘N` on empty entry replaces timestamp; `⌘N` on non-empty entry
  appends; `finalize` removes multiple trailing empty session separators
  but never older ones; edits above the separator survive `finalize`.
- `NoteStore`: missing file loads empty; save then load round-trips;
  atomic write leaves no temp files; external change raises error and
  writes conflict file; backup created once per day and pruned to 7.
- Highlighting: golden tests per grammar; `CodeBlockMap` with closed,
  unclosed and adjacent fences; separator recognition; Markdown regions
  do not leak into code blocks.

Manual checklist (UI, run after `make app`):

- Hotkey opens panel from another app; `Esc` hides it and focus returns
  to that app.
- Clicking outside keeps the panel visible and saves pending edits.
- `⌘C/V/X/A/Z/⇧⌘Z/⌘F` work with no visible app menu.
- `⌘N` appends a separator; repeated `⌘N` on an empty entry only updates
  the time.
- Resize the panel, hide, reopen: size and position preserved.
- Launch at login toggle reflects in System Settings.
- 5 MB generated file: panel appears and accepts typing within ~1 s.
- Editing the file in another editor while the panel is open, then `Esc`:
  conflict file appears, banner shown.
