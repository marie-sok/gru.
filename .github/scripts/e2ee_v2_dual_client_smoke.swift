import CryptoKit
import Foundation

private let version = "gru-e2ee-v2"
private let chatID = "ci-direct-chat"

private struct Copy {
    let ciphertext: String
    let ephemeralPublicKey: String
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

    let senderRecoveredPlaintext = try open(
        copy: recovery,
        privateKey: senderAgreement,
        sharedInfo: context(
            role: "sender-recovery",
            senderID: senderID,
            receiverID: receiverID,
            clientID: clientID
        )
    )
    precondition(senderRecoveredPlaintext == plaintext, "sender recovery copy could not decrypt")

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
        !senderSigning.publicKey.isValidSignature(signature, for: tamperedCanonical),
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

print("PASS: gru-e2ee-v2 two-client recipient + sender-recovery smoke")
