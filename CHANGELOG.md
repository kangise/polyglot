# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **`⌥⌘D` Draft mode**: floating suggestion panel with word-level diff, accept
  with `⌘↩`, dismiss with `Esc`, or retry for a new rewrite. No selection
  required in native macOS apps — reads the focused paragraph via the
  Accessibility API. Falls back to the current selection in apps whose AX tree
  doesn't expose text (Electron apps like Slack, Notion, VS Code).
- `AccessibilityReader`, `SuggestionPanel`, `DiffRenderer` modules.
- Multi-hotkey support in `HotKeyManager` (dispatch by string id).

### Changed
- `HotKeyManager.register` now requires a string `id` and dispatches
  `onTrigger` with that id so callers can register multiple hotkeys.

## [0.1.0] - 2026-05-13

### Added
- Menu-bar app with global hotkey `⌥⌘T` to translate or polish the current
  selection in any macOS app.
- Auto-routing: CJK input is translated to English; English input is polished.
- OpenAI Chat Completions backend; default model `gpt-4o-mini`.
- API key stored in Keychain; model stored in `UserDefaults`.
- `install.sh` / `uninstall.sh` for `~/Applications` + Login Item.
- GitHub Actions CI running `swift build` on `macos-latest`.
