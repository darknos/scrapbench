<p align="center">
  <img src="docs/icon.png" width="128" alt="">
</p>
<h1 align="center">Scrapbench</h1>
<p align="center">A workbench for text scraps, in the macOS menu bar.</p>

One plain-text file, a floating editor with syntax highlighting, a timestamped
separator per session. Press the hotkey, paste, split, fix that long command
line, jot the thought, press `Esc` — saved and hidden.

![Paste a command, split it; paste JSON, pretty-print it; epoch, calculator, base64: each scrap under its own timestamp](docs/demo.gif)

## Install

```sh
brew trust darknos/scrapbench      # Homebrew asks this once for third-party taps
brew install darknos/scrapbench/scrapbench
```

Or download `Scrapbench-<version>.zip` from the
[latest release](https://github.com/darknos/scrapbench/releases/latest) and drop
`Scrapbench.app` into `/Applications`. Releases are signed with a Developer ID and
notarized. macOS 14 or later.

## Build

Requires Xcode 27 / Swift 6 and `rsvg-convert` (`brew install librsvg`) for the
icons. No `.xcodeproj`; it is a Swift Package.

```sh
make app          # builds build/Scrapbench.app (ad-hoc signed)
make app SIGN="Developer ID Application: Name (TEAMID)"   # sign with a real identity
make run          # builds and launches it
make test         # unit tests for ScrapbenchCore
make sample       # generates build/sample-scraps.md (~5 MB) for load testing
cp -r build/Scrapbench.app /Applications
```

## Defaults

| Setting | Default |
|---|---|
| Scrap file | `~/Documents/scrapbench.md` |
| Hotkey | `⌃⌥Space` |
| Font | Menlo 14 |
| Appearance | System (light or dark follows macOS) |
| Stay on top | On (the bench floats over other windows; off makes it an ordinary window) |
| Indent | 2 spaces (4 spaces or a tab in Settings) |
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
| `⌘N` | new timestamped scrap at the end |
| `⌘S` | save now (autosave runs 2 s after typing anyway) |
| `⌘⌥A` | select the current scrap (text between separators) |
| `Tab`, `⇧Tab` | indent or outdent the selected lines by one unit (`⇧Tab` works on the current line too); a bare `Tab` inserts one unit |
| `⌘⌥W` | word wrap on or off (the ↵ button in the header does the same) |
| `⌘K` | transform the selection or the current scrap (palette; the header button does the same; `⌘K` again applies the last one) |
| `⌘⇧K` | repeat the last transformer |
| `⌘F` | find |
| `⌘,` | settings |

Closing the panel finishes the scrap: empty separators go, and a ``` fence
left open gets its closing line, so the next scrap never lands inside it.
| `⌘?` | help (also in the menu bar menu) |

Launching with `--open` shows the panel immediately (handy for testing).

## Transformers

`⌘K` opens a palette under the header over the selection, or over the current scrap when
nothing is selected. It lists only the transformers that apply to that text,
with fuzzy search; `Enter` replaces the text in one undo step. Built-ins:

- **Case**: UPPER CASE, lower case, Title Case, camelCase, snake_case,
  kebab-case, CONSTANT_CASE (identifier styles work per line).
- **Encoding**: Base64 encode / decode, URL encode / decode, JSON string
  escape / unescape.
- **Lines**: JSON pretty / minify (key order and numbers kept as written),
  Sort lines, Sort lines unique, Reverse lines, Unique lines, Remove blank
  lines, Trim trailing whitespace, Trim each line, Indent, Dedent, Join lines
  with space, Join lines with ", ", Split by comma, Split by whitespace,
  Unwrap lines (undo terminal hard wraps, keeping paragraphs, lists and code
  blocks; made for pasting Claude Code output into Slack).
- **CLI**: Split command (one flag per line with ` \` continuations), Join
  command, Comment lines, Uncomment lines.
- **Time**: Epoch ↔ ISO 8601.
- **Math**: Calculate (`3+4` → `3+4 = 7`, one expression per line,
  `+ - * / %`, `pow`, `sqrt`, `min`, `max`, `round`, `pi`).

A transformer that cannot handle the text reports why in the banner and
leaves the text alone.

## Take to Scrapbench

Select text in any app, right-click → Services → **Take to Scrapbench**: the
text lands at the end of your file on its own line, under a fresh
separator if the panel was hidden. Assign it a global shortcut in
System Settings → Keyboard → Keyboard Shortcuts → Services → Text.
The service appears once the app has been launched from `/Applications`.

Design: `docs/superpowers/specs/2026-10-26-daily-notes-design.md`.

## Author

Sergey Nosenko, `sergey@nosenko.org`, [github.com/darknos](https://github.com/darknos).
Contributions: see `CONTRIBUTING.md`. Security reports: see `SECURITY.md`.

## License

MIT, see `LICENSE`.
