import Foundation

/// Decides whether to translate (zh→en) or polish (en→en) based on input.
struct TranslationEngine {
    enum EngineError: LocalizedError {
        case missingAPIKey
        case badResponse(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "OpenAI API key is not set. Open the menu bar icon → Set OpenAI API Key."
            case .badResponse(let detail):
                return "OpenAI error: \(detail)"
            }
        }
    }

    func transform(_ input: String) async throws -> String {
        guard let key = Settings.apiKey, !key.isEmpty else { throw EngineError.missingAPIKey }

        let mode: Mode = containsCJK(input) ? .translateToEnglish : .polishEnglish
        let system = mode.systemPrompt
        let user = input

        return try await callChat(apiKey: key, system: system, user: user)
    }

    // MARK: - Detection

    private func containsCJK(_ s: String) -> Bool {
        for scalar in s.unicodeScalars {
            let v = scalar.value
            // CJK Unified Ideographs + extensions + Hiragana/Katakana + Hangul
            if (0x3040...0x30FF).contains(v) ||
               (0x3400...0x4DBF).contains(v) ||
               (0x4E00...0x9FFF).contains(v) ||
               (0xAC00...0xD7AF).contains(v) ||
               (0x20000...0x2A6DF).contains(v) {
                return true
            }
        }
        return false
    }

    private enum Mode {
        case translateToEnglish
        case polishEnglish

        var systemPrompt: String {
            switch self {
            case .translateToEnglish:
                return """
                You are a professional translator. Translate the user's message into natural, \
                idiomatic English suitable for business chat and email. Preserve the original \
                tone (formal vs casual) and meaning. Do not add commentary, quotes, or labels. \
                Return only the translated text.
                """
            case .polishEnglish:
                return """
                You are an expert editor for a non-native English speaker. Rewrite the user's \
                message into clear, natural, idiomatic English. Keep the original intent, tone, \
                and level of formality. Fix grammar and awkward phrasing. Keep it concise. \
                Do not add commentary, quotes, or labels. Return only the rewritten text.
                """
            }
        }
    }

    // MARK: - OpenAI call

    private func callChat(apiKey: String, system: String, user: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": Settings.model,
            "temperature": 0.3,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw EngineError.badResponse("invalid response")
        }
        if !(200..<300).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "http \(http.statusCode)"
            throw EngineError.badResponse(msg)
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw EngineError.badResponse("empty content")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }
}
