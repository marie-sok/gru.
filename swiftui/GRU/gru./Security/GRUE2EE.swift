import CryptoKit
import Foundation
import Security

struct GRUE2EEPublicIdentity: Codable, Equatable {
    let keyAgreementPublicKey: String
    let signingPublicKey: String

    var signingFingerprint: String {
        GRUE2EE.fingerprint(base64PublicKey: signingPublicKey)
    }
}

struct GRUE2EEEnvelope: Codable, Equatable {
    let version: String
    let clientMessageId: String
    let encryptedPayload: String
    let senderEphemeralPublicKey: String
    let signature: String
    let senderKeyFingerprint: String
}

enum GRUE2EETrustState: Equatable {
    case firstSeen
    case trusted
    case keyChanged(previous: String, current: String)
}

final class GRUE2EE {

    static let shared = GRUE2EE()
    static let protocolVersion = "gru-e2ee-v1"
    static let keyRotationVersion = "gru-e2ee-key-rotation-v1"

    private let keychainService = "sok.com.gru.e2ee.identity.v1"
    private let trustKeychainService = "sok.com.gru.e2ee.trust.v1"
    private let agreementAccount = "x25519-private"
    private let signingAccount = "ed25519-private"

    private init() {}

    func publicIdentity() throws -> GRUE2EEPublicIdentity {
        let agreement = try agreementPrivateKey()
        let signing = try signingPrivateKey()
        return GRUE2EEPublicIdentity(
            keyAgreementPublicKey: agreement.publicKey.rawRepresentation.base64EncodedString(),
            signingPublicKey: signing.publicKey.rawRepresentation.base64EncodedString()
        )
    }

    func encrypt(
        plaintext: String,
        chatID: String,
        senderID: String,
        receiverID: String,
        receiverIdentity: GRUE2EEPublicIdentity,
        clientMessageID: String = UUID().uuidString.lowercased()
    ) throws -> GRUE2EEEnvelope {
        guard UUID(uuidString: clientMessageID) != nil else {
            throw GRUE2EEError.invalidClientMessageID
        }
        guard let recipientAgreementData = Data(base64Encoded: receiverIdentity.keyAgreementPublicKey) else {
            throw GRUE2EEError.invalidPublicKey
        }

        let recipientPublicKey = try Curve25519.KeyAgreement.PublicKey(
            rawRepresentation: recipientAgreementData
        )
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let sharedSecret = try ephemeral.sharedSecretFromKeyAgreement(with: recipientPublicKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(Self.protocolVersion.utf8),
            sharedInfo: contextData(chatID: chatID, senderID: senderID, receiverID: receiverID),
            outputByteCount: 32
        )

        let sealedBox = try ChaChaPoly.seal(Data(plaintext.utf8), using: symmetricKey)
        let encryptedPayload = sealedBox.combined.base64EncodedString()
        let ephemeralPublicKey = ephemeral.publicKey.rawRepresentation.base64EncodedString()
        let fingerprint = try publicIdentity().signingFingerprint

        let canonical = canonicalEnvelopeData(
            version: Self.protocolVersion,
            chatID: chatID,
            senderID: senderID,
            receiverID: receiverID,
            clientMessageID: clientMessageID,
            ephemeralPublicKey: ephemeralPublicKey,
            encryptedPayload: encryptedPayload,
            senderKeyFingerprint: fingerprint
        )
        let signature = try signingPrivateKey().signature(for: canonical).base64EncodedString()

        return GRUE2EEEnvelope(
            version: Self.protocolVersion,
            clientMessageId: clientMessageID,
            encryptedPayload: encryptedPayload,
            senderEphemeralPublicKey: ephemeralPublicKey,
            signature: signature,
            senderKeyFingerprint: fingerprint
        )
    }

    func decrypt(
        envelope: GRUE2EEEnvelope,
        chatID: String,
        senderID: String,
        receiverID: String,
        senderIdentity: GRUE2EEPublicIdentity
    ) throws -> String {
        guard envelope.version == Self.protocolVersion else {
            throw GRUE2EEError.unsupportedVersion
        }
        guard UUID(uuidString: envelope.clientMessageId) != nil else {
            throw GRUE2EEError.invalidClientMessageID
        }

        let expectedFingerprint = senderIdentity.signingFingerprint
        guard constantTimeEqual(envelope.senderKeyFingerprint, expectedFingerprint) else {
            throw GRUE2EEError.identityMismatch
        }

        guard let signatureData = Data(base64Encoded: envelope.signature),
              let signingData = Data(base64Encoded: senderIdentity.signingPublicKey),
              let ephemeralData = Data(base64Encoded: envelope.senderEphemeralPublicKey),
              let encryptedData = Data(base64Encoded: envelope.encryptedPayload)
        else {
            throw GRUE2EEError.invalidEnvelope
        }

        let canonical = canonicalEnvelopeData(
            version: envelope.version,
            chatID: chatID,
            senderID: senderID,
            receiverID: receiverID,
            clientMessageID: envelope.clientMessageId,
            ephemeralPublicKey: envelope.senderEphemeralPublicKey,
            encryptedPayload: envelope.encryptedPayload,
            senderKeyFingerprint: envelope.senderKeyFingerprint
        )

        let senderSigningKey = try Curve25519.Signing.PublicKey(rawRepresentation: signingData)
        guard senderSigningKey.isValidSignature(signatureData, for: canonical) else {
            throw GRUE2EEError.invalidSignature
        }

        let ephemeralPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralData)
        let sharedSecret = try agreementPrivateKey().sharedSecretFromKeyAgreement(with: ephemeralPublicKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(Self.protocolVersion.utf8),
            sharedInfo: contextData(chatID: chatID, senderID: senderID, receiverID: receiverID),
            outputByteCount: 32
        )

