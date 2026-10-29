<p align="center">
  <img src="docs/icon.png" width="128" alt="">
</p>
<h1 align="center">Scrapbench</h1>
<p align="center">Scraps of text. A bench to work them on.</p>

A workbench for text scraps in the macOS menu bar: one plain-text file, a
floating editor with syntax highlighting, a timestamped separator per session. Press the hotkey, paste, split, fix that long command
line, jot the thought, press `Esc` — saved and hidden. Your own transformers are
scripts, AI rewrites and translations included.

![Paste a command, split it; paste JSON, pretty-print it; epoch, calculator; then Corporate style through the Claude Code CLI while typing goes on, URL decode and Base64 under it: each scrap under its own timestamp](docs/demo.gif)

## Install

```sh
brew trust darknos/scrapbench      # Homebrew asks this once for third-party taps
brew install darknos/scrapbench/scrapbench
```

Or download `Scrapbench-<version>.dmg` from the
[latest release](https://github.com/darknos/scrapbench/releases/latest) and drag
`Scrapbench.app` into `Applications` (a `.zip` is there too). Releases are signed
with a Developer ID and notarized. macOS 14 or later.

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

### Your own transformers, AI included

Drop an executable file into
`~/Library/Application Support/Scrapbench/Transformers/`. Text comes in
on stdin, the result goes out on stdout, a `# @name` comment on top gives
it a name. Press `⌘K`: it is in the list, next to the built-ins.

An AI tool is simpler still: a `.prompt` file with the same header and the
prompt below it. Put your own Anthropic key in Settings → AI, or point it
at Ollama, LM Studio, OpenRouter or OpenAI; the scrap goes to the model and
the answer replaces it.

Scripts run without blocking the editor, so a round trip to an AI model
fits in. `Examples/transformers/` has these ready to copy, as `.prompt` files and as
scripts through the Claude Code CLI:

- **Improve text**: fix mistakes, keep tone and language
- **Translate to English**: same file, another prompt; change the language once to get Bulgarian or German
- **Corporate style**: fixes the text, makes it fit for the whole company and translates it to English, whatever mood it was written in
- **Summarize**: three sentences, same language, on Haiku
- **JSON pretty (jq)**: any shell tool works the same way

Select a paragraph, `⌘K`, `impr`, `Enter`, keep typing. The result lands
when it is ready: in place if the text is still there, as a new scrap
below if you moved on. Details in [docs/transformers.md](docs/transformers.md).

Add `# @service` to a script or prompt and press `Register` in Settings: it
also appears as `Scrapbench: <name>` in the Services menu of every app and
replaces the selection there, with a shortcut of its own from System
Settings → Keyboard → Keyboard Shortcuts → Services.

## Take to Scrapbench

Select text in any app, right-click → Services → **Take to Scrapbench**: the
text lands at the end of your file on its own line, under a fresh
separator if the panel was hidden. Assign it a global shortcut in
System Settings → Keyboard → Keyboard Shortcuts → Services → Text.
The service appears once the app has been launched from `/Applications`.

Design: `docs/specs/2026-10-26-daily-notes-design.md`.

## Author

Sergey Nosenko, `sergey@nosenko.org`, [github.com/darknos](https://github.com/darknos).
Contributions: see `CONTRIBUTING.md`. Security reports: see `SECURITY.md`.

## License

MIT, see `LICENSE`.
