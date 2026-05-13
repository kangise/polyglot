import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotKey = HotKeyManager()
    private let engine = TranslationEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        ensureAccessibility()
        ensureAPIKey()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }

        hotKey.onTrigger = { [weak self] in
            self?.translateSelection()
        }
        hotKey.register() // ⌥⌘T by default
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🌐"
            button.toolTip = "swift-translate — ⌥⌘T to translate selection"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Translate Selection  ⌥⌘T",
                                action: #selector(translateSelection),
                                keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Set OpenAI API Key…",
                                action: #selector(promptForAPIKey),
                                keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Set Model…",
                                action: #selector(promptForModel),
                                keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        for item in menu.items where item.action != nil && item.action != #selector(NSApp.terminate(_:)) {
            item.target = self
        }
    }

    // MARK: - Core flow

    @objc func translateSelection() {
        Task {
            do {
                guard let original = try await SelectionIO.readSelection() else {
                    notify("No text selected", body: "Select some text first, then press ⌥⌘T.")
                    return
                }
                let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    notify("Selection is empty", body: nil)
                    return
                }

                let replacement = try await engine.transform(trimmed)
                try await SelectionIO.replaceSelection(with: replacement)
            } catch {
                notify("Translation failed", body: error.localizedDescription)
            }
        }
    }

    // MARK: - Settings prompts

    @objc private func promptForAPIKey() {
        let alert = NSAlert()
        alert.messageText = "OpenAI API Key"
        alert.informativeText = "Paste your key (sk-...). Stored in Keychain."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = Settings.apiKey ?? ""
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            Settings.apiKey = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    @objc private func promptForModel() {
        let alert = NSAlert()
        alert.messageText = "OpenAI Model"
        alert.informativeText = "Model id, e.g. gpt-4o-mini, gpt-4o, gpt-4.1-mini."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = Settings.model
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { Settings.model = value }
        }
    }

    // MARK: - First-run checks

    private func ensureAccessibility() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    private func ensureAPIKey() {
        if Settings.apiKey == nil || Settings.apiKey?.isEmpty == true {
            DispatchQueue.main.async { [weak self] in self?.promptForAPIKey() }
        }
    }

    // MARK: - Notifications

    private func notify(_ title: String, body: String?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body ?? ""
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
