# Header and in-panel palette

Status: implemented 2026-10-28. Deviation: on open the status shows the file's modification time, not the open time. Supersedes the "Palette" section of
`2026-10-27-transformers-design.md` and extends the `BenchPanel` entry in
`2026-10-26-daily-notes-design.md`. Everything about transformers themselves
(target, interface, built-ins, applying, errors) stays as specified there.

## Goal

The panel gets a header strip like Notes or VS Code: a place for the file
name, the save status and the transformer control. The palette stops being a
separate child window and becomes a quick pick inside the panel, dropping
from the header like the VS Code command palette. Two things the earlier
design lost are restored: the last applied transformer is always on top, and
`⌘K` inside the open palette applies it.

## Header

- A `HeaderView` of fixed height 52 pt sits at the top of the panel's content
  stack, above the banner and the editor. The panel keeps `.titled` with
  `titleVisibility = .hidden`, `titlebarAppearsTransparent = true` and
  `.fullSizeContentView`, so the system close button stays and the header
  draws under it. The header is part of the window background, so the panel
  is still draggable by it.
- Left: the file name (`lastPathComponent`) in the editor font, semibold;
  under it, in a smaller secondary colour, the save status: `saved HH:mm`
  after a successful save, `editing` while there are unsaved edits, `read-only`
  when the load failed. `SessionController` pushes these; the header holds no
  logic.
- Right: the transformer control, a capsule button `Transform  ⌘K`. Clicking
  it does what `⌘K` does. While the palette is open the button draws as
  pressed.
- Fonts are monospace, emphasis by weight and colour only (brand rule).
- `minSize` grows by the header height. The editor's `bottomPadding` and
  `centerEnd` are unaffected: they work on the scroll view, which does not
  change.

## Palette (quick pick)

- `⌘K` in the editor (keyCode 40), the header button and the hidden menu item
  resolve the target as before (selection, else the current scrap, selected
  in place; empty target → banner `Nothing to transform`, nothing opens).
- The palette is a `PaletteView` added to the panel's content view, over the
  editor, dropping from the top edge of the panel over the header (VS Code
style), horizontally centred, width
  60 % of the panel and at least 420 pt. Rounded corners, a hairline border,
  a shadow. It is not a window: no `resignKey` games.
- Layout: a text field on top (placeholder `Transform…`), a hairline, then
  the list. Row height 24 pt. Each row has the name on the left and a
  right-aligned column reserved for a shortcut, empty in this version (the
  future per-transformer shortcuts render there). Group headers are a small
  secondary-colour label with a hairline above, VS Code style. The list
  shows at most 8 rows and scrolls beyond that; the view is only as tall as
  its rows.
- Content: transformers whose `canApply` holds for the target.
  - Empty query: first a `Recent` section with the last applied transformer
    if it applies to this target, highlighted; then the groups in registry
    order (the last one also stays in its group).
  - Non-empty query: a flat list ranked by `FuzzyMatcher`; on equal score
    the last applied transformer wins. No group headers.
  - Nothing applies: one disabled row `No transformers apply to this text`.
- Keys while the field has focus: `↑`/`↓` move the highlight, `Enter` and a
  click apply the highlighted row, `Esc` closes without applying and
  collapses the selection to a caret at its end, so typing continues after
  the scrap instead of replacing it. `⌘K`
  applies the last transformer if it is in the list, else does nothing.
  `⌘⇧K` is unchanged (repeat without opening). Typing filters.
- Closing (any reason) hides the view, restores the header button and
  returns first responder to the editor; except after `Esc`, the selection
  made for the target stays. The palette also closes when the user clicks anywhere in the panel
  outside it, and when the panel loses key status.
- The last applied transformer id is stored in `UserDefaults`
  (`lastTransformer`), so it survives relaunches. It is set only after a
  successful apply.

## Code

- `CommandPalette` (an `NSPanel`) is replaced by `PaletteView` (`NSView`) and
  `PaletteController`, which owns the view, the field delegate, the table
  data source and the open/close transitions. Row building and matching move
  over unchanged; the `Recent` section and the tie-break are the additions.
- `HeaderView` is a plain `NSView` with two labels and one button; it exposes
  `fileName`, `status` and `isPaletteOpen` setters and an `onTransform`
  callback.
- `TransformController` gets `lastID` from `UserDefaults`, exposes
  `last: (any Transformer)?` for the palette, and calls
  `paletteController.open(items:)` instead of creating a window.
- `BenchPanel` builds header + banner + scroll in the stack and hosts the
  palette view; it tells the palette controller about `resignKey` and
  forwards `mouseDown` outside the palette.
- `SessionController` updates the header on load, after every save, on
  `textDidChange` and when a load fails.

## Out of scope

Per-transformer shortcuts (the column is reserved only), a `Recent` list
longer than one entry, palette search across groups or descriptions.

## Testing

Core is untouched; existing tests stay green. Manual, on the built app:
open the palette by `⌘K`, by the button and from the menu; pick with keys
and with the mouse; `Esc`; `⌘K` twice applies the last; `⌘⇧K` still works;
click into the editor with the palette open; switch to another app with the
palette open; resize the panel with the palette open (it stays centred and
within the panel); light and dark; the header status flips `editing` →
`saved HH:mm` two seconds after typing; relaunch keeps the last transformer
on top. `Scripts/record-demo.sh` still records (it only sends `⌘K`, text,
`Enter`).

## Documentation

README: `⌘K` row mentions the header button; Help: one line about the
header and `⌘K ⌘K`. CLAUDE.md: `CommandPalette` entry replaced by
`PaletteController` / `HeaderView`.
