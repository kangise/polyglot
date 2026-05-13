import AppKit

/// Produces an attributed string that shows a word-level diff between two
/// strings. Removed words are struck through in red; added words have a green
/// background. Unchanged words use the default label color.
enum DiffRenderer {
    static func render(original: String, rewritten: String, font: NSFont) -> NSAttributedString {
        let a = tokenize(original)
        let b = tokenize(rewritten)
        let ops = lcsDiff(a, b)

        let out = NSMutableAttributedString()
        let addBg = NSColor.systemGreen.withAlphaComponent(0.22)
        let delFg = NSColor.systemRed

        for op in ops {
            switch op {
            case .equal(let token):
                out.append(NSAttributedString(string: token, attributes: [
                    .font: font,
                    .foregroundColor: NSColor.labelColor
                ]))
            case .insert(let token):
                out.append(NSAttributedString(string: token, attributes: [
                    .font: font,
                    .foregroundColor: NSColor.labelColor,
                    .backgroundColor: addBg
                ]))
            case .delete(let token):
                out.append(NSAttributedString(string: token, attributes: [
                    .font: font,
                    .foregroundColor: delFg,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: delFg
                ]))
            }
        }
        return out
    }

    // MARK: - Internals

    private enum Op {
        case equal(String)
        case insert(String)
        case delete(String)
    }

    /// Tokenize into words + separators so that whitespace is preserved verbatim
    /// and diffs align on word boundaries.
    private static func tokenize(_ s: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var currentIsWord = false
        for ch in s {
            let isWord = ch.isLetter || ch.isNumber
            if current.isEmpty {
                current.append(ch); currentIsWord = isWord; continue
            }
            if isWord == currentIsWord {
                current.append(ch)
            } else {
                tokens.append(current)
                current = String(ch)
                currentIsWord = isWord
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Classic LCS-based diff. Fine for paragraph-sized input.
    private static func lcsDiff(_ a: [String], _ b: [String]) -> [Op] {
        let n = a.count, m = b.count
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0..<n {
            for j in 0..<m {
                if a[i] == b[j] {
                    dp[i + 1][j + 1] = dp[i][j] + 1
                } else {
                    dp[i + 1][j + 1] = max(dp[i][j + 1], dp[i + 1][j])
                }
            }
        }

        var ops: [Op] = []
        var i = n, j = m
        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                ops.append(.equal(a[i - 1])); i -= 1; j -= 1
            } else if dp[i - 1][j] >= dp[i][j - 1] {
                ops.append(.delete(a[i - 1])); i -= 1
            } else {
                ops.append(.insert(b[j - 1])); j -= 1
            }
        }
        while i > 0 { ops.append(.delete(a[i - 1])); i -= 1 }
        while j > 0 { ops.append(.insert(b[j - 1])); j -= 1 }
        return ops.reversed()
    }
}
