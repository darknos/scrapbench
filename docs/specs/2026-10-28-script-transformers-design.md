# Script transformers

Status: implemented 2026-10-28. Extends `2026-10-27-transformers-design.md`
(target, interface, applying, errors stay as specified there) and the palette
in `2026-10-28-header-and-palette-design.md`.

## Goal

Users add their own transformers without rebuilding the app: one executable
file per transformer in a folder, text on stdin, result on stdout. The first
use case is AI tools through `claude -p` (improve text, translate, corporate
style), the kind of thing people run today as Automator services. The
contract is not tied to AI: `jq`, `sort -u` or a Python script work the same
way. Scripts appear in the same palette as the built-ins, take part in
Recent and `⌘K⌘K`, and will get per-transformer shortcuts later without any
change to the format.

Scripts can take seconds (an AI call takes 5–20 s), so they run without
blocking the editor and their result is applied when it arrives.

## Script file

- Folder: `~/Library/Application Support/Scrapbench/Transformers/`. The app
  creates it on first launch. Settings gets an `Open transformers folder`
  button.
- Every executable regular file directly in the folder is one transformer.
  No recursion; names starting with `.` are ignored.
- The header is read from the first 20 lines. A header line is a comment
  line (`#`, `//` or `--` after optional whitespace) whose first word is
  `@name`, `@group`, `@description` or `@timeout`; the rest of the line,
  trimmed, is the value. Other lines are ignored, so the shebang and any
  prose stay where they are.

```bash
#!/bin/bash
# @name Improve text
# @group AI
# @description Fixes mistakes, keeps tone and language
# @timeout 60

PROMPT='The user message is a piece of text to process. ...'
claude -p --model sonnet --tools "" --system-prompt "$PROMPT"
```

| key | required | default | notes |
|---|---|---|---|
| `@name` | yes | | palette label |
| `@group` | no | `Scripts` | palette group header |
| `@description` | no | empty | shown dimmed on the right of the palette row |
| `@timeout` | no | `30` | seconds, positive integer |

- `id` is `script.<file name without extension>`: stable across edits of
  the file, used by Recent and, later, by shortcuts. Two files with the same
  stem (`improve.sh`, `improve.py`) are a problem; the first in byte order
  wins and the other is reported.
- Script groups come after the built-in groups, alphabetically by group
  name; inside a group, by file name.
- `canApply` is always true. A `@match <regex>` key is the planned way to
  narrow that; not in this version.

### Problems

