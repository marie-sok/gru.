import CryptoKit
import Foundation
import Security

struct GRUE2EEEnvelopeV2: Codable, Equatable {
    let version: String
    let clientMessageId: String
    let encryptedPayload: String
    let senderEphemeralPublicKey: String
    let senderRecoveryEncryptedPayload: String
    let senderRecoveryEphemeralPublicKey: String
    let signature: String
    let senderKeyFingerprint: String
}

/// E2EE v2 keeps the v1 recipient ciphertext and adds a second ciphertext for
/// the sender's own long-lived X25519 identity. After a legitimate identity
/// restore, a replacement device can decrypt both incoming and outgoing
/// history while the backend still stores ciphertext only.
final class GRUE2EEV2 {

    static let shared = GRUE2EEV2()
    static let protocolVersion = "gru-e2ee-v2"

    private let identityService = "sok.com.gru.e2ee.identity.v1"
    private let agreementAccount = "x25519-private"
    private let signingAccount = "ed25519-private"

    private init() {}

    func encrypt(
        plaintext: String,
        chatID: String,
        senderID: String,
        receiverID: String,
        receiverIdentity: GRUE2EEPublicIdentity,
        clientMessageID: String = UUID().uuidString.lowercased()
    ) throws -> GRUE2EEEnvelopeV2 {
        guard UUID(uuidString: clientMessageID) != nil else {
            throw GRUE2EEError.invalidClientMessageID
        }

        let agreementPrivate = try currentAgreementPrivateKey()
        let signingPrivate = try currentSigningPrivateKey()

        guard let recipientAgreementData = Data(base64Encoded: receiverIdentity.keyAgreementPublicKey),
              recipientAgreementData.count == 32 else {
            throw GRUE2EEError.invalidPublicKey
        }
        let recipientPublicKey = try Curve25519.KeyAgreement.PublicKey(
            rawRepresentation: recipientAgreementData
        )

        let recipientCopy = try seal(
            plaintext: plaintext,
            recipientPublicKey: recipientPublicKey,
            context: recipientContext(
                chatID: chatID,
                senderID: senderID,
                receiverID: receiverID,
                clientMessageID: clientMessageID
            )
        )

        let senderCopy = try seal(
            plaintext: plaintext,
            recipientPublicKey: agreementPrivate.publicKey,
            context: senderRecoveryContext(
                chatID: chatID,
                senderID: senderID,
                receiverID: receiverID,
                clientMessageID: clientMessageID
            )
        )

        let fingerprint = GRUE2EE.fingerprint(
            base64PublicKey: signingPrivate.publicKey.rawRepresentation.base64EncodedString()
        )
        guard fingerprint != "invalid" else {
            throw GRUE2EEError.invalidFingerprint
        }

        let canonical = canonicalData(
            chatID: chatID,
            senderID: senderID,
            receiverID: receiverID,
            clientMessageID: clientMessageID,
            recipientEphemeralPublicKey: recipientCopy.ephemeralPublicKey,
            recipientEncryptedPayload: recipientCopy.encryptedPayload,
            senderRecoveryEphemeralPublicKey: senderCopy.ephemeralPublicKey,
            senderRecoveryEncryptedPayload: senderCopy.encryptedPayload,
            senderKeyFingerprint: fingerprint
        )
        let signature = try signingPrivate.signature(for: canonical).base64EncodedString()

        return GRUE2EEEnvelopeV2(
            version: Self.protocolVersion,
            clientMessageId: clientMessageID,
            encryptedPayload: recipientCopy.encryptedPayload,
            senderEphemeralPublicKey: recipientCopy.ephemeralPublicKey,
            senderRecoveryEncryptedPayload: senderCopy.encryptedPayload,
            senderRecoveryEphemeralPublicKey: senderCopy.ephemeralPublicKey,
            signature: signature,
            senderKeyFingerprint: fingerprint
        )
    }

    func decryptForRecipient(
        envelope: GRUE2EEEnvelopeV2,
        chatID: String,
        senderID: String,
        receiverID: String,
        senderIdentity: GRUE2EEPublicIdentity
    ) throws -> String {
        try verify(
            envelope: envelope,
            chatID: chatID,
            senderID: senderID,
            receiverID: receiverID,
            senderIdentity: senderIdentity
        )

        return try open(
            encryptedPayload: envelope.encryptedPayload,
            ephemeralPublicKey: envelope.senderEphemeralPublicKey,
            privateKey: currentAgreementPrivateKey(),
            context: recipientContext(
                chatID: chatID,
                senderID: senderID,
                receiverID: receiverID,
                clientMessageID: envelope.clientMessageId
            )
        )
    }

    func decryptForSenderRecovery(
        envelope: GRUE2EEEnvelopeV2,
        chatID: String,
        senderID: String,
        receiverID: String,
        senderIdentity: GRUE2EEPublicIdentity
    ) throws -> String {
        try verify(
            envelope: envelope,
            chatID: chatID,
            senderID: senderID,
            receiverID: receiverID,
            senderIdentity: senderIdentity
        )

        return try open(
            encryptedPayload: envelope.senderRecoveryEncryptedPayload,
            ephemeralPublicKey: envelope.senderRecoveryEphemeralPublicKey,
            privateKey: currentAgreementPrivateKey(),
            context: senderRecoveryContext(
                chatID: chatID,
                senderID: senderID,
                receiverID: receiverID,
                clientMessageID: envelope.clientMessageId
            )
        )
    }

