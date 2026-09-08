import CryptoKit
import Foundation
import Security

/// Encrypts sensitive local application data before it is written to disk.
///
/// The symmetric master key is generated on-device and stored in Keychain with
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, so it is neither synced via
/// iCloud Keychain nor usable while the device is locked.
final class GRUDataProtection {

    static let shared = GRUDataProtection()

    private let service = "sok.com.gru.local-data-protection"
    private let account = "cache-master-key-v1"
    private let magic = Data("GRUENC1".utf8)

    private init() {}

    func seal(_ plaintext: Data) throws -> Data {
        let key = try loadOrCreateKey()
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw GRUDataProtectionError.invalidCiphertext
        }
        return magic + combined
    }

    /// Opens encrypted payloads. Legacy plaintext files are returned as-is so
    /// they can be migrated transparently on the next successful save.
    func open(_ storedData: Data) throws -> Data {
        guard storedData.starts(with: magic) else {
            return storedData
        }

        let encrypted = storedData.dropFirst(magic.count)
        let box = try AES.GCM.SealedBox(combined: encrypted)
        return try AES.GCM.open(box, using: loadOrCreateKey())
    }

    func removeKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try loadKeyData() {
            guard existing.count == 32 else {
                throw GRUDataProtectionError.invalidKeyMaterial
            }
            return SymmetricKey(data: existing)
        }

        var bytes = Data(count: 32)
        let status = bytes.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, 32, base)
        }
        guard status == errSecSuccess else {
            throw GRUDataProtectionError.keyGenerationFailed(status)
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: bytes,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            throw GRUDataProtectionError.keychain(addStatus)
        }

        if addStatus == errSecDuplicateItem, let existing = try loadKeyData() {
            return SymmetricKey(data: existing)
        }

        return SymmetricKey(data: bytes)
    }

    private func loadKeyData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw GRUDataProtectionError.keychain(status)
        }
        guard let data = item as? Data else {
            throw GRUDataProtectionError.invalidKeyMaterial
        }
        return data
    }
}

enum GRUDataProtectionError: Error {
    case invalidCiphertext
    case invalidKeyMaterial
    case keyGenerationFailed(OSStatus)
    case keychain(OSStatus)
}