A file is skipped and reported when it has no `@name`, is not executable, has
a malformed `@timeout`, or its stem collides with an earlier file. Problems
are shown once per palette open as a flash banner:
`2 scripts skipped: improve.sh (no @name), x.py (not executable)`. The app
never modifies the files (no `chmod +x` on the user's behalf).

### Scanning

The folder is scanned every time the palette opens: a directory listing and
one header read per file. No file watcher. Add a file, press `⌘K`, it is
there.

## Running

- Target text goes to stdin as UTF-8, exactly as in the editor (no newline
  added). Stdout, as a whole, is the result; no trailing-newline or CRLF
  normalisation, the script owns its output.
- Exit 0 with non-empty stdout: result. Exit 0 with empty stdout: error
  `empty output`. Non-zero exit: error with the first non-blank line of
  stderr, or `exit code N` when stderr is empty. Errors show as
  `<name>: <message>` in the banner and leave the text untouched.
- Timeout: `SIGTERM`, `SIGKILL` 2 s later, error `timed out after N s`.
- Environment: `HOME`, `USER`, `LANG=en_US.UTF-8`,
  `PATH=~/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin`
  (`~` expanded), `SCRAPBENCH_FILE` with the path of the scrap file. Working
  directory `$HOME`. No login shell: the file is executed directly and its
  shebang picks the interpreter.
- Stdout and stderr are read incrementally (`readabilityHandler`), so large
  output does not fill the pipe and deadlock the child.
- One script at a time. Starting a script while another runs flashes
  `<name> is running` and does nothing. Built-ins keep working meanwhile.
- Quit while a script runs: the child gets `SIGTERM`; the result is not
  awaited.

## Applying asynchronously

When a script starts, the controller remembers the target range and its
text. The header shows `<name>…` in place of the save status; the editor
stays editable, the Transform button works as usual.

When the result arrives:

1. **Panel visible, target text unchanged.** The range is replaced through
   `editor.replace` (one undo step, result selected). The range is kept in
   step with edits made above it while the script ran (the same shift logic
   `HighlightCoordinator` applies to its `IndexSet`); edits inside the range
   count as a change. Autosave runs on its usual timer.
2. **Panel visible, target text changed.** A new scrap is appended
   (`formatter.newScrap` then `ScrapFormatter.append(chunk:)` with the
   result), the result is selected, banner
   `<name>: text changed, result added below`.
3. **Panel hidden** (`Esc` while the script ran; the session closed and the
   file was saved). The result goes the "Take to Scrapbench" way:
   `SessionController.take(text:)` opens the panel and appends the result
   under a fresh separator, selected, with the same banner. The panel is
   non-activating, so the frontmost app keeps focus.
4. **Error or timeout.** Banner only; the header status returns to the save
   status.

The script enters Recent (and becomes the `⌘K⌘K` target) only after a
successful application, like a built-in.

## Core and app

Core (`ScrapbenchCore/Transformers/Scripts/`, pure Foundation, unit-tested):

- `ScriptHeader`: `name`, `group`, `description`, `timeout`;
  `static func parse(_ text: String) -> Result<ScriptHeader, ScriptProblem>`.
- `ScriptProblem`: file name plus a short reason (`no @name`,
  `not executable`, `bad @timeout`, `duplicate id`).
- `ScriptTransformer: Transformer`: `id`, `name`, `group`, `description`,
  `url`, `timeout`. `canApply` returns true; `apply` throws
  `TransformError("runs through the app")`: the palette treats it as any
  row, the app runs it.
- `ScriptRegistry.scan(directory: URL) -> (transformers: [ScriptTransformer], problems: [ScriptProblem])`
  on `FileManager`, ordering as above.
- `TransformerGroup` becomes `struct TransformerGroup: Hashable { let name }`
  with static constants for the built-in groups and a `builtInOrder` list;
  `PaletteRows` groups by `name`.
- `TransformerRegistry.applicable(to:extra:)` takes the scripts as an extra
  list after the built-ins; `transformer(id:)` likewise.

App:

- `ScriptRunner`: `Process` + `Pipe`, environment, timeout, incremental
  reading, completion on the main thread with `Result<String, TransformError>`.
  One instance per run; the controller holds at most one.
- `PendingTransform`: the remembered range and text, shifted on
  `textDidChange`; answers "unchanged?" when the result arrives.
- `TransformController.run` dispatches `ScriptTransformer` to the runner and
  applies the result per the section above; everything else is unchanged.
  `openPalette` scans the folder and reports problems.
- `HeaderView` gets a `running(name:)` status.
- `SessionController` exposes what the controller needs for cases 2 and 3
  (`newScrap`-style append and `take`), nothing more.

## Documentation

- `docs/transformers.md`: how to write a script in five minutes, the
  stdin/stdout/exit/environment contract, the header keys, three complete
  examples: `Improve text` and `Translate to English` through `claude -p`,
  and one with no AI (`jq .`). Linked from the Transformers section of the
  README.
- `Examples/transformers/` holds the same three scripts, ready to copy.
- README: one paragraph in Transformers and the link.
- CLAUDE.md: the `Scripts/` directory, the runner, and the rule that the app
  never modifies script files.

## Testing

- `ScriptHeaderTests`: each comment style, missing `@name`, malformed and
  missing `@timeout`, header lines after line 20 ignored, values trimmed.
- `ScriptRegistryTests` on a temporary folder: executable bit, dot files,
  subfolders skipped, duplicate stems, ordering.
- `PaletteRowsTests` extended for script groups after built-ins.
- The runner and asynchronous application are checked by running the app:
  a script with `sleep 5` and editing meanwhile, `Esc` meanwhile, `exit 1`
  with stderr, a script without `@name`, a timeout.

## Not in this version

- `@match <regex>` to narrow `canApply`.
- Per-transformer shortcuts (the palette reserves the column; applies to
  scripts and built-ins alike).
- Passing the selection and the whole scrap separately.
- A plugin list in Settings beyond the folder button.
