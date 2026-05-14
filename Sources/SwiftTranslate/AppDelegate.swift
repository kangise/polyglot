import AppKit
import Carbon.HIToolbox
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotKey = HotKeyManager()
    private let engine = TranslationEngine()
    private let panel = SuggestionPanel()

    /// In-flight draft session state so Retry and Accept know what to do.
    private var draftContext: AccessibilityReader.ParagraphContext?
    private var draftFallbackSelection: String?
    private var draftOriginalText: String?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusItem()
        ensureAccessibility()
        ensureAPIKey()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }

        hotKey.onTrigger = { [weak self] id in
            switch id {
            case "translate": self?.translateSelection()
            case "draft":     self?.draftSuggestion()
            default: break
            }
        }
        hotKey.register(id: "translate",
                        keyCode: UInt32(kVK_ANSI_T),
                        modifiers: UInt32(cmdKey | optionKey))
        hotKey.register(id: "draft",
                        keyCode: UInt32(kVK_ANSI_D),
                        modifiers: UInt32(cmdKey | optionKey))

        panel.onAccept = { [weak self] text in self?.applyAcceptedDraft(text) }
        panel.onDismiss = { [weak self] in self?.clearDraftState() }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(retryDraft),
                                               name: .suggestionPanelRetry,
                                               object: panel)
    }

    // MARK: - Menu bar

    /// Menu bar apps (LSUIElement) don't get a default Edit menu, which breaks
    /// ⌘C / ⌘V / ⌘X / ⌘A in alerts and panels. Install a minimal main menu
    /// so standard editing shortcuts dispatch correctly.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit",
                        action: #selector(NSApp.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo",
                         action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo",
                         action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut",
                         action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",
                         action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",
                         action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All",
                         action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🌐"
            button.toolTip = "polyglot — ⌥⌘T replace, ⌥⌘D draft"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Translate Selection  ⌥⌘T",
                                action: #selector(translateSelection),
                                keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Draft from Paragraph  ⌥⌘D",
                                action: #selector(draftSuggestion),
                                keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings…",
                                action: #selector(openAccessibilitySettings),
                                keyEquivalent: ""))
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

    // MARK: - ⌥⌘T : in-place replace (unchanged behavior)

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

    // MARK: - ⌥⌘D : draft suggestion panel

    @objc func draftSuggestion() {
        // Prefer AX (no selection needed). Fall back to selection if AX can't
        // read the focused field (Slack/VS Code/etc).
        if let ctx = AccessibilityReader.readFocusedParagraph(),
           !ctx.paragraphText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draftContext = ctx
            draftFallbackSelection = nil
            startDraft(for: ctx.paragraphText, anchor: screenAnchor())
            return
        }

        Task { @MainActor in
            do {
                guard let sel = try await SelectionIO.readSelection(),
                      !sel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    notify("Nothing to draft",
                           body: "Place your cursor in a text field, or select text, then press ⌥⌘D.")
                    return
                }
                draftContext = nil
                draftFallbackSelection = sel
                startDraft(for: sel, anchor: screenAnchor())
            } catch {
                notify("Could not read text", body: error.localizedDescription)
            }
        }
    }

    @objc private func retryDraft() {
        guard let original = draftOriginalText else { return }
        startDraft(for: original, anchor: screenAnchor(), isRetry: true)
    }

    private func startDraft(for original: String, anchor: NSRect?, isRetry: Bool = false) {
        draftOriginalText = original
        panel.showLoading(original: original, anchor: anchor)

        Task {
            do {
                let rewritten = try await engine.transform(original)
                await MainActor.run {
                    self.panel.showResult(original: original, rewritten: rewritten)
                }
            } catch {
                await MainActor.run {
                    self.panel.showError(error.localizedDescription)
                }
            }
        }
    }

    private func applyAcceptedDraft(_ rewritten: String) {
        if let ctx = draftContext, AccessibilityReader.replace(ctx, with: rewritten) {
            clearDraftState()
            return
        }
        // Fallback: use pasteboard-based replace. Works when user had a selection.
        if draftFallbackSelection != nil {
            Task {
                do {
                    try await SelectionIO.replaceSelection(with: rewritten)
                } catch {
                    notify("Replace failed", body: error.localizedDescription)
                }
                clearDraftState()
            }
            return
        }
        // Last resort: copy to clipboard so the user can paste manually.
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(rewritten, forType: .string)
        notify("Copied to clipboard",
               body: "Couldn't edit that field directly, so the suggestion is on your clipboard.")
        clearDraftState()
    }

    private func clearDraftState() {
        draftContext = nil
        draftFallbackSelection = nil
        draftOriginalText = nil
    }

    private func screenAnchor() -> NSRect? {
        guard let screen = NSScreen.main else { return nil }
        let frame = screen.visibleFrame
        return NSRect(x: frame.maxX - 600, y: frame.minY + 40, width: 0, height: 0)
    }

    // MARK: - Settings prompts

    private var apiKeyWindow: APIKeyWindowController?

    @objc private func promptForAPIKey() {
        let current = Settings.apiKey ?? ""
        let controller = APIKeyWindowController(initial: current) { key in
            Settings.apiKey = key
        }
        apiKeyWindow = controller
        controller.present()
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

    @objc private func openAccessibilitySettings() {
        // Trigger a permission prompt first (no-op if already granted),
        // then jump to the right pane in System Settings.
        ensureAccessibility()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
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
