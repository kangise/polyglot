import Foundation
import Security

/// Persistent settings. API key lives in Keychain; model lives in UserDefaults.
enum Settings {
    private static let service = "com.swifttranslate.app"
    private static let account = "openai-api-key"
    private static let modelKey = "openai.model"
    static let defaultModel = "gpt-4o-mini"

    static var model: String {
        get { UserDefaults.standard.string(forKey: modelKey) ?? defaultModel }
        set { UserDefaults.standard.set(newValue, forKey: modelKey) }
    }

    static var apiKey: String? {
        get { keychainRead() }
        set { keychainWrite(newValue) }
    }

    // MARK: - Keychain

    private static func keychainRead() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess,
              let data = out as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private static func keychainWrite(_ value: String?) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        guard let value = value, !value.isEmpty,
              let data = value.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }
}
