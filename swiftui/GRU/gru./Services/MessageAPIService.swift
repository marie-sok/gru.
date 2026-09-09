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

            if !message.text.isEmpty && !message.text.hasPrefix("🔒") {
                result.append(message)
                continue
            }

            do {
                let plaintext = try await E2EEAPIService.shared.decrypt(
                    message: message,
                    currentUserID: currentUserID,
                    token: token
                )

                if GRUE2EEMediaKeyStore.isMediaKeyPayload(plaintext) {
                    // A media key is cryptographic material, never user-visible
                    // message text. Even a malformed server DTO without remoteURL
                    // must fail closed instead of rendering/caching the raw key.
                    if let remoteURL = message.attachment?.remoteURL,
                       !remoteURL.isEmpty {
                        GRUE2EEMediaKeyStore.shared.register(
                            keyPayload: plaintext,
                            remoteURL: remoteURL
                        )
                    } else {
                        #if DEBUG
                        print("⚠️ E2EE media envelope has no remoteURL; key suppressed")
                        #endif
                    }

                    result.append(message.replacingText(""))
                } else {
                    result.append(message.replacingText(plaintext))
                }
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
        try await E2EEMediaService.shared.send(
            chatID: chatID,
            data: data,
            type: .photo,
            fileName: fileName,
            mimeType: "image/jpeg",
            width: width,
            height: height,
            replyToMessageID: replyToMessageID,
            token: token
        )
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
        try await E2EEMediaService.shared.send(
            chatID: chatID,
            data: data,
            type: .video,
            fileName: fileName,
            mimeType: mimeType,
            width: width,
            height: height,
            duration: duration,
            replyToMessageID: replyToMessageID,
            token: token
        )
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
        try await E2EEMediaService.shared.send(
            chatID: chatID,
            data: data,
            type: .videoNote,
            fileName: fileName,
            mimeType: mimeType,
            width: width,
            height: height,
            duration: duration,
            replyToMessageID: replyToMessageID,
            token: token
        )
    }

    func sendDocument(
        chatID: String,
        data: Data,
        fileName: String,
        mimeType: String = "application/octet-stream",
        replyToMessageID: String? = nil,
        token: String
    ) async throws -> ServerMessageDTO {
        try await E2EEMediaService.shared.send(
            chatID: chatID,
            data: data,
            type: .document,
            fileName: fileName,
            mimeType: mimeType,
            replyToMessageID: replyToMessageID,
            token: token
        )
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
        try await E2EEMediaService.shared.send(
            chatID: chatID,
            data: data,
            type: .audio,
            fileName: fileName,
            mimeType: mimeType,
            duration: duration,
            waveform: waveform,
            replyToMessageID: replyToMessageID,
            token: token
        )
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
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            throw MessageTransportError.emptyMessage
        }

        let chatID = await MainActor.run { () -> String? in
            ChatService.shared.chats.first(where: { chat in
                chat.messages.contains(where: { $0.serverID == messageID })
            })?.serverID
        }
        guard let chatID, !chatID.isEmpty else {
            throw MessageTransportError.missingChatContext
        }

        return try await E2EEAPIService.shared.editEncryptedText(
            messageID: messageID,
            chatID: chatID,
            plaintext: cleanText,
            token: token
        )
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
    case missingChatContext

    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Сообщение пустое."
        case .missingChatContext:
            return "Не удалось определить чат для защищённого сообщения."
        }
    }
}
