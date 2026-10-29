# Prompt transformers

Status: implemented 2026-10-29. Extends `2026-10-28-script-transformers-design.md`
(the folder, the header format, the asynchronous application of a result and
the one-at-a-time rule stay as specified there) and
`2026-10-28-service-transformers-design.md`.

## Goal

Today an AI transformer is a shell script that pipes the text through
`claude -p`. That needs a CLI on the machine, a login, a login shell's
`PATH`, and it does not survive the App Store sandbox, which is where the
app is heading: a sandboxed app cannot run user scripts or register
Automator services. The API call itself is small (one system prompt, one
user message, one text answer), faster than spawning a CLI, and costs a
fraction of a cent per scrap.

So a third kind of transformer: a `.prompt` file in the transformers folder.
The header is the same `# @key value` block as a script; the body is the
system prompt. The app sends the target text to the configured provider and
applies the answer exactly as it applies a script's stdout. Prompts take
part in the palette, Recent and `⌘K⌘K`; a prompt file needs no executable
bit and no interpreter.

Two providers, no plugin system: `Anthropic` (Messages API) and `Other
server` (any Chat Completions server: Ollama, LM Studio, OpenRouter,
OpenAI). Keys are the user's own; the app has no key of its own and no
account. There is no `ANTHROPIC_API_KEY` fallback: a sandboxed app sees no
environment, and a key typed once into Settings is the same effort.

## Prompt file

- Folder: the transformers folder, `~/Library/Application Support/Scrapbench/Transformers/`,
  scanned by `ScriptRegistry.scan` on every palette open together with the
  scripts. No recursion, dot files ignored, symlinks as for scripts.
- Every regular file with the extension `.prompt` is a prompt transformer,
  executable or not. Other files keep the script rules (`not executable` is
  still a problem for them).
- The header is read as for scripts: the first 20 lines, `# @key value`
  (also `//` and `--`). The body is the file with the header lines removed,
  trimmed of leading and trailing blank lines. Other lines inside the first
  20 (a Markdown heading, prose) stay in the body: only lines that parse as
  `@key` comments are dropped.

```text
# @name Improve text
# @group AI
# @description fixes mistakes, keeps tone and language
# @model claude-sonnet-5-5
# @effort low

The user message is a piece of text to process. Fix spelling, grammar and
punctuation. Keep the language, the tone, the formatting and the line
breaks. Return only the corrected text, nothing else.
```

| key | required | default | notes |
|---|---|---|---|
| `@name` | yes | | palette label |
| `@group` | no | `AI` | palette group (scripts default to `Scripts`) |
| `@description` | no | empty | dimmed text on the right of the row |
| `@timeout` | no | `60` | seconds, positive integer (scripts default to `30`) |
| `@model` | no | the model in Settings | free text, passed as is |
| `@provider` | no | the provider in Settings | `anthropic` or `other` |
| `@effort` | no | `low` | `low`, `medium`, `high`, `xhigh`, `max`; Anthropic only |
| `@service` | no | | also offer as a macOS Service (Developer ID build only) |

- `id` is `prompt.<file name without extension>`, so `improve.prompt` and
  `improve.sh` coexist (`prompt.improve`, `script.improve`); two `.prompt`
  files cannot share a stem.
- Prompt groups sort with the script groups, after the built-ins:
  alphabetically by group name, then by file name. `AI` prompts and `AI`
  scripts share one group.
- `canApply` is always true, as for scripts.

### Problems

A `.prompt` file is skipped and reported, in the same banner as script
problems (`2 transformers skipped: …`), when it has no `@name`, an empty
body (`empty prompt`), a malformed `@timeout`, an unknown `@provider`
(`bad @provider`) or `@effort` (`bad @effort`), or its stem collides with
an earlier `.prompt` file. `@model`, `@provider` and `@effort` are parsed
for every file and ignored by scripts.

## Settings → AI

A fourth tab. Everything on it is per provider; switching the picker shows
that provider's fields and keeps the other's values.

- `Provider`: `Anthropic` | `Other server`. Under `Other server` a caption:
  `Chat Completions API: Ollama, LM Studio, OpenRouter, OpenAI`.
- `API key`: a secure field. Once a key is stored the field is empty and a
  caption shows `Key ends in …a1b2`; typing replaces the key, a `Remove`
  button deletes it. Keys live in the Keychain (generic password, service
  `org.nosenko.Scrapbench`, account `anthropic` or `other`), never in
  `UserDefaults`. For `Other server` the key is optional: Ollama and LM
  Studio take none.
- `Model`: for Anthropic a picker, `Claude Opus 5.5` (default,
  `claude-opus-5-5`), `Claude Sonnet 5.5` (`claude-sonnet-5-5`),
  `Claude Haiku 5.5` (`claude-haiku-5-5`), plus `Other…` revealing a text
  field for any id. For `Other server` a text field, default empty, and a
  prompt without `@model` reports `no model, see Settings → AI`.
- `Base URL`: `Other server` only, default `https://api.openai.com/v1`;
  the app appends `/chat/completions`. Anthropic always goes to
  `https://api.anthropic.com`.
