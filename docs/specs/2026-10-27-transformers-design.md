# Text Transformers — Design

Companion to `2026-10-26-daily-notes-design.md`. Adds a set of built-in text
transformers and a command palette to run them. External plugins are out of
scope here; the `Transformer` interface is shaped so that a plugin can
implement it later without changing the palette or the editor glue.

## Goal

The target user edits plain text: assembles pieces from the clipboard, splits
long lines, fixes a CLI command before running it. A transformer takes the
text the user is working on and replaces it with a derived version in one
undoable step. The palette shows only transformers that make sense for that
text.

## Target text

1. If there is a non-empty selection, the target is the selection.
2. Otherwise the target is the current scrap: the text between separators
   around the cursor, as `Separator.scrap(containing:in:)` returns it (the
   same range `⌘⌥A` selects). The editor selects that range before applying,
   so the user sees what was transformed.
3. If the target is empty, the palette does not open; the banner shows
   `Nothing to transform`.

## Transformer interface (`ScrapbenchCore/Transformers/`)

```swift
public protocol Transformer {
    var id: String { get }              // stable, e.g. "base64.decode"
    var name: String { get }            // palette label, e.g. "Base64 decode"
    var group: TransformerGroup { get } // .case, .encoding, .lines, .cli, .time, .math
    func canApply(to text: String) -> Bool
    func apply(_ text: String) throws -> String
}

public struct TransformError: Error { public let message: String }
```

- `canApply` is a cheap check (regex, line count, a parse for small input).
  For input over 1 MB it returns `true` for transformers whose check would
  parse the whole text; `apply` then reports the error if any.
- `apply` is pure. It throws `TransformError` with a short message that the
  banner shows verbatim, prefixed by the transformer name:
  `JSON pretty: unexpected token at 3:14`.
- `TransformerRegistry.builtIn: [Transformer]` lists all built-ins in palette
  order (by group, then as listed below).
- Line-based transformers treat the input as lines split on `\n`. A trailing
  newline in the input is preserved in the output; none is added otherwise.
  `\r\n` is normalised to `\n` on output.

## Built-in transformers

### Case and identifiers (`.case`)

| id | name | canApply | apply |
|---|---|---|---|
| `case.upper` | UPPER CASE | always | `uppercased()` |
| `case.lower` | lower case | always | `lowercased()` |
| `case.title` | Title Case | always | first letter of each whitespace-separated word upper, rest unchanged |
| `case.camel` | camelCase | always | identifier conversion, per line |
| `case.snake` | snake_case | always | identifier conversion, per line |
| `case.kebab` | kebab-case | always | identifier conversion, per line |
| `case.constant` | CONSTANT_CASE | always | identifier conversion, per line |

Identifier conversion splits each line into words on `_`, `-`, whitespace,
lower→upper boundaries (`fooBar` → `foo`, `bar`) and acronym boundaries
(`HTTPServer` → `http`, `server`), lowercases them, then joins in the target
style. Leading and trailing whitespace of the line is kept.

### Encoding (`.encoding`)

| id | name | canApply | apply / errors |
|---|---|---|---|
| `base64.encode` | Base64 encode | always | UTF-8 bytes, standard alphabet, no line breaks |
| `base64.decode` | Base64 decode | decodes (whitespace ignored, missing padding tolerated) and result is UTF-8 | error `not valid Base64` or `decoded bytes are not UTF-8 text` |
| `url.encode` | URL encode | always | percent-encode everything except `A-Za-z0-9-._~` |
| `url.decode` | URL decode | contains `%XX` | decode `%XX` only (`+` is left alone); error `invalid percent escape` |
| `json.escape` | JSON string escape | always | wrap in `"…"` with JSON escapes |
| `json.unescape` | JSON string unescape | trimmed text starts and ends with `"` and parses as a JSON string | error `not a JSON string literal` |

### JSON and lines (`.lines`)

| id | name | canApply | apply |
|---|---|---|---|
| `json.pretty` | JSON pretty | parses as JSON | 2-space indent, key order and number literals preserved verbatim |
| `json.minify` | JSON minify | parses as JSON | whitespace outside strings removed |
| `lines.sort` | Sort lines | more than one line | stable, byte-wise `<` |
| `lines.sortUnique` | Sort lines unique | more than one line | sort then drop duplicates |
| `lines.reverse` | Reverse lines | more than one line | |
| `lines.unique` | Unique lines | more than one line | keep first occurrence, order kept |
| `lines.removeBlank` | Remove blank lines | has a whitespace-only line | |
| `lines.trimTrailing` | Trim trailing whitespace | some line has trailing whitespace | |
| `lines.trim` | Trim each line | some line has leading or trailing whitespace | |
| `lines.indent` | Indent | always | prefix non-empty lines with 4 spaces, or a tab if any line already starts with a tab |
| `lines.dedent` | Dedent | every non-empty line starts with whitespace | remove the common leading whitespace |
| `lines.joinSpace` | Join lines with space | more than one line | trim lines, join with `" "` |
| `lines.joinComma` | Join lines with ", " | more than one line | trim lines, join with `", "` |
| `lines.splitComma` | Split by comma | contains `,` | split on `,`, trim parts, one per line |
| `lines.splitSpace` | Split by whitespace | one line containing whitespace | split on whitespace runs, one per line |

JSON pretty/minify use a token-level reformatter in Core, not
`JSONSerialization`: it validates syntax and reports `unexpected token at
line:column`, and it never reorders keys or rewrites numbers.

