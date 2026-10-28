# Contributing

Scrapbench is a Swift Package for macOS 14 and later. There is no `.xcodeproj`.

## Build and test

```sh
make app      # release build, build/Scrapbench.app, ad-hoc signed
make run      # build and launch
make test     # swift test, ScrapbenchCore only
```

`ScrapbenchCore` is pure Foundation and fully unit-tested with Swift Testing.
`ScrapbenchApp` is AppKit and has no tests; its behaviour is verified by running
the app. `CLAUDE.md` describes the architecture and the manual-testing setup.

## Changes

- The design specs in `docs/superpowers/specs/` describe the behaviour. A change
  in behaviour changes the spec in the same pull request.
- Core changes come with tests. App changes describe in the pull request how
  they were verified by hand.
- Keep pull requests small, one change each.
- Commit messages follow `type(scope): subject`, for example
  `fix(core): Base64 decode ignores short words`. Types: `feat`, `fix`, `perf`,
  `refactor`, `docs`, `chore`. Scopes: `core`, `app`.
- UI text follows `docs/brand.md`: short sentences, no exclamation marks, the
  vocabulary scrap / bench / transformer.

## Reporting bugs

Open an issue with macOS version, what you did, what happened and what you
expected. For security issues see `SECURITY.md`.