    private func verify(
        envelope: GRUE2EEEnvelopeV2,
        chatID: String,
        senderID: String,
        receiverID: String,
        senderIdentity: GRUE2EEPublicIdentity
    ) throws {
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
              signatureData.count == 64,
              let signingData = Data(base64Encoded: senderIdentity.signingPublicKey),
              signingData.count == 32,
              validEnvelopeField(envelope.senderEphemeralPublicKey, exactBytes: 32),
              validEnvelopeField(envelope.senderRecoveryEphemeralPublicKey, exactBytes: 32),
              Data(base64Encoded: envelope.encryptedPayload) != nil,
              Data(base64Encoded: envelope.senderRecoveryEncryptedPayload) != nil else {
            throw GRUE2EEError.invalidEnvelope
        }

        let canonical = canonicalData(
            chatID: chatID,
            senderID: senderID,
            receiverID: receiverID,
            clientMessageID: envelope.clientMessageId,
            recipientEphemeralPublicKey: envelope.senderEphemeralPublicKey,
            recipientEncryptedPayload: envelope.encryptedPayload,
            senderRecoveryEphemeralPublicKey: envelope.senderRecoveryEphemeralPublicKey,
            senderRecoveryEncryptedPayload: envelope.senderRecoveryEncryptedPayload,
            senderKeyFingerprint: envelope.senderKeyFingerprint
        )

        let signingKey = try Curve25519.Signing.PublicKey(rawRepresentation: signingData)
        guard signingKey.isValidSignature(signatureData, for: canonical) else {
            throw GRUE2EEError.invalidSignature
        }
    }

    private func seal(
        plaintext: String,
        recipientPublicKey: Curve25519.KeyAgreement.PublicKey,
        context: Data
    ) throws -> (encryptedPayload: String, ephemeralPublicKey: String) {
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let sharedSecret = try ephemeral.sharedSecretFromKeyAgreement(with: recipientPublicKey)
        let key = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(Self.protocolVersion.utf8),
            sharedInfo: context,
            outputByteCount: 32
        )
        let box = try ChaChaPoly.seal(Data(plaintext.utf8), using: key)
        return (
            box.combined.base64EncodedString(),
            ephemeral.publicKey.rawRepresentation.base64EncodedString()
        )
    }

    private func open(
        encryptedPayload: String,
        ephemeralPublicKey: String,
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        context: Data
    ) throws -> String {
        guard let encryptedData = Data(base64Encoded: encryptedPayload),
              let ephemeralData = Data(base64Encoded: ephemeralPublicKey),
              ephemeralData.count == 32 else {
            throw GRUE2EEError.invalidEnvelope
        }

        let ephemeral = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralData)
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: ephemeral)
        let key = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(Self.protocolVersion.utf8),
            sharedInfo: context,
            outputByteCount: 32
        )
        let box = try ChaChaPoly.SealedBox(combined: encryptedData)
        let plaintext = try ChaChaPoly.open(box, using: key)
        guard let value = String(data: plaintext, encoding: .utf8) else {
            throw GRUE2EEError.invalidPlaintext
        }
        return value
    }

    private func canonicalData(
        chatID: String,
        senderID: String,
        receiverID: String,
        clientMessageID: String,
        recipientEphemeralPublicKey: String,
        recipientEncryptedPayload: String,
        senderRecoveryEphemeralPublicKey: String,
        senderRecoveryEncryptedPayload: String,
        senderKeyFingerprint: String
    ) -> Data {
        Data([
            Self.protocolVersion,
            chatID,
            senderID,
            receiverID,
            clientMessageID,
            recipientEphemeralPublicKey,
            recipientEncryptedPayload,
            senderRecoveryEphemeralPublicKey,
            senderRecoveryEncryptedPayload,
            senderKeyFingerprint
        ].joined(separator: "|").utf8)
    }

    private func recipientContext(
        chatID: String,
        senderID: String,
        receiverID: String,
        clientMessageID: String
    ) -> Data {
        Data([
            Self.protocolVersion,
            "recipient",
            chatID,
            senderID,
            receiverID,
            clientMessageID
        ].joined(separator: "|").utf8)
    }

    private func senderRecoveryContext(
        chatID: String,
        senderID: String,
        receiverID: String,
        clientMessageID: String
    ) -> Data {
        Data([
            Self.protocolVersion,
            "sender-recovery",
            chatID,
            senderID,
            receiverID,
            clientMessageID
        ].joined(separator: "|").utf8)
    }

    private func currentAgreementPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        guard let data = try loadPrivateKey(account: agreementAccount), data.count == 32 else {
            throw GRUE2EEError.invalidPublicKey
        }
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    private func currentSigningPrivateKey() throws -> Curve25519.Signing.PrivateKey {
        guard let data = try loadPrivateKey(account: signingAccount), data.count == 32 else {
            throw GRUE2EEError.invalidPublicKey
        }
        return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }

    private func loadPrivateKey(account: String) throws -> Data? {
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
            throw GRUE2EEError.keychain(status)
        }
        return data
    }

    private func validEnvelopeField(_ value: String, exactBytes: Int) -> Bool {
        guard let data = Data(base64Encoded: value) else { return false }
        return data.count == exactBytes
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
}
