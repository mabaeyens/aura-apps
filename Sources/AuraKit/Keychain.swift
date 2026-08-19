import Foundation
import Security

/// Minimal Keychain wrapper for the single secret Aura stores: the AEMET API key.
///
/// The key never lives in the binary or the repo — only here, in the Keychain. Later phases
/// move this into a shared access group so widgets and the Watch read the same item; for now
/// it is app-local.
public enum AuraKeychain {
    /// Account under which the AEMET key is stored.
    public static let apiKeyAccount = "aemet-api-key"

    private static let service = "com.mab.Aura"

    /// Store (or replace) the AEMET API key. Passing an empty string deletes it.
    public static func setAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { delete(account: apiKeyAccount); return }
        save(trimmed, account: apiKeyAccount)
    }

    /// The stored AEMET API key, or nil if none has been set.
    public static func apiKey() -> String? {
        load(account: apiKeyAccount)
    }

    // MARK: - Generic item access

    private static func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    private static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
