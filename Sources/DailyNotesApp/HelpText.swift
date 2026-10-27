/// Shown in the help window through the regular editor, so every example
/// below is highlighted exactly as it would be in the notes file.
enum HelpText {
    static let markdown = """
    # DailyNotes Help

    ## Keys

    - `⌃⌥Space` show or hide the panel (change it in Settings)
    - `Esc` save and hide; the window close button does the same
    - `⌘N` new timestamped entry at the end
    - `⌘S` save now (autosave runs 2 s after you stop typing)
    - `⌘⌥A` select the current entry (text between separators)
    - `⌘F` find, `⌘G` / `⇧⌘G` next / previous match
    - `⌘Z` / `⇧⌘Z` undo / redo
    - `⌘,` settings
    - `⌘Q` quit

    Clicking outside leaves the panel open and saves pending edits.
    Pasting always inserts plain text.

    ## Entries

    Each time the panel opens, a separator with the current time is appended
    and the cursor goes below it:

    --------------------< 2026-10-27 09:30 >--------------------

    `⌘N` adds another one. Separators left empty are removed on close.

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

    Notes: ~/Documents/daily-notes.md, changeable in Settings.
    Backups: ~/Library/Application Support/DailyNotes/backups/, one per day, 7 kept.
    If the file changed on disk while the panel was open, your text is written
    to <name>.conflict-<timestamp>.md next to it instead of overwriting.
    """
}
