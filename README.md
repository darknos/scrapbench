# Scrapbench

A workbench for text scraps, living in the macOS menu bar. One plain-text
file, a floating editor with syntax highlighting, a timestamped separator
per session. Press the hotkey, paste, split, fix that long command line,
jot the thought, press `Esc` — saved and hidden.

## Build

Requires Xcode 27 / Swift 6. No `.xcodeproj`; it is a Swift Package.

```sh
make app          # builds build/Scrapbench.app (ad-hoc signed)
make app SIGN="Developer ID Application: Name (TEAMID)"   # sign with a real identity
make run          # builds and launches it
make test         # unit tests for ScrapbenchCore
make sample       # generates build/sample-notes.md (~5 MB) for load testing
cp -r build/Scrapbench.app /Applications
```

## Defaults

| Setting | Default |
|---|---|
| Notes file | `~/Documents/scrapbench.md` |
| Hotkey | `⌃⌥Space` |
| Font | Menlo 14 |
| Panel size | 720×480, remembered after resize |

Backups: first open of each day copies the file to
`~/Library/Application Support/Scrapbench/backups/`, newest 7 kept.
Failed saves land in `~/Library/Application Support/Scrapbench/unsaved-*.md`.
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

## Take to Scrapbench

Select text in any app, right-click → Services → **Take to Scrapbench**: the
text lands at the end of your file on its own line, under a fresh
separator if the panel was hidden. Assign it a global shortcut in
System Settings → Keyboard → Keyboard Shortcuts → Services → Text.
The service appears once the app has been launched from `/Applications`.

Design: `docs/superpowers/specs/2026-10-26-daily-notes-design.md`.

## License

MIT, see `LICENSE`.