        let box = try ChaChaPoly.SealedBox(combined: encryptedData)
        let plaintext = try ChaChaPoly.open(box, using: symmetricKey)
        guard let text = String(data: plaintext, encoding: .utf8) else {
            throw GRUE2EEError.invalidPlaintext
        }
        return text
    }

    func keyRotationSignature(
        userID: String,
        newIdentity: GRUE2EEPublicIdentity
    ) throws -> String {
        let canonical = Data([
            Self.keyRotationVersion,
            userID,
            newIdentity.keyAgreementPublicKey,
            newIdentity.signingPublicKey
        ].joined(separator: "|").utf8)
        return try signingPrivateKey().signature(for: canonical).base64EncodedString()
    }

    func trustState(for userID: String, identity: GRUE2EEPublicIdentity) -> GRUE2EETrustState {
        let current = identity.signingFingerprint
        guard let previous = loadTrustedFingerprint(for: userID) else {
            return .firstSeen
        }
        return constantTimeEqual(previous, current)
            ? .trusted
            : .keyChanged(previous: previous, current: current)
    }

    func trust(identity: GRUE2EEPublicIdentity, for userID: String) throws {
        try storeTrustedFingerprint(identity.signingFingerprint, for: userID)
        UserDefaults.standard.removeObject(forKey: legacyTrustKey(userID))
    }

    func clearTrust(for userID: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trustKeychainService,
            kSecAttrAccount as String: trustAccount(userID)
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: legacyTrustKey(userID))
    }

    static func fingerprint(base64PublicKey: String) -> String {
        guard let data = Data(base64Encoded: base64PublicKey) else { return "invalid" }
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func agreementPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        if let data = try loadPrivateKey(account: agreementAccount) {
            return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
        }
        let key = Curve25519.KeyAgreement.PrivateKey()
        try storePrivateKey(key.rawRepresentation, account: agreementAccount)
        return key
    }

    private func signingPrivateKey() throws -> Curve25519.Signing.PrivateKey {
        if let data = try loadPrivateKey(account: signingAccount) {
            return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
        }
        let key = Curve25519.Signing.PrivateKey()
        try storePrivateKey(key.rawRepresentation, account: signingAccount)
        return key
    }

    private func contextData(chatID: String, senderID: String, receiverID: String) -> Data {
        Data("\(Self.protocolVersion)|\(chatID)|\(senderID)|\(receiverID)".utf8)
    }

    private func canonicalEnvelopeData(
        version: String,
        chatID: String,
        senderID: String,
        receiverID: String,
        clientMessageID: String,
        ephemeralPublicKey: String,
        encryptedPayload: String,
        senderKeyFingerprint: String
    ) -> Data {
        Data([
            version,
            chatID,
            senderID,
            receiverID,
            clientMessageID,
            ephemeralPublicKey,
            encryptedPayload,
            senderKeyFingerprint
        ].joined(separator: "|").utf8)
    }

    private func loadTrustedFingerprint(for userID: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trustKeychainService,
            kSecAttrAccount as String: trustAccount(userID),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess,
           let data = item as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }

        if let legacy = UserDefaults.standard.string(forKey: legacyTrustKey(userID)) {
            try? storeTrustedFingerprint(legacy, for: userID)
            UserDefaults.standard.removeObject(forKey: legacyTrustKey(userID))
            return legacy
        }
        return nil
    }

    private func storeTrustedFingerprint(_ fingerprint: String, for userID: String) throws {
        let account = trustAccount(userID)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trustKeychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard let data = fingerprint.data(using: .utf8) else {
            throw GRUE2EEError.invalidFingerprint
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trustKeychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw GRUE2EEError.keychain(status)
        }
    }

    private func trustAccount(_ userID: String) -> String {
        "peer-" + userID
    }

    private func legacyTrustKey(_ userID: String) -> String {
        "gru.e2ee.trusted-signing-fingerprint.v1.\(userID)"
    }

    private func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        guard a.count == b.count else { return false }
        var result: UInt8 = 0
        for index in a.indices {
            result |= a[index] ^ b[index]
        }
        return result == 0
    }

    private func loadPrivateKey(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw GRUE2EEError.keychain(status)
        }
        return data
    }

    private func storePrivateKey(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem { return }
        guard status == errSecSuccess else {
            throw GRUE2EEError.keychain(status)
        }
    }
}

enum GRUE2EEError: Error {
    case invalidPublicKey
    case invalidEnvelope
    case invalidSignature
    case invalidPlaintext
    case invalidClientMessageID
    case invalidFingerprint
    case identityMismatch
    case unsupportedVersion
    case keychain(OSStatus)
}
