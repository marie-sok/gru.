import Foundation
import Security

final class TokenStorage {

    static let shared = TokenStorage()

    private let service = "sok.com.gru.auth.beta.session.v4"
    private let legacyServices = [
        "sok.com.gru.auth",
        "sok.com.gru.auth.beta.session.v3"
    ]

    private let tokenAccount = "jwt_token"
    private let userIDAccount = "user_id"
    private let backendAccount = "backend_base_url"

    private let legacyTokenKey = "jwt"
    private let legacyUserIDKey = "serverUserID"

    private init() {
        purgeLegacyStorage()
        discardSessionIfBackendChanged()
    }

    private var currentBackend: String {
        GRUServerConfiguration.httpBaseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    var storedBackend: String? {
        readFromKeychain(service: service, account: backendAccount)
    }

    var belongsToCurrentBackend: Bool {
        guard let storedBackend, !storedBackend.isEmpty else { return false }
        return storedBackend == currentBackend
    }

    var token: String? {
        guard belongsToCurrentBackend else {
            clear()
            return nil
        }
        return readFromKeychain(service: service, account: tokenAccount)
    }

    var userID: String? {
        guard belongsToCurrentBackend else {
            clear()
            return nil
        }
        return readFromKeychain(service: service, account: userIDAccount)
    }

    func save(token: String, userID: String) {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToken.isEmpty, !cleanUserID.isEmpty else {
            clear()
            return
        }

        // A new authenticated principal must never inherit process-local media
        // keys from the previous account/session, even when both accounts use
        // the same backend and media paths happen to collide.
        clearSessionEphemera()
        clearCurrentService()
        saveToKeychain(value: currentBackend, service: service, account: backendAccount)
        saveToKeychain(value: cleanToken, service: service, account: tokenAccount)
        saveToKeychain(value: cleanUserID, service: service, account: userIDAccount)
        removeLegacyDefaults()

        // The authenticated session is now complete and backend-bound. Security
        // services may safely publish the device's public E2EE identity.
        NotificationCenter.default.post(name: .gruSessionDidAuthenticate, object: nil)
    }

    func save(_ token: String) {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else { return }
        saveToKeychain(value: currentBackend, service: service, account: backendAccount)
        saveToKeychain(value: cleanToken, service: service, account: tokenAccount)
        removeLegacyDefaults()
    }

    func clear() {
        clearSessionEphemera()
        clearCurrentService()
        removeLegacyDefaults()
    }

    func purgeAllKnownSessions() {
        clearSessionEphemera()
        clearCurrentService()
        for legacyService in legacyServices {
            deleteFromKeychain(service: legacyService, account: tokenAccount)
            deleteFromKeychain(service: legacyService, account: userIDAccount)
            deleteFromKeychain(service: legacyService, account: backendAccount)
        }
        removeLegacyDefaults()
    }

    private func discardSessionIfBackendChanged() {
        guard let savedBackend = readFromKeychain(
            service: service,
            account: backendAccount
        ) else { return }

        guard savedBackend != currentBackend else { return }
        clearSessionEphemera()
        clearCurrentService()

        #if DEBUG
        print("🧹 GRU session discarded: backend changed from \(savedBackend) to \(currentBackend)")
        #endif
    }

    private func purgeLegacyStorage() {
        for legacyService in legacyServices {
            deleteFromKeychain(service: legacyService, account: tokenAccount)
            deleteFromKeychain(service: legacyService, account: userIDAccount)
            deleteFromKeychain(service: legacyService, account: backendAccount)
        }
        removeLegacyDefaults()
    }

    private func clearSessionEphemera() {
        GRUE2EEMediaKeyStore.shared.clear()
    }

    private func removeLegacyDefaults() {
        UserDefaults.standard.removeObject(forKey: legacyTokenKey)
        UserDefaults.standard.removeObject(forKey: legacyUserIDKey)
    }

    private func clearCurrentService() {
        deleteFromKeychain(service: service, account: tokenAccount)
        deleteFromKeychain(service: service, account: userIDAccount)
        deleteFromKeychain(service: service, account: backendAccount)
    }

    private func saveToKeychain(
        value: String,
        service: String,
        account: String
    ) {
        guard let data = value.data(using: .utf8) else { return }
        deleteFromKeychain(service: service, account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        #if DEBUG
        if status != errSecSuccess {
            print("❌ Keychain save failed for \(account): \(status)")
        }
        #endif
    }

    private func readFromKeychain(
        service: String,
        account: String
    ) -> String? {
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
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func deleteFromKeychain(
        service: String,
        account: String
    ) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

extension Notification.Name {
    static let gruSessionInvalidated = Notification.Name("gru.session.invalidated")
    static let gruSessionDidAuthenticate = Notification.Name("gru.session.did-authenticate")
}