### CLI (`.cli`)

| id | name | canApply | apply |
|---|---|---|---|
| `cli.split` | Split command | one line containing whitespace | see below |
| `cli.join` | Join command | more than one line | strip trailing `\`, trim, join with one space |
| `cli.comment` | Comment lines | some non-empty line does not start with `#` | prefix each non-empty line with `# ` |
| `cli.uncomment` | Uncomment lines | every non-empty line starts with `#` | remove leading `#` and one following space |

Split command tokenises on whitespace outside single and double quotes
(quotes are kept as written). The first line holds the command and its
leading non-flag arguments. Every token starting with `-` begins a new line;
tokens that follow a flag and do not start with `-` stay on that flag's line
(`--out file`, `-o file`). `|`, `||`, `&&`, `;` begin a new line and keep
their following command on it. All lines except the last end with ` \`;
continuation lines are indented two spaces.

```
docker run --rm -it -v "$PWD:/src" -w /src node:20 npm test
```
becomes
```
docker run \
  --rm \
  -it \
  -v "$PWD:/src" \
  -w /src node:20 npm test
```

### Time (`.time`)

| id | name | canApply | apply |
|---|---|---|---|
| `time.epochIso` | Epoch ↔ ISO 8601 | trimmed text is 10 or 13 digits, or parses as ISO 8601 | digits → `2026-10-27T18:52:00Z` (13 digits keep `.mmm`); ISO → epoch seconds |

### Math (`.math`)

| id | name | canApply | apply |
|---|---|---|---|
| `calc.evaluate` | Calculate | every non-blank line is an arithmetic expression (see below) and at least one contains an operator | per line: `3+4` → `3+4 = 7`; a line that already has ` = <result>` gets the result recomputed |

Calculate evaluates with the `Expression` package (nicklockwood/Expression,
MIT, the second dependency after `KeyboardShortcuts`), wrapped in Core as
`Calculator` so the transformer and its tests do not touch the library
directly. Supported: decimal numbers, `+ - * / %`, unary minus, parentheses,
and the library's `sqrt`, `abs`, `round`, `floor`, `ceil`, `min`, `max`,
`pow`, `pi`. There is no `^`: the library cannot give a custom operator
power precedence, so `pow(x, y)` is the way. Results are `Double`;
`Calculator` formats them: integers without a fraction, others with up to
10 significant digits and no trailing zeros (`10/4` → `2.5`, `1/3` →
`0.3333333333`). An infinite result reports `division by zero`, NaN reports
`not a number`; syntax errors pass the library's message through.
`canApply` evaluates every non-blank line and succeeds (evaluation is pure
and cheap). Blank lines are kept as they are. No variables, no assignment,
no units: that is a plugin's job.

## Palette (`ScrapbenchApp/CommandPalette.swift`)

- `⌘K` in the editor (keyCode 40, so it works under any layout) resolves the
  target text, selects it, and opens the palette. `⌘K` is also in the hidden
  main menu and listed in Help.
- The palette is a borderless child window of the bench panel, 480×360,
  anchored at the top centre of the panel. A search field on top, a list
  below. Nothing else.
- The list holds only transformers whose `canApply` is true for the target,
  grouped with small group headers, in registry order. An empty query shows
  all of them.
- Filtering is fuzzy subsequence matching on `name`, case-insensitive,
  ranked by match tightness (consecutive characters and word starts score
  higher). `FuzzyMatcher` lives in Core and is unit-tested.
- `↑`/`↓` move the highlight, `Enter` applies the highlighted transformer,
  `Esc` closes the palette and leaves the editor and its selection as they
  were. Clicking a row applies it. Losing key status closes the palette.
- If no transformer applies, the list shows one disabled row:
  `No transformers apply to this text`.
- `⌘⇧K` repeats the last applied transformer on the current target without
  opening the palette (the id is kept in memory for the session). If there
  is none yet, or it does not apply to the target, it opens the palette
  instead.

Per-transformer shortcuts are not in this version. When they come, they are
a user setting mapping transformer id → key combination (shown in the
palette next to the name), handled in the editor's `keyDown` like `⌘K`;
nothing in the protocol or the palette needs to change for that.

## Applying

- The editor replaces the target range with the result through
  `shouldChangeText(in:replacementString:)` / `replaceCharacters` /
  `didChangeText`, so it is one undo step and highlighting shifts as for any
  edit. The result becomes the new selection.
- A result equal to the input changes nothing and shows no banner.
- On `TransformError` the text and selection stay untouched and the banner
  shows `<name>: <message>`.
- Transform banners auto-hide after 4 s or on the next key press. Save
  banners keep today's behaviour (stay until the next successful save).

## Testing

- One test suite per group in `Tests/ScrapbenchCoreTests/Transformers/`:
  every transformer has `canApply` positive and negative cases, an `apply`
  example, and an error case where it can fail. Trailing newline
  preservation and CRLF normalisation are tested once per line-based group.
- `JSONFormatterTests`: nested objects/arrays, strings with escapes and
  braces inside, numbers verbatim (`1e3`, `-0.50`), error position.
- `CommandSplitterTests`: quotes with spaces, flag/value pairing, pipes,
  round trip split → join.
- `FuzzyMatcherTests`: ranking and no-match.
- The palette itself is checked by running the app.

## Documentation

README gets a `⌘K` row and a Transformers section listing the built-ins;
Help text gets the same list in short form; CLAUDE.md gets the
`Transformers/` directory and the "canApply is cheap, apply throws" rule.
