import AppKit

/// A small panel for entering the OpenAI API key. Includes an explicit
/// "Paste from Clipboard" button so users aren't dependent on ⌘V being
/// routed correctly in a menu-bar (LSUIElement) app.
final class APIKeyWindowController: NSWindowController, NSWindowDelegate {
    private let field = NSSecureTextField()
    private let status = NSTextField(labelWithString: "")
    private let onSave: (String) -> Void

    init(initial: String, onSave: @escaping (String) -> Void) {
        self.onSave = onSave

        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 170),
                            styleMask: [.titled, .closable, .utilityWindow],
                            backing: .buffered,
                            defer: false)
        panel.title = "OpenAI API Key"
        panel.level = .modalPanel
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        super.init(window: panel)
        panel.delegate = self

        field.stringValue = initial
        field.placeholderString = "sk-..."
        field.isEditable = true
        field.isSelectable = true
        field.font = .systemFont(ofSize: 13)
        field.target = self
        field.action = #selector(save)
        field.nextKeyView = field

        let label = NSTextField(labelWithString:
            "Paste your key, or click the Paste button. Stored in macOS Keychain.")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor

        let pasteButton = NSButton(title: "Paste from Clipboard",
                                   target: self, action: #selector(pasteFromClipboard))
        pasteButton.bezelStyle = .rounded

        let cancelButton = NSButton(title: "Cancel",
                                    target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        let saveButton = NSButton(title: "Save",
                                  target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor

        let buttonRow = NSStackView(views: [pasteButton, NSView(), status, cancelButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY

        let stack = NSStackView(views: [label, field, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView(frame: panel.contentView!.bounds)
        content.autoresizingMask = [.width, .height]
        content.addSubview(stack)
        panel.contentView = content

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 420),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor,
                                             constant: -36)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(field)
    }

    // MARK: - Actions

    @objc private func pasteFromClipboard() {
        let pb = NSPasteboard.general
        if let s = pb.string(forType: .string) {
            field.stringValue = s.trimmingCharacters(in: .whitespacesAndNewlines)
            status.stringValue = "Pasted \(field.stringValue.count) chars"
            status.textColor = .secondaryLabelColor
        } else {
            status.stringValue = "Clipboard is empty"
            status.textColor = .systemRed
        }
    }

    @objc private func save() {
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            status.stringValue = "Key is empty"
            status.textColor = .systemRed
            return
        }
        if !value.hasPrefix("sk-") {
            status.stringValue = "Key doesn't start with sk-. Saving anyway."
            status.textColor = .systemOrange
        }
        onSave(value)
        close()
    }

    @objc private func cancel() { close() }
}
