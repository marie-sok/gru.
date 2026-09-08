import Foundation

final class MessageAPIService {
    static let shared = MessageAPIService()
    private init() {}

    func getMessages(chatID: String, token: String) async throws -> [ServerMessageDTO] {
        let data = try await APIClient.shared.request(
            path: "/chats/\(chatID)/messages", method: "GET", token: token
        )
        let messages = try JSONCoding.decoder.decode([ServerMessageDTO].self, from: data)
        guard let currentUserID = TokenStorage.shared.userID else { return messages }

        var result: [ServerMessageDTO] = []
        result.reserveCapacity(messages.count)
        for message in messages {
            guard message.e2eeEnvelope != nil else {
                result.append(message)
                continue
            }

            if message.senderId == currentUserID {
                // v1 recipient envelope cannot be decrypted by its sender.
                // Preserve the protected local-cache copy when available.
                if let localText = cachedPlaintext(serverMessageID: message.id, chatID: chatID),
                   !localText.isEmpty {
                    result.append(message.replacingText(localText))
                } else {
                    result.append(message.replacingText("🔒 Зашифрованное сообщение"))
                }
                continue
            }

            let plaintext = try await E2EEAPIService.shared.decrypt(
                message: message,
                currentUserID: currentUserID,
                token: token
            )
            result.append(message.replacingText(plaintext))
        }
        return result
    }

    func sendMessage(
        chatID: String,
        text: String,
        replyToMessageID: String? = nil,
        token: String
    ) async throws -> ServerMessageDTO {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { throw MessageTransportError.emptyMessage }
        guard let senderID = TokenStorage.shared.userID,
              let receiverID = receiverID(for: chatID, senderID: senderID)
        else { throw MessageTransportError.missingDirectChatIdentity }

        // Text is E2EE by default. There is deliberately no plaintext fallback:
        // if key setup fails, the send fails closed instead of leaking content.
        return try await E2EEAPIService.shared.sendEncryptedText(
            chatID: chatID,
            senderID: senderID,
            receiverID: receiverID,
            plaintext: cleanText,
            replyToMessageID: replyToMessageID,
            token: token
        )
    }

    private func receiverID(for chatID: String, senderID: String) -> String? {
        guard let chat = ChatService.shared.chats.first(where: { $0.serverID == chatID }) else { return nil }
        let peers = chat.users.compactMap(\.serverID).filter { $0 != senderID }
        return Set(peers).count == 1 ? peers.first : nil
    }

    private func cachedPlaintext(serverMessageID: String, chatID: String) -> String? {
        ChatService.shared.chats
            .first(where: { $0.serverID == chatID })?
            .messages
            .first(where: { $0.serverID == serverMessageID })?
            .text
    }

    func sendPhoto(
        chatID: String, data: Data, fileName: String, width: Double, height: Double,
        replyToMessageID: String? = nil, token: String
    ) async throws -> ServerMessageDTO {
        var fields = ["chatId": chatID, "width": String(width), "height": String(height)]
        if let replyToMessageID, !replyToMessageID.isEmpty { fields["replyToMessageId"] = replyToMessageID }
        let responseData = try await APIClient.shared.uploadMultipart(
            path: "/messages/photo", token: token, fields: fields, fileFieldName: "file",
            fileName: fileName, mimeType: "image/jpeg", fileData: data
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: responseData)
    }

    func sendVideo(
        chatID: String, data: Data, fileName: String, mimeType: String,
        width: Double? = nil, height: Double? = nil, duration: Double? = nil,
        replyToMessageID: String? = nil, token: String
    ) async throws -> ServerMessageDTO {
        var fields = ["chatId": chatID]
        if let width, width > 0 { fields["width"] = String(width) }
        if let height, height > 0 { fields["height"] = String(height) }
        if let duration, duration > 0 { fields["duration"] = String(duration) }
        if let replyToMessageID, !replyToMessageID.isEmpty { fields["replyToMessageId"] = replyToMessageID }
        let responseData = try await APIClient.shared.uploadMultipart(
            path: "/messages/video", token: token, fields: fields, fileFieldName: "file",
            fileName: fileName, mimeType: mimeType, fileData: data
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: responseData)
    }

