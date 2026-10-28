/// Shown in the help window through the regular editor, so every example
/// below is highlighted exactly as it would be in the scrap file.
enum HelpText {
    static let markdown = """
    # Scrapbench Help

    ## Keys

    - `⌃⌥Space` show or hide the panel (change it in Settings)
    - `Esc` save and hide; the window close button does the same.
      An open ``` fence is closed for you so the next scrap stays outside it.
    - `⌘N` new timestamped scrap at the end
    - `⌘S` save now (autosave runs 2 s after you stop typing)
    - `⌘⌥A` select the current scrap (text between separators)
    - `Tab` / `⇧Tab` indent or outdent the selected lines by one unit (2 spaces by default,
      change it in Settings); `⇧Tab` also works on the current line
    - `⌘⌥W` word wrap on or off; the ↵ button in the header shows the state
    - `⌘K` transform the selection or the current scrap; `⌘K` again applies the last one
    - `⌘⇧K` repeat the last transformer
    - `⌘F` find, `⌘G` / `⇧⌘G` next / previous match
    - `⌘Z` / `⇧⌘Z` undo / redo
    - `⌘,` settings
    - `⌘Q` quit

    Clicking outside leaves the panel open and saves pending edits.
    Pasting always inserts plain text.

    ## Take to Scrapbench

    Select text in any app, right-click → Services → Take to Scrapbench.
    It lands at the end of the file on its own line. Give the service a
    global shortcut in System Settings → Keyboard → Keyboard Shortcuts →
    Services.

    ## Scraps

    Each time the panel opens, a separator with the current time is appended
    and the cursor goes below it:

    --------------------< 2026-10-27 09:30 >--------------------

    `⌘N` adds another one. Separators left empty are removed on close.

    ## Transformers

    The header shows the file and whether it is saved. `⌘K` or its button
    opens a palette over the selection, or over the current scrap when
    nothing is selected. Only transformers that apply to that text are
    listed; type to filter, `Enter` applies as one undo step, `Esc` closes.

    - Case: UPPER, lower, Title, camelCase, snake_case, kebab-case, CONSTANT_CASE
    - Encoding: Base64, URL, JSON string escape, each way
    - Lines: JSON pretty / minify, sort, unique, reverse, remove blank, trim,
      indent / dedent, join / split, unwrap terminal hard wraps
    - CLI: split a command one flag per line, join it back, comment / uncomment
    - Time: Epoch ↔ ISO 8601
    - Math: Calculate (`3+4` → `3+4 = 7`)

    ## Markdown

    Highlighting only; the file stays plain text.

    # Heading (1 to 6 hashes)
    **bold** and *italic*
    `inline code`
    > quote
    - list item, also * item, + item, 1. item
    - [ ] open task
    - [x] done task
    [link text](https://example.com) and bare https://example.com

    Fenced code blocks are highlighted by language:

    ```go
    func main() { fmt.Println("hi") } // comment
    ```

    ```json
    {"id": 42, "ok": true, "name": null}
    ```

    Languages: json, yaml, sql, bash / sh / zsh, go, js / ts, xml / html.
    Any other language, or none, gets the block background only.

    ## Files

    File: ~/Documents/scrapbench.md, changeable in Settings.
    Appearance follows macOS; Settings can pin it to light or dark.
    Backups: ~/Library/Application Support/Scrapbench/backups/, one per day, 7 kept.
    If the file changed on disk while the panel was open, your text is written
    to <name>.conflict-<timestamp>.md next to it instead of overwriting.
    """
}
