# Service transformers

Status: designed 2026-10-28. Extends `2026-10-28-script-transformers-design.md`:
the script file, its header and the way the app runs it stay as specified
there.

## Goal

A script transformer can also work outside the bench, as a macOS Service:
select text in any app, pick `Scrapbench: Improve text` from the Services
menu (or press the shortcut assigned to it in System Settings → Keyboard →
Keyboard Shortcuts → Services), and the selection is replaced with the
script's output. That is what people run today as Automator workflows; now
the same file serves both the palette and the Services menu.

`NSServices` entries are static in an app's `Info.plist`, so the app cannot
offer one service per user script itself. Instead it writes one Automator
workflow bundle per script into `~/Library/Services/`, on demand, from a
button in Settings. Nothing runs in the background and nothing is kept in
sync automatically: a user who adds `@service` to a script presses the
button once.

## Header

A new header key, `@service`. Its presence marks the script; a value, if
any, is ignored. `ScriptHeader` and `ScriptTransformer` gain
`service: Bool`. Nothing else about the script changes: the same file is
offered in the palette as before.

```bash
#!/bin/bash
# @name Improve text
# @group AI
# @service
# @timeout 60
```

## The workflow bundle

For a script `improve-text.sh` with `@name Improve text` the app writes
`~/Library/Services/Scrapbench - Improve text.workflow/Contents/` with two
files. (The menu title has a colon; the file name has a dash because Finder
shows a colon in a file name as a slash.)

`Info.plist`:

- `NSServices`: one entry, `NSMenuItem.default = "Scrapbench: Improve text"`,
  `NSMessage = runWorkflowAsService`, `NSSendTypes` and `NSReturnTypes` both
  `public.utf8-plain-text`, `NSIconName = NSActionTemplate`,
  `NSBackgroundColorName = background`. These are the keys Automator writes
  for a "replace selected text" service.
- `ScrapbenchScriptID`: the transformer id (`script.improve-text`). This key
  is how the app tells its own bundles from the user's; a bundle without it
  is never touched.
- `ScrapbenchScriptPath`: the script's absolute path, for people reading
  the bundle.

`document.wflow`: one `Run Shell Script` action
(`/System/Library/Automator/Run Shell Script.action`, bundle
`com.apple.RunShellScript`, class `RunShellScriptAction`), shell `/bin/sh`,
`inputMethod 0` (stdin), accepting and providing `com.apple.cocoa.string`,
with `workflowMetaData` of type `com.apple.Automator.servicesMenu`, input
and output `com.apple.Automator.text`. The command:

```sh
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export LANG=en_US.UTF-8
exec '/Users/me/Library/Application Support/Scrapbench/Transformers/improve-text.sh'
```

The path is single-quoted, with `'` inside it written as `'\''`. `HOME` and
`USER` come from Automator. Differences from running inside the bench, all
documented:

- No `SCRAPBENCH_FILE`.
- No timeout; Automator waits for the script.
- A non-zero exit shows Automator's own error dialog and leaves the
  selection as it was. Empty output replaces the selection with nothing,
  as any Automator text service does.
- The script runs even when Scrapbench is not running; the bundle holds the
  script's path, so a moved transformers folder needs `Register services`
  again.

A workflow the user made by hand with the same purpose (`Improve
Text.workflow`) is a different bundle with no `ScrapbenchScriptID`; it stays
and shows next to ours in the menu.

## Register services and Remove all services

Core computes a `ServicePlan` from two lists: the scripts in the
transformers folder that have `@service` (the regular `ScriptRegistry.scan`,
problems excluded) and the bundles in `~/Library/Services/` that carry
`ScrapbenchScriptID`, keyed by that id.

- `add`: the script has `@service`, no bundle with its id.
- `refresh`: both exist. The bundle is rewritten without comparing; the
  title and the path follow the script.
- `remove`: a bundle with our key whose id has no script with `@service`
  any more (key removed, file deleted, file renamed).

`Register services` performs the whole plan: writes every `add` and
`refresh` bundle (a `refresh` whose title changed is written under the new
folder name and the old folder is removed), removes every `remove` bundle,
then calls `NSUpdateDynamicServices()` so the Services menu picks the change
up without a logout. `Remove all services` deletes every bundle with our
key and calls `NSUpdateDynamicServices()` too.

A keyboard shortcut assigned in System Settings is tied to the service's
title, so a `refresh` with the same `@name` keeps it; a renamed script needs
the shortcut assigned again.

## Settings

The Transformers section gains two rows under `Open transformers folder`:

- A status line and the `Register services` button. The line reads
  `Services: add 2, refresh 1, remove 1` (only the non-zero parts; `refresh
  3` when nothing else changes) or `No scripts with @service` when the plan
  is empty and nothing of ours is installed, in which case the button is
  disabled. The plan is computed when the window opens and after each
  press.
- `Remove all services`, titled `Remove 3 services` when something is
  installed, disabled at zero.
- A failure (a bundle that cannot be written or removed) is shown as a red
  caption under the rows, like the launch-at-login error, with the bundle
  name and the system message.

## Core and app

Core, `ScrapbenchCore/Transformers/Scripts/Services/` (pure Foundation,
unit-tested):

- `ServiceWorkflow`: `init(script: ScriptTransformer)`; `title`
  (`Scrapbench: <name>`), `bundleName` (`Scrapbench - <name>.workflow`, with
  `/` and `:` in the name replaced by `-`), `command`, `infoPlist` and
  `document` as `[String: Any]` ready for `PropertyListSerialization`.
  `static let scriptIDKey = "ScrapbenchScriptID"`, `scriptPathKey`.
- `InstalledService`: `id`, `url` (the bundle folder).
- `ServicePlan`: `init(scripts: [ScriptTransformer], installed: [InstalledService])`;
  `add`, `refresh` (pairs of script and installed bundle), `remove`,
  `isEmpty`, `summary` (the status line text without the `Services: `
  prefix).

App:

- `ServiceInstaller` (`Sources/ScrapbenchApp/ServiceInstaller.swift`):
  `servicesDirectory` (`~/Library/Services`), `installed()` reads every
  `.workflow` there and keeps those whose `Info.plist` has our key,
  `plan()` combines it with `ScriptRegistry.scan`, `register(plan)` and
  `removeAll()` write and delete bundles and call `NSUpdateDynamicServices()`.
  Errors carry the bundle name.
- `SettingsView`: the two rows, state refreshed on appear and after each
  action.

## Documentation

- `docs/transformers.md`: `@service` in the key table and a section
  "As a macOS Service" with the button, the shortcut path in System
  Settings and the four differences listed above.
- `Examples/transformers/improve-text.sh` gets `# @service`.
- README: one paragraph in Transformers.
- CLAUDE.md: the `Services/` folder in Core, `ServiceInstaller`, and the
  rule that only bundles with `ScrapbenchScriptID` are ever touched.

## Testing

- `ServiceWorkflowTests`: title and bundle name (plain, with `/` and `:`),
  the command for a path with a space and a single quote, the plist keys
  listed above, `PropertyListSerialization` accepts both dictionaries.
- `ServicePlanTests`: add / refresh / remove for each combination, empty
  plan, summary strings.
- Manual: Register with two `@service` scripts, run one on a selection in
  TextEdit, rename a `@name`, register again (old bundle gone, new title),
  remove `@service`, register (bundle gone), Remove all.

## Not in this version

- Keeping the bundles in sync automatically on each palette scan.
- A custom title through `@service <title>`.
- A timeout or `SCRAPBENCH_FILE` inside the service.
