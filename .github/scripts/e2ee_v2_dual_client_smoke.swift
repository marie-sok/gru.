import CryptoKit
import Foundation

private let version = "gru-e2ee-v2"
private let chatID = "ci-direct-chat"

private struct Copy {
    let ciphertext: String
    let ephemeralPublicKey: String
}

private struct IdentityBackup: Codable {
    let agreementPrivateKey: String
    let signingPrivateKey: String
}

private struct RestoredIdentity {
    let agreement: Curve25519.KeyAgreement.PrivateKey
    let signing: Curve25519.Signing.PrivateKey
}

private func fingerprint(_ signingPublicKey: Curve25519.Signing.PublicKey) -> String {
    SHA256.hash(data: signingPublicKey.rawRepresentation)
        .map { String(format: "%02x", $0) }
        .joined()
}

private func context(
    role: String,
    senderID: String,
    receiverID: String,
    clientID: String
) -> Data {
    Data([
        version,
        role,
        chatID,
        senderID,
        receiverID,
        clientID
    ].joined(separator: "|").utf8)
}

private func seal(
    plaintext: String,
    recipient: Curve25519.KeyAgreement.PublicKey,
    sharedInfo: Data
) throws -> Copy {
    let ephemeral = Curve25519.KeyAgreement.PrivateKey()
    let secret = try ephemeral.sharedSecretFromKeyAgreement(with: recipient)
    let key = secret.hkdfDerivedSymmetricKey(
        using: SHA256.self,
        salt: Data(version.utf8),
        sharedInfo: sharedInfo,
        outputByteCount: 32
    )
    let box = try ChaChaPoly.seal(Data(plaintext.utf8), using: key)
    return Copy(
        ciphertext: box.combined.base64EncodedString(),
        ephemeralPublicKey: ephemeral.publicKey.rawRepresentation.base64EncodedString()
    )
}

private func open(
    copy: Copy,
    privateKey: Curve25519.KeyAgreement.PrivateKey,
    sharedInfo: Data
) throws -> String {
    guard let ephemeralData = Data(base64Encoded: copy.ephemeralPublicKey),
          let encryptedData = Data(base64Encoded: copy.ciphertext) else {
        fatalError("invalid base64 in smoke vector")
    }

    let ephemeral = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralData)
    let secret = try privateKey.sharedSecretFromKeyAgreement(with: ephemeral)
    let key = secret.hkdfDerivedSymmetricKey(
        using: SHA256.self,
        salt: Data(version.utf8),
        sharedInfo: sharedInfo,
        outputByteCount: 32
    )
    let box = try ChaChaPoly.SealedBox(combined: encryptedData)
    let plaintext = try ChaChaPoly.open(box, using: key)
    guard let value = String(data: plaintext, encoding: .utf8) else {
        fatalError("decrypted smoke value is not UTF-8")
    }
    return value
}

/// Simulates the security-critical part of a reinstall/new-phone recovery:
/// the server keeps only this encrypted identity bundle; the recovery key is
/// separate, and the restored private keys must recreate the exact same public
/// identity rather than generating a replacement identity.
private func simulateReinstallRestore(
    agreement: Curve25519.KeyAgreement.PrivateKey,
    signing: Curve25519.Signing.PrivateKey
) throws -> RestoredIdentity {
    let recoveryKey = SymmetricKey(size: .bits256)
    let backup = IdentityBackup(
        agreementPrivateKey: agreement.rawRepresentation.base64EncodedString(),
        signingPrivateKey: signing.rawRepresentation.base64EncodedString()
    )
    let plaintext = try JSONEncoder().encode(backup)
    let encryptedBundle = try ChaChaPoly.seal(plaintext, using: recoveryKey).combined

    // A wrong recovery key must fail closed.
    do {
        _ = try ChaChaPoly.open(
            ChaChaPoly.SealedBox(combined: encryptedBundle),
            using: SymmetricKey(size: .bits256)
        )
        fatalError("wrong recovery key decrypted the identity backup")
    } catch {
        // Expected authentication failure.
    }

    let recoveredData = try ChaChaPoly.open(
        ChaChaPoly.SealedBox(combined: encryptedBundle),
        using: recoveryKey
    )
    let recovered = try JSONDecoder().decode(IdentityBackup.self, from: recoveredData)

    guard let agreementData = Data(base64Encoded: recovered.agreementPrivateKey),
          let signingData = Data(base64Encoded: recovered.signingPrivateKey) else {
        fatalError("invalid recovered identity encoding")
    }

    let restoredAgreement = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: agreementData)
    let restoredSigning = try Curve25519.Signing.PrivateKey(rawRepresentation: signingData)

    precondition(
        restoredAgreement.publicKey.rawRepresentation == agreement.publicKey.rawRepresentation,
        "reinstall restore changed the X25519 public identity"
    )
    precondition(
        restoredSigning.publicKey.rawRepresentation == signing.publicKey.rawRepresentation,
        "reinstall restore changed the Ed25519 public identity"
    )

    return RestoredIdentity(
        agreement: restoredAgreement,
        signing: restoredSigning
    )
}

