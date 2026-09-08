import Foundation

struct E2EEKeyDTO: Codable {
    let userId: String
    let keyAgreementPublicKey: String
    let signingPublicKey: String
    let updatedAt: Date?

    var identity: GRUE2EEPublicIdentity {
        GRUE2EEPublicIdentity(
            keyAgreementPublicKey: keyAgreementPublicKey,
            signingPublicKey: signingPublicKey
        )
    }
}

final class E2EEAPIService {

    static let shared = E2EEAPIService()

    private init() {}

    func publishIdentity(token: String) async throws -> E2EEKeyDTO {
        let identity = try GRUE2EE.shared.publicIdentity()
        struct Request: Codable {
            let keyAgreementPublicKey: String
            let signingPublicKey: String
        }

        let body = try JSONCoding.encoder.encode(
            Request(
                keyAgreementPublicKey: identity.keyAgreementPublicKey,
                signingPublicKey: identity.signingPublicKey
            )
        )

        let data = try await APIClient.shared.request(
            path: "/e2ee/keys/me",
            method: "PUT",
            token: token,
            body: body
        )
        return try JSONCoding.decoder.decode(E2EEKeyDTO.self, from: data)
    }

    func identity(for userID: String, token: String) async throws -> E2EEKeyDTO {
        let data = try await APIClient.shared.request(
            path: "/e2ee/keys/\(userID)",
            method: "GET",
            token: token
        )
        return try JSONCoding.decoder.decode(E2EEKeyDTO.self, from: data)
    }

    func sendEncryptedText(
        chatID: String,
        senderID: String,
        receiverID: String,
        plaintext: String,
        clientMessageID: String = UUID().uuidString.lowercased(),
        token: String
    ) async throws -> ServerMessageDTO {
        let recipient = try await identity(for: receiverID, token: token)

        switch GRUE2EE.shared.trustState(for: receiverID, identity: recipient.identity) {
        case .keyChanged:
            throw E2EEAPIError.recipientKeyChanged
        case .firstSeen:
            throw E2EEAPIError.recipientKeyNotTrusted(recipient.identity.signingFingerprint)
        case .trusted:
            break
        }

        let envelope = try GRUE2EE.shared.encrypt(
            plaintext: plaintext,
            chatID: chatID,
            senderID: senderID,
            receiverID: receiverID,
            receiverIdentity: recipient.identity,
            clientMessageID: clientMessageID
        )

        struct Request: Codable {
            let chatId: String
            let clientMessageId: String
            let encryptedPayload: String
            let encryptionVersion: String
            let senderEphemeralPublicKey: String
            let signature: String
            let senderKeyFingerprint: String
        }

        let body = try JSONCoding.encoder.encode(
            Request(
                chatId: chatID,
                clientMessageId: envelope.clientMessageId,
                encryptedPayload: envelope.encryptedPayload,
                encryptionVersion: envelope.version,
                senderEphemeralPublicKey: envelope.senderEphemeralPublicKey,
                signature: envelope.signature,
                senderKeyFingerprint: envelope.senderKeyFingerprint
            )
        )

        let data = try await APIClient.shared.request(
            path: "/messages/e2ee",
            method: "POST",
            token: token,
            body: body
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func decrypt(
        message: ServerMessageDTO,
        currentUserID: String,
        token: String
    ) async throws -> String {
        guard let envelope = message.e2eeEnvelope else {
            return message.text
        }

        guard GRUE2EEReplayGuard.shared.accept(
            clientMessageID: envelope.clientMessageId,
            serverMessageID: message.id
        ) else {
            throw E2EEAPIError.replayedEnvelope
        }

        let sender = try await identity(for: message.senderId, token: token)
        switch GRUE2EE.shared.trustState(for: message.senderId, identity: sender.identity) {
        case .keyChanged:
            throw E2EEAPIError.senderKeyChanged
        case .firstSeen:
            throw E2EEAPIError.senderKeyNotTrusted(sender.identity.signingFingerprint)
        case .trusted:
            break
        }

        return try GRUE2EE.shared.decrypt(
            envelope: envelope,
            chatID: message.chatId,
            senderID: message.senderId,
            receiverID: currentUserID,
            senderIdentity: sender.identity
        )
    }
}

enum E2EEAPIError: Error {
    case recipientKeyChanged
    case senderKeyChanged
    case recipientKeyNotTrusted(String)
    case senderKeyNotTrusted(String)
    case replayedEnvelope
}
