import CryptoKit
import Foundation
import Security

struct GRUE2EERecoveryStatus: Equatable {
    let hasLocalIdentity: Bool
    let hasSynchronizedRecoveryKey: Bool
}

struct GRUE2EERecoveryBackupDTO: Codable {
    let version: String
    let encryptedBundle: String
    let signature: String
    let updatedAt: Date?
}

struct GRUE2EERecoveryCreatedBackup {
    /// Human-exportable fallback. The server never receives this value.
    let recoveryCode: String
    let updatedAt: Date?
}

enum GRUE2EERecoveryError: LocalizedError {
    case missingUserID
    case localIdentityMissing
    case invalidPrivateKey
    case recoveryKeyUnavailable
    case invalidRecoveryCode
    case invalidBackup
    case identityMismatch
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingUserID:
            return "Не найден ID текущего пользователя."
        case .localIdentityMissing:
            return "Локальная E2EE-личность отсутствует."
        case .invalidPrivateKey:
            return "Ключ E2EE повреждён."
        case .recoveryKeyUnavailable:
            return "Ключ восстановления не найден в iCloud Keychain. Введите recovery code."
        case .invalidRecoveryCode:
            return "Recovery code повреждён или введён неверно."
        case .invalidBackup:
            return "Резервная копия E2EE повреждена или не прошла проверку."
        case .identityMismatch:
            return "Восстановленный ключ не совпадает с E2EE-личностью аккаунта на сервере."
        case .keychain(let status):
            return "Ошибка Keychain: \(status)."
        }
    }
}

/// Cross-device identity recovery for E2EE.
///
/// Security boundary:
/// - the GRU backend stores only ChaChaPoly ciphertext;
/// - the 256-bit recovery key is either synchronized by Apple's Keychain or
///   held by the user as a recovery code;
/// - the backend never receives the recovery key or private identity keys;
/// - backup replacement is signed by the currently registered Ed25519 key.
final class GRUE2EERecoveryService {

    static let shared = GRUE2EERecoveryService()

    static let recoveryVersion = "gru-e2ee-recovery-v1"
    private static let backupSignatureVersion = "gru-e2ee-recovery-backup-v1"

    private let identityService = "sok.com.gru.e2ee.identity.v1"
    private let agreementAccount = "x25519-private"
    private let signingAccount = "ed25519-private"

    private let recoveryKeyService = "sok.com.gru.e2ee.recovery.key.v1"

    private struct PrivateIdentityBackup: Codable {
        let version: String
        let userID: String
        let keyAgreementPrivateKey: String
        let signingPrivateKey: String
        let createdAt: Date
    }

    private struct PutRequest: Codable {
        let version: String
        let encryptedBundle: String
        let signature: String
    }

    private init() {}

    func status(userID: String) -> GRUE2EERecoveryStatus {
        GRUE2EERecoveryStatus(
            hasLocalIdentity: hasLocalIdentity(),
            hasSynchronizedRecoveryKey: (try? loadSynchronizedRecoveryKey(userID: userID)) != nil
        )
    }

    /// Creates/refreshes the encrypted identity backup and returns a fallback
    /// recovery code. The caller should show the code once and ask the user to
    /// store it outside GRU.
    func createOrRefreshBackup(
        token: String,
        userID: String
    ) async throws -> GRUE2EERecoveryCreatedBackup {
        let cleanUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUserID.isEmpty else { throw GRUE2EERecoveryError.missingUserID }

        let agreementData = try loadIdentityKey(account: agreementAccount)
        let signingData = try loadIdentityKey(account: signingAccount)
        guard let agreementData, let signingData else {
            throw GRUE2EERecoveryError.localIdentityMissing
        }
        try validatePrivateKeys(agreementData: agreementData, signingData: signingData)

        let recoveryKeyData = try loadOrCreateSynchronizedRecoveryKey(userID: cleanUserID)
        let recoveryKey = SymmetricKey(data: recoveryKeyData)

        let backup = PrivateIdentityBackup(
            version: Self.recoveryVersion,
            userID: cleanUserID,
            keyAgreementPrivateKey: agreementData.base64EncodedString(),
            signingPrivateKey: signingData.base64EncodedString(),
            createdAt: Date()
        )
        let plaintext = try JSONCoding.encoder.encode(backup)
        let sealed = try ChaChaPoly.seal(plaintext, using: recoveryKey).combined
        let encryptedBundle = sealed.base64EncodedString()

        let canonical = Data([
            Self.backupSignatureVersion,
            cleanUserID,
            Self.recoveryVersion,
            encryptedBundle
        ].joined(separator: "|").utf8)
        let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: signingData)
        let signature = try signingKey.signature(for: canonical).base64EncodedString()

        let body = try JSONCoding.encoder.encode(
            PutRequest(
                version: Self.recoveryVersion,
                encryptedBundle: encryptedBundle,
                signature: signature
            )
        )

        let data = try await APIClient.shared.request(
            path: "/e2ee/recovery/me",
            method: "PUT",
            token: token,
            body: body
        )
        let response = try JSONCoding.decoder.decode(GRUE2EERecoveryBackupDTO.self, from: data)

