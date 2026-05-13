import AppKit
import ApplicationServices

/// Reads and replaces the paragraph surrounding the cursor in the focused
/// text field, using the macOS Accessibility API.
///
/// Works reliably in native AppKit text views (Mail, Notes, Messages, Safari
/// text fields). Returns nil in Electron apps (Slack, Notion, VS Code) when
/// their AX tree doesn't expose the text value.
enum AccessibilityReader {
    struct ParagraphContext {
        let element: AXUIElement
        let fullText: String
        /// Range (in UTF-16 code units) of the paragraph inside `fullText`.
        let paragraphRange: NSRange
        var paragraphText: String {
            let ns = fullText as NSString
            guard paragraphRange.location + paragraphRange.length <= ns.length else {
                return ""
            }
            return ns.substring(with: paragraphRange)
        }
    }

    // MARK: - Public

    static func readFocusedParagraph() -> ParagraphContext? {
        guard AXIsProcessTrusted() else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        let status = AXUIElementCopyAttributeValue(systemWide,
                                                   kAXFocusedUIElementAttribute as CFString,
                                                   &focused)
        guard status == .success, let element = focused else { return nil }
        let axElement = element as! AXUIElement

        // Read full value string.
        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(axElement,
                                            kAXValueAttribute as CFString,
                                            &valueRef) == .success,
              let text = valueRef as? String, !text.isEmpty else {
            return nil
        }

        // Read selection range; fall back to end-of-text if unavailable.
        var rangeRef: AnyObject?
        var cursorLocation = (text as NSString).length
        if AXUIElementCopyAttributeValue(axElement,
                                         kAXSelectedTextRangeAttribute as CFString,
                                         &rangeRef) == .success,
           let axValue = rangeRef, CFGetTypeID(axValue) == AXValueGetTypeID() {
            var range = CFRange(location: 0, length: 0)
            if AXValueGetValue(axValue as! AXValue, .cfRange, &range) {
                cursorLocation = range.location
            }
        }

        let paragraph = paragraphRange(in: text, at: cursorLocation)
        guard paragraph.length > 0 else { return nil }

        return ParagraphContext(element: axElement,
                                fullText: text,
                                paragraphRange: paragraph)
    }

    /// Replace the given paragraph range with new text using AX.
    /// Returns false if the app's AX tree doesn't accept the write.
    static func replace(_ context: ParagraphContext, with newText: String) -> Bool {
        var range = CFRange(location: context.paragraphRange.location,
                            length: context.paragraphRange.length)
        guard let axRange = AXValueCreate(.cfRange, &range) else { return false }

        // Select the paragraph range first.
        let selectStatus = AXUIElementSetAttributeValue(context.element,
                                                        kAXSelectedTextRangeAttribute as CFString,
                                                        axRange)
        guard selectStatus == .success else { return false }

        // Replace the selected range with the new text.
        let replaceStatus = AXUIElementSetAttributeValue(context.element,
                                                         kAXSelectedTextAttribute as CFString,
                                                         newText as CFString)
        return replaceStatus == .success
    }

    // MARK: - Paragraph boundaries

    /// Finds the paragraph (bounded by `\n` or `\r`) containing `offset` in
    /// UTF-16 space. Handles end-of-text by walking back one character.
    private static func paragraphRange(in text: String, at offset: Int) -> NSRange {
        let ns = text as NSString
        var location = min(max(offset, 0), ns.length)
        if location == ns.length && location > 0 { location -= 1 }

        var start = location
        while start > 0 {
            let prev = ns.character(at: start - 1)
            if prev == 0x0A || prev == 0x0D { break }
            start -= 1
        }

        var end = location
        while end < ns.length {
            let ch = ns.character(at: end)
            if ch == 0x0A || ch == 0x0D { break }
            end += 1
        }

        // Trim trailing whitespace inside the paragraph so we don't feed the
        // LLM a bunch of trailing spaces.
        while end > start {
            let ch = ns.character(at: end - 1)
            if ch != 0x20 && ch != 0x09 { break }
            end -= 1
        }

        return NSRange(location: start, length: end - start)
    }
}
