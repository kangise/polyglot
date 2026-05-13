import AppKit
import Carbon.HIToolbox

/// Reads and replaces the *currently selected* text in any focused app by
/// simulating ⌘C / ⌘V against a temporarily-swapped pasteboard.
enum SelectionIO {
    enum IOError: LocalizedError {
        case accessibilityDenied
        var errorDescription: String? {
            switch self {
            case .accessibilityDenied:
                return "Accessibility permission is required. Enable it in System Settings → Privacy & Security → Accessibility."
            }
        }
    }

    static func readSelection() async throws -> String? {
        try ensureAccessibility()
        let pb = NSPasteboard.general
        let saved = snapshot(pb)
        defer { restore(pb, saved) }

        pb.clearContents()
        let baselineCount = pb.changeCount

        postCommand(keyCode: CGKeyCode(kVK_ANSI_C))

        // Wait up to ~400ms for the pasteboard to update.
        let deadline = Date().addingTimeInterval(0.4)
        while pb.changeCount == baselineCount && Date() < deadline {
            try? await Task.sleep(nanoseconds: 15_000_000)
        }
        return pb.string(forType: .string)
    }

    static func replaceSelection(with text: String) async throws {
        try ensureAccessibility()
        let pb = NSPasteboard.general
        let saved = snapshot(pb)

        pb.clearContents()
        pb.setString(text, forType: .string)

        postCommand(keyCode: CGKeyCode(kVK_ANSI_V))

        // Give the target app a beat to read from the pasteboard before restore.
        try? await Task.sleep(nanoseconds: 250_000_000)
        restore(pb, saved)
    }

    // MARK: - Helpers

    private static func ensureAccessibility() throws {
        if !AXIsProcessTrusted() { throw IOError.accessibilityDenied }
    }

    private static func postCommand(keyCode: CGKeyCode) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func snapshot(_ pb: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pb.pasteboardItems ?? []).map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type] = data }
            }
            return dict
        }
    }

    private static func restore(_ pb: NSPasteboard, _ saved: [[NSPasteboard.PasteboardType: Data]]) {
        pb.clearContents()
        for entry in saved {
            let item = NSPasteboardItem()
            for (type, data) in entry { item.setData(data, forType: type) }
            pb.writeObjects([item])
        }
    }
}
