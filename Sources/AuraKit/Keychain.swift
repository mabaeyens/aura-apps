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
    ///
    /// A valid AEMET key is a JWT with no internal whitespace, but email clients line-wrap it, so a
    /// paste can carry a newline or space in the middle that end-trimming leaves in place. That
    /// corrupts the stored key and AEMET rejects it with a 401, so strip every whitespace character,
    /// not just the ends.
    public static func setAPIKey(_ key: String) {
        let cleaned = key.filter { !$0.isWhitespace }
        guard !cleaned.isEmpty else { delete(account: apiKeyAccount); return }
        save(cleaned, account: apiKeyAccount)
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
        // `ThisDeviceOnly`: a credential should never leave this device. Without it the key is copied
        // into encrypted device backups and restored onto a new device; with it, a device migration
        // simply re-prompts for the key. Setting it on the update path too migrates existing installs
        // the next time the key is saved.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
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