- `Test`: sends `Reply with OK.` through the same code path as a transformer
  (system prompt `You are a connectivity test.`, `max_tokens` 1024, since
  thinking tokens count against the cap, timeout 15 s) and shows the outcome under the button: `OK · claude-opus-5-5 · 1.2 s`
  in secondary colour, or the error text in red. The button is disabled
  while a test runs.

Preferences in `UserDefaults`: `aiProvider` (`anthropic` | `other`),
`aiAnthropicModel`, `aiOtherModel`, `aiOtherBaseURL`. Nothing about AI is
stored in the scrap file.

A prompt run with no key for its provider (and, for `Other server`, no
model) fails before any request: `<name>: no API key, see Settings → AI`.

## Request and response

One request per run: a system prompt, one user message holding the target
text exactly as it is in the editor, no streaming, no tools, no history.
`max_tokens` is 16000 for Anthropic; the other server gets no cap, because
OpenAI's reasoning models reject `max_tokens` and every listed server has
a default of its own. The timeout is the prompt's
`@timeout`, applied to the whole request.

### Anthropic

`POST https://api.anthropic.com/v1/messages`, headers `content-type:
application/json`, `x-api-key`, `anthropic-version: 2026-10-21`. Body:

```json
{
  "model": "claude-opus-5-5",
  "max_tokens": 16000,
  "system": "<prompt body>",
  "messages": [{"role": "user", "content": "<target text>"}],
  "output_config": {"effort": "low"},
  "fallbacks": "default"
}
```

- `thinking` is not sent: the current models think adaptively by default
  and `effort` is the one knob that works on all of them. `low` is the
  default because a transformer is a short rewrite and the user is waiting.
- `fallbacks: "default"` with the header
  `anthropic-beta: server-side-fallback-2026-07-01` lets a request the
  safety classifier declines run on a substitute model inside the same
  call. The parameter has no effect on Haiku, so both the field and the
  header are sent only when the model id does not start with
  `claude-haiku`.
- `temperature` and the other sampling fields are not sent; the
  `2026-10-21` API version rejects them.

Response: `stop_reason` is read first. `refusal` → error `refused`;
`max_tokens` → error `output too long`. Otherwise the `text` blocks of
`content` are joined in order; `thinking` and `fallback` blocks are ignored.

### Other server

`POST <base URL>/chat/completions`, headers `content-type: application/json`
and, when a key is stored, `authorization: Bearer <key>`. Body:

```json
{
  "model": "<model>",
  "messages": [
    {"role": "system", "content": "<prompt body>"},
    {"role": "user", "content": "<target text>"}
  ]
}
```

Response: `choices[0].message.content` as a string. `finish_reason` of
`length` → error `output too long`; `content_filter` → `refused`. `@effort`
is ignored with this provider.

### The result