    func sendVideoNote(
        chatID: String, data: Data, fileName: String, mimeType: String,
        width: Double? = nil, height: Double? = nil, duration: Double? = nil,
        replyToMessageID: String? = nil, token: String
    ) async throws -> ServerMessageDTO {
        var fields = ["chatId": chatID]
        if let width, width > 0 { fields["width"] = String(width) }
        if let height, height > 0 { fields["height"] = String(height) }
        if let duration, duration > 0 { fields["duration"] = String(duration) }
        if let replyToMessageID, !replyToMessageID.isEmpty { fields["replyToMessageId"] = replyToMessageID }
        let responseData = try await APIClient.shared.uploadMultipart(
            path: "/messages/video-note", token: token, fields: fields, fileFieldName: "file",
            fileName: fileName, mimeType: mimeType, fileData: data
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: responseData)
    }

    func sendDocument(
        chatID: String, data: Data, fileName: String, mimeType: String = "application/octet-stream",
        replyToMessageID: String? = nil, token: String
    ) async throws -> ServerMessageDTO {
        var fields = ["chatId": chatID]
        if let replyToMessageID, !replyToMessageID.isEmpty { fields["replyToMessageId"] = replyToMessageID }
        let responseData = try await APIClient.shared.uploadMultipart(
            path: "/messages/document", token: token, fields: fields, fileFieldName: "file",
            fileName: fileName, mimeType: mimeType, fileData: data
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: responseData)
    }

    func sendAudio(
        chatID: String, data: Data, fileName: String, mimeType: String = "audio/mp4",
        duration: Double? = nil, waveform: [Double]? = nil,
        replyToMessageID: String? = nil, token: String
    ) async throws -> ServerMessageDTO {
        var fields = ["chatId": chatID]
        if let duration, duration > 0 { fields["duration"] = String(duration) }
        if let waveform, !waveform.isEmpty {
            fields["waveform"] = waveform.prefix(64)
                .map { String(format: "%.4f", max(0.04, min(1.0, $0))) }.joined(separator: ",")
        }
        if let replyToMessageID, !replyToMessageID.isEmpty { fields["replyToMessageId"] = replyToMessageID }
        let responseData = try await APIClient.shared.uploadMultipart(
            path: "/messages/audio", token: token, fields: fields, fileFieldName: "file",
            fileName: fileName, mimeType: mimeType, fileData: data
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: responseData)
    }

    func markDelivered(messageID: String, token: String) async throws -> ServerMessageDTO {
        let data = try await APIClient.shared.request(path: "/messages/\(messageID)/delivered", method: "POST", token: token)
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func markRead(messageID: String, token: String) async throws -> ServerMessageDTO {
        let data = try await APIClient.shared.request(path: "/messages/\(messageID)/read", method: "POST", token: token)
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func markChatRead(chatID: String, token: String) async throws -> [ServerMessageDTO] {
        let data = try await APIClient.shared.request(path: "/chats/\(chatID)/read", method: "POST", token: token)
        return try JSONCoding.decoder.decode([ServerMessageDTO].self, from: data)
    }

    func setReaction(messageID: String, reaction: ReactionType, token: String) async throws -> ServerMessageDTO {
        let body = try JSONCoding.encoder.encode(SetReactionDTO(reaction: reaction.rawValue))
        let data = try await APIClient.shared.request(
            path: "/messages/\(messageID)/reaction", method: "POST", token: token, body: body
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func removeReaction(messageID: String, token: String) async throws -> ServerMessageDTO {
        let data = try await APIClient.shared.request(path: "/messages/\(messageID)/reaction", method: "DELETE", token: token)
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func deleteMessage(messageID: String, token: String) async throws -> ServerMessageDTO {
        let data = try await APIClient.shared.request(path: "/messages/\(messageID)", method: "DELETE", token: token)
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func editMessage(messageID: String, text: String, token: String) async throws -> ServerMessageDTO {
        struct EditMessageRequest: Codable { let text: String }
        let body = try JSONCoding.encoder.encode(EditMessageRequest(text: text))
        let data = try await APIClient.shared.request(path: "/messages/\(messageID)", method: "PATCH", token: token, body: body)
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func deleteMessageForMe(messageID: String, token: String) async throws -> ServerMessageDTO {
        let data = try await APIClient.shared.request(path: "/messages/\(messageID)/me", method: "DELETE", token: token)
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }
}

private struct SetReactionDTO: Codable { let reaction: String }

enum MessageTransportError: Error {
    case emptyMessage
    case missingDirectChatIdentity
}
