# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Menu-bar app with global hotkey `⌥⌘T` to translate or polish the current
  selection in any macOS app.
- Auto-routing: CJK input is translated to English; English input is polished.
- OpenAI Chat Completions backend; default model `gpt-4o-mini`.
- API key stored in Keychain; model stored in `UserDefaults`.
- `install.sh` / `uninstall.sh` for `~/Applications` + Login Item.
- GitHub Actions CI running `swift build` on `macos-latest`.
