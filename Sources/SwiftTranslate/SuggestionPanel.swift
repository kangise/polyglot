import AppKit

/// Floating panel that shows the original text, a rewritten suggestion, and a
/// word-level diff. The user accepts with ⌘↩ or dismisses with Esc.
final class SuggestionPanel: NSPanel {
    var onAccept: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private let originalView = NSTextView()
    private let diffView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let acceptButton = NSButton(title: "Accept  ⌘↩", target: nil, action: nil)
    private let dismissButton = NSButton(title: "Dismiss  Esc", target: nil, action: nil)
    private let retryButton = NSButton(title: "Retry", target: nil, action: nil)

    private var currentSuggestion: String?

    // MARK: - Init

    init() {
        let size = NSSize(width: 560, height: 380)
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel, .hudWindow],
                   backing: .buffered,
                   defer: false)

        title = "Suggestion"
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
        worksWhenModal = true

        buildLayout()
    }

    override var canBecomeKey: Bool { true }

    // MARK: - Public API

    func showLoading(original: String, anchor: NSRect?) {
        currentSuggestion = nil
        statusLabel.stringValue = "Rewriting…"
        acceptButton.isEnabled = false
        retryButton.isEnabled = false

        setPlain(originalView, text: original)
        setPlain(diffView, text: "")

        position(near: anchor)
        orderFrontRegardless()
        makeKey()
    }

    func showResult(original: String, rewritten: String) {
        currentSuggestion = rewritten
        statusLabel.stringValue = "\(wordCount(original)) → \(wordCount(rewritten)) words"
        acceptButton.isEnabled = true
        retryButton.isEnabled = true

        setPlain(originalView, text: original)
        setAttributed(diffView, string: DiffRenderer.render(
            original: original, rewritten: rewritten, font: diffFont()))
    }

    func showError(_ message: String) {
        currentSuggestion = nil
        statusLabel.stringValue = "Error: \(message)"
        acceptButton.isEnabled = false
        retryButton.isEnabled = true
    }

    // MARK: - Layout

    private func buildLayout() {
        let content = NSView(frame: contentView!.bounds)
        content.autoresizingMask = [.width, .height]
        contentView = content

        configureTextView(originalView, placeholder: "Original")
        configureTextView(diffView, placeholder: "Suggestion")

        let originalScroll = scrollWrap(originalView)
        let diffScroll = scrollWrap(diffView)

        let originalHeader = sectionLabel("Original")
        let diffHeader = sectionLabel("Suggestion (diff)")

        acceptButton.bezelStyle = .rounded
        acceptButton.keyEquivalent = "\r"
        acceptButton.keyEquivalentModifierMask = [.command]
        acceptButton.target = self
        acceptButton.action = #selector(accept)

        dismissButton.bezelStyle = .rounded
        dismissButton.keyEquivalent = "\u{1b}" // Esc
        dismissButton.target = self
        dismissButton.action = #selector(dismiss)

        retryButton.bezelStyle = .rounded
        retryButton.target = self
        retryButton.action = #selector(retry)

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor

        let buttonRow = NSStackView(views: [retryButton, statusLabel, dismissButton, acceptButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY
        buttonRow.setHuggingPriority(.defaultLow, for: .horizontal)
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [originalHeader, originalScroll, diffHeader, diffScroll, buttonRow])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            originalScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            diffScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])
    }

    private func configureTextView(_ tv: NSTextView, placeholder: String) {
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = true
        tv.backgroundColor = .textBackgroundColor
        tv.font = diffFont()
        tv.textContainerInset = NSSize(width: 6, height: 6)
    }

    private func scrollWrap(_ tv: NSTextView) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .lineBorder
        scroll.documentView = tv
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true
        return scroll
    }

    private func sectionLabel(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.textColor = .secondaryLabelColor
        return l
    }

    private func diffFont() -> NSFont { .systemFont(ofSize: 13) }

    // MARK: - Actions

    @objc private func accept() {
        guard let s = currentSuggestion else { return }
        orderOut(nil)
        onAccept?(s)
    }

    @objc private func dismiss() {
        orderOut(nil)
        onDismiss?()
    }

    @objc private func retry() {
        NotificationCenter.default.post(name: .suggestionPanelRetry, object: self)
    }

    // MARK: - Helpers

    private func setPlain(_ tv: NSTextView, text: String) {
        tv.textStorage?.setAttributedString(
            NSAttributedString(string: text,
                               attributes: [.font: diffFont(),
                                            .foregroundColor: NSColor.labelColor]))
    }

    private func setAttributed(_ tv: NSTextView, string: NSAttributedString) {
        tv.textStorage?.setAttributedString(string)
    }

    private func wordCount(_ s: String) -> Int {
        s.split { $0.isWhitespace || $0.isNewline }.count
    }

    private func position(near anchor: NSRect?) {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        var frame = self.frame
        if let a = anchor {
            frame.origin.x = min(a.maxX + 12,
                                 screenFrame.maxX - frame.width - 12)
            frame.origin.y = min(max(a.minY, screenFrame.minY + 12),
                                 screenFrame.maxY - frame.height - 12)
        } else {
            frame.origin.x = screenFrame.maxX - frame.width - 24
            frame.origin.y = screenFrame.minY + 24
        }
        setFrame(frame, display: true)
    }
}

extension Notification.Name {
    static let suggestionPanelRetry = Notification.Name("suggestionPanelRetry")
}
