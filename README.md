# swift-translate

> Select text anywhere on macOS → press `⌥⌘T` → it's rewritten in natural English, in place.

[![CI](https://github.com/kangise/easy-translate/actions/workflows/ci.yml/badge.svg)](https://github.com/kangise/easy-translate/actions/workflows/ci.yml)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue.svg)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A tiny menu-bar utility for non-native English speakers. Write your message in
Slack, Mail, Notes, a browser, wherever. Select it, hit a hotkey, and it's
replaced with a polished version.

- **CJK selection** → translated to natural business English
- **English selection** → rewritten into idiomatic, native-sounding English

Powered by the OpenAI Chat Completions API. One file per responsibility,
zero third-party dependencies.

---

## Install

```bash
git clone https://github.com/kangise/easy-translate.git
cd easy-translate
./install.sh
```

This builds a release binary, copies it to `~/Applications/swift-translate`,
and registers it as a hidden Login Item so it starts at login. The script
offers to launch it at the end.

First-run prompts:

1. **Accessibility permission** — macOS will ask. Required so the app can
   synthesize `⌘C` / `⌘V` against the focused app to read and replace the
   selection.
2. **OpenAI API key** — paste your `sk-...` key. Stored in the macOS Keychain.

To uninstall: `./uninstall.sh`

## Use

1. Select some text in any app.
2. Press **`⌥⌘T`** (Option + Command + T).
3. The selection gets replaced.

Click the `🌐` menu bar icon to change the API key, change the model, or quit.

## Configuration

| Setting  | Default       | Where it lives |
| -------- | ------------- | ---------------------- |
| Hotkey   | `⌥⌘T`         | Hardcoded — see `AppDelegate.swift` |
| Model    | `gpt-4o-mini` | `UserDefaults` (menu: "Set Model…") |
| API key  | *(unset)*     | Keychain, service `com.swifttranslate.app` |

`gpt-4o-mini` handles a sentence or two for a fraction of a cent. Bump to
`gpt-4o` via the menu if you want heavier rewrites.

## Build from source

```bash
swift build            # debug
swift build -c release # release → .build/release/swift-translate
./.build/debug/swift-translate
```

Requirements: macOS 13+, Swift 5.9+, Xcode CLT.

## How it works

```
hotkey (Carbon)  ─►  snapshot pasteboard
                 ─►  synthetic ⌘C          ─►  read selection from pasteboard
                 ─►  detect CJK vs English
                 ─►  OpenAI chat completion
                 ─►  put result on pasteboard
                 ─►  synthetic ⌘V          ─►  selection replaced
                 ─►  restore pasteboard (so your clipboard isn't trashed)
```

Source map:

```
Sources/SwiftTranslate/
  main.swift              App entry
  AppDelegate.swift       Menu bar + orchestration
  HotKeyManager.swift     Global hotkey via Carbon's RegisterEventHotKey
  SelectionIO.swift       Read / replace selection via synthetic ⌘C / ⌘V
  TranslationEngine.swift CJK vs English routing + OpenAI call
  Settings.swift          Keychain + UserDefaults
```

## Limitations

- **Accessibility permission is required.** There's no way around it on macOS.
- Only works where `⌘C` / `⌘V` work. Secure text fields and a handful of
  terminals don't cooperate.
- Not sandboxed or notarized. Fine for your own machine; ship a signed
  `.app` if you want to distribute.

## Privacy

The selected text is sent to OpenAI to be rewritten. Nothing else is sent.
The API key never leaves your Keychain except in the `Authorization` header
of the OpenAI request.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Keep the scope tight, keep the
dependencies at zero.

## License

MIT. See [LICENSE](LICENSE).