        return GRUE2EERecoveryCreatedBackup(
            recoveryCode: Self.encodeRecoveryCode(recoveryKeyData),
            updatedAt: response.updatedAt
        )
    }

    /// Restores the exact same long-lived X25519 + Ed25519 identity on a new
    /// installation. This preserves peer fingerprints and decryptability of
    /// recipient-side historical ciphertext.
    ///
    /// If iCloud Keychain does not contain the recovery key, pass the user's
    /// exported recovery code.
    func restoreIdentity(
        token: String,
        userID: String,
        recoveryCode: String? = nil
    ) async throws {
        let cleanUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUserID.isEmpty else { throw GRUE2EERecoveryError.missingUserID }

        let data = try await APIClient.shared.request(
            path: "/e2ee/recovery/me",
            method: "GET",
            token: token
        )
        let remote = try JSONCoding.decoder.decode(GRUE2EERecoveryBackupDTO.self, from: data)
        guard remote.version == Self.recoveryVersion,
              let encryptedData = Data(base64Encoded: remote.encryptedBundle)
        else {
            throw GRUE2EERecoveryError.invalidBackup
        }

        let recoveryKeyData: Data
        if let code = recoveryCode?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty {
            guard let decoded = Self.decodeRecoveryCode(code), decoded.count == 32 else {
                throw GRUE2EERecoveryError.invalidRecoveryCode
            }
            recoveryKeyData = decoded
            try storeSynchronizedRecoveryKey(decoded, userID: cleanUserID)
        } else if let synchronized = try loadSynchronizedRecoveryKey(userID: cleanUserID) {
            recoveryKeyData = synchronized
        } else {
            throw GRUE2EERecoveryError.recoveryKeyUnavailable
        }

        let box: ChaChaPoly.SealedBox
        do {
            box = try ChaChaPoly.SealedBox(combined: encryptedData)
        } catch {
            throw GRUE2EERecoveryError.invalidBackup
        }

        let plaintext: Data
        do {
            plaintext = try ChaChaPoly.open(box, using: SymmetricKey(data: recoveryKeyData))
        } catch {
            throw GRUE2EERecoveryError.invalidRecoveryCode
        }

        guard let backup = try? JSONCoding.decoder.decode(PrivateIdentityBackup.self, from: plaintext),
              backup.version == Self.recoveryVersion,
              backup.userID == cleanUserID,
              let agreementData = Data(base64Encoded: backup.keyAgreementPrivateKey),
              let signingData = Data(base64Encoded: backup.signingPrivateKey)
        else {
            throw GRUE2EERecoveryError.invalidBackup
        }

        try validatePrivateKeys(agreementData: agreementData, signingData: signingData)

        // Verify against the server's already pinned public identity before we
        // overwrite any local key material. A wrong-account backup must fail
        // closed rather than silently becoming a new identity.
        let server = try await E2EEAPIService.shared.identity(for: cleanUserID, token: token)
        let agreementKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: agreementData)
        let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: signingData)
        let recoveredIdentity = GRUE2EEPublicIdentity(
            keyAgreementPublicKey: agreementKey.publicKey.rawRepresentation.base64EncodedString(),
            signingPublicKey: signingKey.publicKey.rawRepresentation.base64EncodedString()
        )
        guard recoveredIdentity == server.identity else {
            throw GRUE2EERecoveryError.identityMismatch
        }

        try replaceIdentityKey(agreementData, account: agreementAccount)
        try replaceIdentityKey(signingData, account: signingAccount)
    }

    func exportedRecoveryCode(userID: String) throws -> String {
        guard let key = try loadSynchronizedRecoveryKey(userID: userID) else {
            throw GRUE2EERecoveryError.recoveryKeyUnavailable
        }
        return Self.encodeRecoveryCode(key)
    }

    private func hasLocalIdentity() -> Bool {
        ((try? loadIdentityKey(account: agreementAccount)) ?? nil) != nil
            && ((try? loadIdentityKey(account: signingAccount)) ?? nil) != nil
    }

    private func validatePrivateKeys(agreementData: Data, signingData: Data) throws {
        guard agreementData.count == 32, signingData.count == 32 else {
            throw GRUE2EERecoveryError.invalidPrivateKey
        }
        do {
            _ = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: agreementData)
            _ = try Curve25519.Signing.PrivateKey(rawRepresentation: signingData)
        } catch {
            throw GRUE2EERecoveryError.invalidPrivateKey
        }
    }

    private func loadIdentityKey(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: identityService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw GRUE2EERecoveryError.keychain(status)
        }
        return data
    }

    private func replaceIdentityKey(_ data: Data, account: String) throws {
        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: identityService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(identityQuery as CFDictionary)

        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: identityService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw GRUE2EERecoveryError.keychain(status)
        }
    }

    private func loadOrCreateSynchronizedRecoveryKey(userID: String) throws -> Data {
        if let existing = try loadSynchronizedRecoveryKey(userID: userID) {
            return existing
        }
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        try storeSynchronizedRecoveryKey(key, userID: userID)
        return key
    }

    private func loadSynchronizedRecoveryKey(userID: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: recoveryKeyService,
            kSecAttrAccount as String: recoveryAccount(userID),
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data, data.count == 32 else {
            throw GRUE2EERecoveryError.keychain(status)
        }
        return data
    }

    private func storeSynchronizedRecoveryKey(_ data: Data, userID: String) throws {
        guard data.count == 32 else { throw GRUE2EERecoveryError.invalidRecoveryCode }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: recoveryKeyService,
            kSecAttrAccount as String: recoveryAccount(userID),
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: recoveryKeyService,
            kSecAttrAccount as String: recoveryAccount(userID),
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw GRUE2EERecoveryError.keychain(status)
        }
    }

    private func recoveryAccount(_ userID: String) -> String {
        "user-" + userID
    }

    private static func encodeRecoveryCode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decodeRecoveryCode(_ raw: String) -> Data? {
        var value = raw
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = value.count % 4
        if remainder != 0 {
            value += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: value)
    }
}
