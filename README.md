# DailyNotes

A macOS menu bar app for daily notes in a single plain-text file.
Press the hotkey, a floating editor appears with a fresh timestamped
separator, type, press `Esc` — saved and hidden.

## Build

Requires Xcode 27 / Swift 6. No `.xcodeproj`; it is a Swift Package.

```sh
make app          # builds build/DailyNotes.app (ad-hoc signed)
make app SIGN="Developer ID Application: Name (TEAMID)"   # sign with a real identity
make run          # builds and launches it
make test         # unit tests for DailyNotesCore
make sample       # generates build/sample-notes.md (~5 MB) for load testing
cp -r build/DailyNotes.app /Applications
```

## Defaults

| Setting | Default |
|---|---|
| Notes file | `~/Documents/daily-notes.md` |
| Hotkey | `⌃⌥Space` |
| Font | Menlo 14 |
| Panel size | 720×480, remembered after resize |

Backups: first open of each day copies the file to
`~/Library/Application Support/DailyNotes/backups/`, newest 7 kept.
Failed saves land in `~/Library/Application Support/DailyNotes/unsaved-*.md`.
If the file changed on disk while the panel was open, your text is written
to `<name>.conflict-<timestamp>.md` next to it instead.

## Keys

| Key | Action |
|---|---|
| `Esc`, close button, hotkey | save and hide |
| click outside | panel stays, pending edits are saved |
| `⌘N` | new timestamped entry at the end |
| `⌘S` | save now (autosave runs 2 s after typing anyway) |
| `⌘⌥A` | select the current entry (text between separators) |
| `⌘F` | find |
| `⌘,` | settings |
| `⌘?` | help (also in the menu bar menu) |

Launching with `--open` shows the panel immediately (handy for testing).

Design: `docs/superpowers/specs/2026-10-26-daily-notes-design.md`.
