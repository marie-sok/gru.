import Foundation

final class MessageAPIService {
    static let shared = MessageAPIService()
    private init() {}

    func getMessages(chatID: String, token: String) async throws -> [ServerMessageDTO] {
        let data = try await APIClient.shared.request(
            path: "/chats/\(chatID)/messages",
            method: "GET",
            token: token
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

            // New envelopes are decrypted synchronously by ServerMessageDTO so
            // REST history and WebSocket realtime share exactly the same path.
            if !message.text.isEmpty && !message.text.hasPrefix("🔒") {
                result.append(message)
                continue
            }

            // Backward compatibility for E2EE records created before the
            // sender signing key was embedded in each server envelope.
            do {
                let plaintext = try await E2EEAPIService.shared.decrypt(
                    message: message,
                    currentUserID: currentUserID,
                    token: token
                )
                result.append(message.replacingText(plaintext))
            } catch {
                #if DEBUG
                print("⚠️ E2EE history decrypt failed:", error.localizedDescription)
                #endif
                result.append(message.replacingText("🔒 Не удалось расшифровать сообщение"))
            }
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
        guard !cleanText.isEmpty else {
            throw MessageTransportError.emptyMessage
        }

        // Text is E2EE by default. There is deliberately no plaintext fallback:
        // if identity/trust/encryption setup fails, sending fails closed.
        return try await E2EEAPIService.shared.sendEncryptedText(
            chatID: chatID,
            plaintext: cleanText,
            replyToMessageID: replyToMessageID,
            token: token
        )
    }

    func sendPhoto(
        chatID: String,
        data: Data,
        fileName: String,
        width: Double,
        height: Double,
        replyToMessageID: String? = nil,
        token: String
    ) async throws -> ServerMessageDTO {
        var fields = [
            "chatId": chatID,
            "width": String(width),
            "height": String(height)
        ]
        if let replyToMessageID, !replyToMessageID.isEmpty {
            fields["replyToMessageId"] = replyToMessageID
        }
        let responseData = try await APIClient.shared.uploadMultipart(
            path: "/messages/photo",
            token: token,
            fields: fields,
            fileFieldName: "file",
            fileName: fileName,
            mimeType: "image/jpeg",
            fileData: data
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: responseData)
    }

    func sendVideo(
        chatID: String,
        data: Data,
        fileName: String,
        mimeType: String,
        width: Double? = nil,
        height: Double? = nil,
        duration: Double? = nil,
        replyToMessageID: String? = nil,
        token: String
    ) async throws -> ServerMessageDTO {
        var fields = ["chatId": chatID]
        if let width, width > 0 { fields["width"] = String(width) }
        if let height, height > 0 { fields["height"] = String(height) }
        if let duration, duration > 0 { fields["duration"] = String(duration) }
        if let replyToMessageID, !replyToMessageID.isEmpty {
            fields["replyToMessageId"] = replyToMessageID
        }
        let responseData = try await APIClient.shared.uploadMultipart(
            path: "/messages/video",
            token: token,
            fields: fields,
            fileFieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: data
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: responseData)
    }

    func sendVideoNote(
        chatID: String,
        data: Data,
        fileName: String,
        mimeType: String,
        width: Double? = nil,
        height: Double? = nil,
        duration: Double? = nil,
        replyToMessageID: String? = nil,
        token: String
    ) async throws -> ServerMessageDTO {
        var fields = ["chatId": chatID]
        if let width, width > 0 { fields["width"] = String(width) }
        if let height, height > 0 { fields["height"] = String(height) }
        if let duration, duration > 0 { fields["duration"] = String(duration) }
        if let replyToMessageID, !replyToMessageID.isEmpty {
            fields["replyToMessageId"] = replyToMessageID
        }
        let responseData = try await APIClient.shared.uploadMultipart(
            path: "/messages/video-note",
            token: token,
            fields: fields,
            fileFieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: data
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: responseData)
    }

    func sendDocument(
        chatID: String,
        data: Data,
        fileName: String,
        mimeType: String = "application/octet-stream",
        replyToMessageID: String? = nil,
        token: String
    ) async throws -> ServerMessageDTO {
        var fields = ["chatId": chatID]
        if let replyToMessageID, !replyToMessageID.isEmpty {
            fields["replyToMessageId"] = replyToMessageID
        }
        let responseData = try await APIClient.shared.uploadMultipart(
            path: "/messages/document",
            token: token,
            fields: fields,
            fileFieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: data
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: responseData)
    }

    func sendAudio(
        chatID: String,
        data: Data,
        fileName: String,
        mimeType: String = "audio/mp4",
        duration: Double? = nil,
        waveform: [Double]? = nil,
        replyToMessageID: String? = nil,
        token: String
    ) async throws -> ServerMessageDTO {
        var fields = ["chatId": chatID]
        if let duration, duration > 0 { fields["duration"] = String(duration) }
        if let waveform, !waveform.isEmpty {
            fields["waveform"] = waveform
                .prefix(64)
                .map { String(format: "%.4f", max(0.04, min(1.0, $0))) }
                .joined(separator: ",")
        }
        if let replyToMessageID, !replyToMessageID.isEmpty {
            fields["replyToMessageId"] = replyToMessageID
        }
        let responseData = try await APIClient.shared.uploadMultipart(
            path: "/messages/audio",
            token: token,
            fields: fields,
            fileFieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: data
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: responseData)
    }

    func markDelivered(messageID: String, token: String) async throws -> ServerMessageDTO {
        let data = try await APIClient.shared.request(
            path: "/messages/\(messageID)/delivered",
            method: "POST",
            token: token
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func markRead(messageID: String, token: String) async throws -> ServerMessageDTO {
        let data = try await APIClient.shared.request(
            path: "/messages/\(messageID)/read",
            method: "POST",
            token: token
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func markChatRead(chatID: String, token: String) async throws -> [ServerMessageDTO] {
        let data = try await APIClient.shared.request(
            path: "/chats/\(chatID)/read",
            method: "POST",
            token: token
        )
        return try JSONCoding.decoder.decode([ServerMessageDTO].self, from: data)
    }

    func setReaction(
        messageID: String,
        reaction: ReactionType,
        token: String
    ) async throws -> ServerMessageDTO {
        let body = try JSONCoding.encoder.encode(
            SetReactionDTO(reaction: reaction.rawValue)
        )
        let data = try await APIClient.shared.request(
            path: "/messages/\(messageID)/reaction",
            method: "POST",
            token: token,
            body: body
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func removeReaction(messageID: String, token: String) async throws -> ServerMessageDTO {
        let data = try await APIClient.shared.request(
            path: "/messages/\(messageID)/reaction",
            method: "DELETE",
            token: token
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func deleteMessage(messageID: String, token: String) async throws -> ServerMessageDTO {
        let data = try await APIClient.shared.request(
            path: "/messages/\(messageID)",
            method: "DELETE",
            token: token
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func editMessage(messageID: String, text: String, token: String) async throws -> ServerMessageDTO {
        struct EditMessageRequest: Codable { let text: String }
        let body = try JSONCoding.encoder.encode(EditMessageRequest(text: text))
        let data = try await APIClient.shared.request(
            path: "/messages/\(messageID)",
            method: "PATCH",
            token: token,
            body: body
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func deleteMessageForMe(messageID: String, token: String) async throws -> ServerMessageDTO {
        let data = try await APIClient.shared.request(
            path: "/messages/\(messageID)/me",
            method: "DELETE",
            token: token
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }
}

private struct SetReactionDTO: Codable {
    let reaction: String
}

enum MessageTransportError: LocalizedError {
    case emptyMessage

    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Сообщение пустое."
        }
    }
}