Trailing newlines of the answer are removed (models end with one; the
scrap's own newline is outside the target). Nothing else is normalised. An
answer that is empty after trimming is the error `empty output`. Unlike a
script, which owns its stdout, a prompt's output is text in a chat
response, so the one trim is the app's job.

### Errors

Shown as `<name>: <message>`, short and lower-case, like every
`TransformError`:

| condition | message |
|---|---|
| HTTP 401 | `401 invalid api key` |
| HTTP 403 | `403 not allowed` |
| HTTP 404 | `404 unknown model or URL` |
| HTTP 429 | `rate limited` |
| HTTP 529 or 503 | `overloaded` |
| other non-2xx | `<status> <first 80 chars of error.message, or error.type>` |
| no connection | `offline` |
| plain `http://` to a non-local host (App Transport Security) | `http needs https, see Settings → AI` |
| timeout | `timed out after N s` |
| unparsable body | `bad response` |

The full response body of a failed request goes to the console log
(`os_log`), not to the banner. No retries: a run is one request; the user
presses `⌘K⌘K` again.

## Running

A prompt runs in the same slot as a script. `TransformController.start`
creates a `PendingTransform`, the header shows `<name>…`, and starting
another prompt or script meanwhile flashes `<name> is running`. The result
is applied by the four rules of the script spec (in place when the target
is intact, else appended as a new scrap, else taken to a fresh scrap when
the panel is hidden, banner only on error). The prompt enters Recent after a
successful application. Quit cancels the request; the answer is not awaited.

## Command line and Services

A `.prompt` file with `@service` is registered by the `Register` button as a
workflow bundle like a script, but a prompt cannot be `exec`ed, so the bundle
runs the app binary instead:

```sh
export LANG=en_US.UTF-8
exec '/Applications/Scrapbench.app/Contents/MacOS/Scrapbench' --transform prompt.improve-text
```

`Scrapbench --transform <id>` is a headless mode checked in `main.swift`
before `NSApplication` starts: it scans the transformers folder, finds the
prompt with that id, reads stdin, performs the request with the key from the
Keychain and the Settings of the same user, writes the answer to stdout and
exits 0. Errors go to stderr with exit 1, which Automator shows in its own
dialog. The bundle holds the app's path from `Bundle.main`, so a moved app
needs `Register` again, like a moved folder does for scripts. The running
app is not involved and need not be running. The mode exists for prompts
only; scripts keep running directly. A second headless mode,
`Scrapbench --set-key <anthropic|other>`, stores the key read from stdin:
a Keychain item written by another binary (the `security` CLI) makes the
app block on an access dialog, so the app has to write its own items. Services are absent from the App Store
build altogether, as before: everything in this section, and the scripts
themselves, is gated on one `Distribution.isSandboxed` check (the
`APP_SANDBOX_CONTAINER_ID` environment variable the sandbox sets), so a
single source tree serves both builds without a compile-time flag. The App
Store spec owns that type.

## Core and app

Core (`ScrapbenchCore/Transformers/Scripts/` and a new
`Transformers/Prompts/`, pure Foundation, unit-tested):

- `ScriptHeader` gains `model: String?`, `provider: PromptProvider?`,
  `effort: Effort?` and a `defaultTimeout` parameter on `parse` (60 for
  prompts, 30 for scripts). `PromptProvider` is `anthropic | other`,
  `Effort` the five levels; both `String`-backed.
- `PromptFile.parse(text, file:) -> Result<(ScriptHeader, body), ScriptProblem>`
  separates header lines from the body and reports `empty prompt`.
- `PromptTransformer: Transformer`: `id`, `name`, `group`, `description`,
  `url`, `timeout`, `systemPrompt`, `model`, `provider`, `effort`,
  `service`. `canApply` true; `apply` throws `runs through the app`.
- `ScriptRegistry.scan` returns prompts in the same list
  (`[any Transformer]` or a second array; the palette does not care).
  `ServicePlan` takes prompts with `@service` too.
- `PromptEndpoint`: the resolved provider, base URL, key, model, effort.
  `PromptRequest.build(endpoint, systemPrompt, input) -> URLRequest`
  and `PromptResponse.parse(provider, status, data) -> Result<String, TransformError>`
  for both wire formats, as pure functions over `Data`.

App:

- `Keychain`: `read(account)`, `write(account, value)`, `delete(account)`
  over `SecItem*`, one service name.
- `PromptRunner`: `URLSession` data task with the request from Core, a
  per-request timeout, `cancel()`, completion on the main thread with
  `Result<String, TransformError>`; the same contract as `ScriptRunner`, so
  `TransformController` holds one `AnyObject` runner and does not branch
  after start.
- `Settings` gains the four AI keys; `SettingsView` the AI tab and the
  `Test` action, which uses `PromptRunner`.
- `ServiceWorkflow` takes the command to run instead of a script path, so
  the bundle for a prompt runs the app binary.
- `main.swift` handles `--transform <id>` before the app delegate exists.
- The App Store build will need the `com.apple.security.network.client`
  entitlement; that belongs to the App Store spec.

## Documentation

- `docs/transformers.md`: a `Prompt transformers` section after the script
  contract: the file format, the header keys that are new, the Settings
  tab, what is sent and what comes back, the errors. An `Other servers`
  table: Ollama `http://localhost:11434/v1`, LM Studio
  `http://localhost:1234/v1`, OpenRouter `https://openrouter.ai/api/v1`,
  OpenAI `https://api.openai.com/v1`, each with a one-line note on the key.
  The `claude -p` examples stay, with a sentence that a `.prompt` file is
  the same thing without the CLI.
- `Examples/transformers/`: `improve-text.prompt`,
  `translate-to-english.prompt`, `corporate-style.prompt`,
  `summarize.prompt`.
- README: one sentence in Transformers (`AI tools are a text file with a
  prompt; bring your own key`) and the link.
- CLAUDE.md: `Prompts/`, `PromptRunner`, `Keychain`, `--transform`, and the
  rule that the key never leaves the Keychain.

## Testing

- `ScriptHeaderTests`: `@model`, `@provider`, `@effort` parsed, bad values
  reported, the default timeout parameter.
- `PromptFileTests`: header lines removed, body trimmed, a `# Heading` kept,
  header lines after line 20 kept, empty body reported.
- `ScriptRegistryTests`: a `.prompt` without the executable bit is a
  transformer; `.prompt` and `.sh` with one stem coexist; two `.prompt`
  with one stem report `duplicate id`; ordering within a shared group.
- `PromptRequestTests`: both bodies and header sets, `fallbacks` and the
  beta header absent for Haiku, no `authorization` header without a key,
  the base URL joined with and without a trailing slash.
- `PromptResponseTests`: text blocks joined, trailing newline trimmed,
  `refusal`, `max_tokens`, every error row, a 200 with an unparsable body.
- `ServicePlanTests`: a prompt with `@service` is an `add`.
- By running the app: `Test` with a wrong key, with no network, with
  Ollama; a 5 s prompt while editing and while hiding the panel; a prompt
  with no key; `--transform` from a terminal and from the Services menu.

## Not in this version

- Streaming the answer into the editor.
- Conversation history or a chat view; every run is one request.
- Passing the selection and the whole scrap separately.
- A third wire format (Gemini, Ollama's native API) or a provider list.
- A base URL for Anthropic (proxies) and per-prompt `max_tokens`.
- Images or files in the request.
