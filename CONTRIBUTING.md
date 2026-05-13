# Contributing

Thanks for taking the time! This project is tiny on purpose, but PRs that fit
the scope are very welcome.

## Scope

`swift-translate` is a single-purpose menu-bar utility:

- Read the current selection.
- Translate (CJK → EN) or polish (EN → EN).
- Replace the selection.

Features that don't serve that loop belong in a fork.

## Dev setup

Requirements:

- macOS 13+
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+

```bash
git clone <your-fork>
cd swift-translate
swift build
./.build/debug/swift-translate
```

## Style

- Follow standard Swift API Design Guidelines.
- Keep dependencies at zero. This project has none and it should stay that way.
- Prefer `async/await` over completion handlers.
- One file per responsibility (`TranslationEngine`, `SelectionIO`, …).

## Pull requests

1. Open an issue first for anything non-trivial so we can agree on scope.
2. Keep PRs focused. One change per PR.
3. Update `CHANGELOG.md` under `[Unreleased]`.
4. Make sure `swift build -c release` passes.

## Security

If you find a security issue, please **do not** open a public issue. Email the
maintainer or use GitHub's private vulnerability reporting.
