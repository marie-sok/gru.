import Foundation

extension E2EEAPIService {

    func editEncryptedText(
        messageID: String,
        chatID: String,
        plaintext: String,
        token: String
    ) async throws -> ServerMessageDTO {
        guard let senderID = TokenStorage.shared.userID,
              !senderID.isEmpty else {
            throw E2EEAPIError.missingCurrentUser
        }

        let chatsData = try await APIClient.shared.request(
            path: "/chats",
            method: "GET",
            token: token
        )
        let chats = try JSONCoding.decoder.decode([ServerChatDTO].self, from: chatsData)
        guard let chat = chats.first(where: { $0.id == chatID }) else {
            throw E2EEAPIError.chatNotFound
        }

        let receivers = chat.participants
            .map(\.id)
            .filter { !$0.isEmpty && $0 != senderID }
        guard receivers.count == 1 else {
            throw E2EEAPIError.directChatRequired
        }
        let receiverID = receivers[0]

        _ = try await publishIdentity(token: token)
        let recipient = try await identity(for: receiverID, token: token)

        switch GRUE2EE.shared.trustState(for: receiverID, identity: recipient.identity) {
        case .keyChanged:
            throw E2EEAPIError.recipientKeyChanged
        case .firstSeen:
            try GRUE2EE.shared.trust(identity: recipient.identity, for: receiverID)
        case .trusted:
            break
        }

        let clientMessageID = UUID().uuidString.lowercased()
        let envelope = try GRUE2EE.shared.encrypt(
            plaintext: plaintext,
            chatID: chatID,
            senderID: senderID,
            receiverID: receiverID,
            receiverIdentity: recipient.identity,
            clientMessageID: clientMessageID
        )

        try GRUE2EESentMessageStore.shared.save(
            plaintext: plaintext,
            userID: senderID,
            clientMessageID: envelope.clientMessageId
        )

        struct Request: Codable {
            let chatId: String
            let clientMessageId: String
            let encryptedPayload: String
            let encryptionVersion: String
            let senderEphemeralPublicKey: String
            let signature: String
            let senderKeyFingerprint: String
            let replyToMessageId: String?
        }

        let body = try JSONCoding.encoder.encode(
            Request(
                chatId: chatID,
                clientMessageId: envelope.clientMessageId,
                encryptedPayload: envelope.encryptedPayload,
                encryptionVersion: envelope.version,
                senderEphemeralPublicKey: envelope.senderEphemeralPublicKey,
                signature: envelope.signature,
                senderKeyFingerprint: envelope.senderKeyFingerprint,
                replyToMessageId: nil
            )
        )

        let data = try await APIClient.shared.request(
            path: "/messages/\(messageID)/e2ee",
            method: "PATCH",
            token: token,
            body: body
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }
}
