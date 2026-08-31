import Foundation
import Security

final class TokenStorage {

    static let shared = TokenStorage()

    private init() {
        migrateFromUserDefaultsIfNeeded()
    }

    // MARK: - Keys

    private let service = "sok.com.gru.auth"
    private let tokenAccount = "jwt_token"
    private let userIDAccount = "user_id"

    // Legacy UserDefaults keys for migration
    private let legacyTokenKey = "jwt"
    private let legacyUserIDKey = "serverUserID"

    // MARK: - Token

    var token: String? {
        if let keychainToken = readFromKeychain(account: tokenAccount) {
            return keychainToken
        }
        // Fallback to UserDefaults if migration hasn't run yet
        return UserDefaults.standard.string(forKey: legacyTokenKey)
    }

    // MARK: - User ID

    var userID: String? {
        if let keychainUserID = readFromKeychain(account: userIDAccount) {
            return keychainUserID
        }
        return UserDefaults.standard.string(forKey: legacyUserIDKey)
    }

    // MARK: - Save Session

    func save(token: String, userID: String) {
        saveToKeychain(value: token, account: tokenAccount)
        saveToKeychain(value: userID, account: userIDAccount)

        // Also keep synchronized in UserDefaults as backup for background extensions
        UserDefaults.standard.set(token, forKey: legacyTokenKey)
        UserDefaults.standard.set(userID, forKey: legacyUserIDKey)
    }

    // MARK: - Compatibility

    func save(_ token: String) {
        saveToKeychain(value: token, account: tokenAccount)
        UserDefaults.standard.set(token, forKey: legacyTokenKey)
    }

    // MARK: - Clear

    func clear() {
        deleteFromKeychain(account: tokenAccount)
        deleteFromKeychain(account: userIDAccount)

        UserDefaults.standard.removeObject(forKey: legacyTokenKey)
        UserDefaults.standard.removeObject(forKey: legacyUserIDKey)
    }

    // MARK: - Migration

    private func migrateFromUserDefaultsIfNeeded() {
        if let legacyToken = UserDefaults.standard.string(forKey: legacyTokenKey), !legacyToken.isEmpty {
            if readFromKeychain(account: tokenAccount) == nil {
                saveToKeychain(value: legacyToken, account: tokenAccount)
            }
        }

        if let legacyUserID = UserDefaults.standard.string(forKey: legacyUserIDKey), !legacyUserID.isEmpty {
            if readFromKeychain(account: userIDAccount) == nil {
                saveToKeychain(value: legacyUserID, account: userIDAccount)
            }
        }
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Remove existing item first
        deleteFromKeychain(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func readFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return string
    }

    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Session Events

extension Notification.Name {
    static let gruSessionInvalidated = Notification.Name("gru.session.invalidated")
}