private func runDirection(
    senderID: String,
    receiverID: String,
    senderAgreement: Curve25519.KeyAgreement.PrivateKey,
    receiverAgreement: Curve25519.KeyAgreement.PrivateKey,
    senderSigning: Curve25519.Signing.PrivateKey,
    plaintext: String
) throws {
    let clientID = UUID().uuidString.lowercased()

    let recipient = try seal(
        plaintext: plaintext,
        recipient: receiverAgreement.publicKey,
        sharedInfo: context(
            role: "recipient",
            senderID: senderID,
            receiverID: receiverID,
            clientID: clientID
        )
    )

    let recovery = try seal(
        plaintext: plaintext,
        recipient: senderAgreement.publicKey,
        sharedInfo: context(
            role: "sender-recovery",
            senderID: senderID,
            receiverID: receiverID,
            clientID: clientID
        )
    )

    let fp = fingerprint(senderSigning.publicKey)
    let canonical = Data([
        version,
        chatID,
        senderID,
        receiverID,
        clientID,
        recipient.ephemeralPublicKey,
        recipient.ciphertext,
        recovery.ephemeralPublicKey,
        recovery.ciphertext,
        fp
    ].joined(separator: "|").utf8)

    let signature = try senderSigning.signature(for: canonical)
    precondition(
        senderSigning.publicKey.isValidSignature(signature, for: canonical),
        "valid v2 envelope signature was rejected"
    )

    let recipientPlaintext = try open(
        copy: recipient,
        privateKey: receiverAgreement,
        sharedInfo: context(
            role: "recipient",
            senderID: senderID,
            receiverID: receiverID,
            clientID: clientID
        )
    )
    precondition(recipientPlaintext == plaintext, "recipient could not decrypt v2 message")

    // Simulate deleting the installation and restoring the same long-lived
    // identity from an opaque encrypted recovery bundle.
    let restoredSender = try simulateReinstallRestore(
        agreement: senderAgreement,
        signing: senderSigning
    )
    precondition(
        restoredSender.signing.publicKey.isValidSignature(signature, for: canonical),
        "restored signing identity does not verify historical envelope"
    )

    let senderRecoveredPlaintext = try open(
        copy: recovery,
        privateKey: restoredSender.agreement,
        sharedInfo: context(
            role: "sender-recovery",
            senderID: senderID,
            receiverID: receiverID,
            clientID: clientID
        )
    )
    precondition(
        senderRecoveredPlaintext == plaintext,
        "restored device could not decrypt historical outgoing message"
    )

    let tamperedCanonical = Data([
        version,
        chatID,
        senderID,
        receiverID,
        clientID,
        recipient.ephemeralPublicKey,
        recipient.ciphertext + "tampered",
        recovery.ephemeralPublicKey,
        recovery.ciphertext,
        fp
    ].joined(separator: "|").utf8)
    precondition(
        !restoredSender.signing.publicKey.isValidSignature(signature, for: tamperedCanonical),
        "tampered v2 envelope signature was accepted"
    )
}

let aliceAgreement = Curve25519.KeyAgreement.PrivateKey()
let bobAgreement = Curve25519.KeyAgreement.PrivateKey()
let aliceSigning = Curve25519.Signing.PrivateKey()
let bobSigning = Curve25519.Signing.PrivateKey()

try runDirection(
    senderID: "alice",
    receiverID: "bob",
    senderAgreement: aliceAgreement,
    receiverAgreement: bobAgreement,
    senderSigning: aliceSigning,
    plaintext: "A → B encrypted text"
)

try runDirection(
    senderID: "bob",
    receiverID: "alice",
    senderAgreement: bobAgreement,
    receiverAgreement: aliceAgreement,
    senderSigning: bobSigning,
    plaintext: "B → A encrypted text"
)

print("PASS: two-client v2 + reinstall identity continuity + sender-history recovery")
