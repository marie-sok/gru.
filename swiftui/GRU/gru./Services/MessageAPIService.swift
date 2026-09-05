import Foundation

final class MessageAPIService {

    static let shared =
        MessageAPIService()

    private init() {}

    // MARK: ========================================
    // MARK: GET MESSAGES
    // MARK: ========================================

    func getMessages(
        chatID: String,
        token: String
    ) async throws -> [ServerMessageDTO] {

        let data =
            try await
                APIClient.shared.request(
                    path:
                        "/chats/\(chatID)/messages",
                    method:
                        "GET",
                    token:
                        token
                )

        return try
            JSONCoding.decoder.decode(
                [ServerMessageDTO].self,
                from:
                    data
            )
    }

    // MARK: ========================================
    // MARK: SEND MESSAGE
    // MARK: ========================================

    func sendMessage(
        chatID: String,
        text: String,
        replyToMessageID: String? = nil,
        token: String
    ) async throws -> ServerMessageDTO {

        let cleanText =
            text.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        let request =
            SendMessageDTO(
                chatId:
                    chatID,
                text:
                    cleanText,
                replyToMessageId:
                    replyToMessageID
            )

        let body =
            try JSONCoding.encoder.encode(
                request
            )

        let data =
            try await
                APIClient.shared.request(
                    path:
                        "/messages",
                    method:
                        "POST",
                    token:
                        token,
                    body:
                        body
                )

        return try
            JSONCoding.decoder.decode(
                ServerMessageDTO.self,
                from:
                    data
            )
    }

    // MARK: ========================================
    // MARK: SEND PHOTO
    // MARK: ========================================

    func sendPhoto(
        chatID: String,
        data: Data,
        fileName: String,
        width: Double,
        height: Double,
        replyToMessageID: String? = nil,
        token: String
    ) async throws -> ServerMessageDTO {

        var fields: [String: String] = [
            "chatId":
                chatID,
            "width":
                String(width),
            "height":
                String(height)
        ]

        if let replyToMessageID,
           !replyToMessageID.isEmpty {

            fields[
                "replyToMessageId"
            ] =
                replyToMessageID
        }

        let responseData =
            try await
                APIClient.shared
                .uploadMultipart(
                    path:
                        "/messages/photo",
                    token:
                        token,
                    fields:
                        fields,
                    fileFieldName:
                        "file",
                    fileName:
                        fileName,
                    mimeType:
                        "image/jpeg",
                    fileData:
                        data
                )

        return try
            JSONCoding.decoder.decode(
                ServerMessageDTO.self,
                from:
                    responseData
            )
    }

    // MARK: ========================================
    // MARK: SEND VIDEO
    // MARK: ========================================

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

        var fields: [String: String] = ["chatId": chatID]

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

        return try JSONCoding.decoder.decode(
            ServerMessageDTO.self,
            from: responseData
        )
    }

    // MARK: ========================================
    // MARK: SEND VIDEO MESSAGE
    // MARK: ========================================

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

        var fields: [String: String] = [
            "chatId":
                chatID
        ]

        if let width,
           width > 0 {
            fields["width"] =
                String(width)
        }

        if let height,
           height > 0 {
            fields["height"] =
                String(height)
        }

        if let duration,
           duration > 0 {
            fields["duration"] =
                String(duration)
        }

        if let replyToMessageID,
           !replyToMessageID.isEmpty {
            fields["replyToMessageId"] =
                replyToMessageID
        }

        let responseData =
            try await
                APIClient.shared
                .uploadMultipart(
                    path:
                        "/messages/video-note",
                    token:
                        token,
                    fields:
                        fields,
                    fileFieldName:
                        "file",
                    fileName:
                        fileName,
                    mimeType:
                        mimeType,
                    fileData:
                        data
                )

        return try
            JSONCoding.decoder.decode(
                ServerMessageDTO.self,
                from:
                    responseData
            )
    }

    // MARK: ========================================
    // MARK: SEND DOCUMENT
    // MARK: ========================================

    func sendDocument(
        chatID: String,
        data: Data,
        fileName: String,
        mimeType: String = "application/octet-stream",
        replyToMessageID: String? = nil,
        token: String
    ) async throws -> ServerMessageDTO {
        var fields: [String: String] = ["chatId": chatID]

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

        return try JSONCoding.decoder.decode(
            ServerMessageDTO.self,
            from: responseData
        )
    }

    // MARK: ========================================
    // MARK: SEND VOICE AUDIO
    // MARK: ========================================

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

        var fields: [String: String] = [
            "chatId": chatID
        ]

        if let duration, duration > 0 {
            fields["duration"] = String(duration)
        }

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

        return try JSONCoding.decoder.decode(
            ServerMessageDTO.self,
            from: responseData
        )
    }

    // MARK: ========================================
    // MARK: DELIVERED
    // MARK: ========================================

    func markDelivered(
        messageID: String,
        token: String
    ) async throws -> ServerMessageDTO {

        let data =
            try await
                APIClient.shared.request(
                    path:
                        "/messages/\(messageID)/delivered",
                    method:
                        "POST",
                    token:
                        token
                )

        return try
            JSONCoding.decoder.decode(
                ServerMessageDTO.self,
                from:
                    data
            )
    }

    // MARK: ========================================
    // MARK: READ MESSAGE
    // MARK: ========================================

    func markRead(
        messageID: String,
        token: String
    ) async throws -> ServerMessageDTO {

        let data =
            try await
                APIClient.shared.request(
                    path:
                        "/messages/\(messageID)/read",
                    method:
                        "POST",
                    token:
                        token
                )

        return try
            JSONCoding.decoder.decode(
                ServerMessageDTO.self,
                from:
                    data
            )
    }

    // MARK: ========================================
    // MARK: READ CHAT
    // MARK: ========================================

    func markChatRead(
        chatID: String,
        token: String
    ) async throws -> [ServerMessageDTO] {

        let data =
            try await
                APIClient.shared.request(
                    path:
                        "/chats/\(chatID)/read",
                    method:
                        "POST",
                    token:
                        token
                )

        return try
            JSONCoding.decoder.decode(
                [ServerMessageDTO].self,
                from:
                    data
            )
    }

    // MARK: ========================================
    // MARK: SET REACTION
    // MARK: ========================================

    func setReaction(
        messageID: String,
        reaction: ReactionType,
        token: String
    ) async throws -> ServerMessageDTO {

        let request =
            SetReactionDTO(
                reaction:
                    reaction.rawValue
            )

        let body =
            try JSONCoding.encoder.encode(
                request
            )

        let data =
            try await
                APIClient.shared.request(
                    path:
                        "/messages/\(messageID)/reaction",
                    method:
                        "POST",
                    token:
                        token,
                    body:
                        body
                )

        return try
            JSONCoding.decoder.decode(
                ServerMessageDTO.self,
                from:
                    data
            )
    }

    // MARK: ========================================
    // MARK: REMOVE REACTION
    // MARK: ========================================

    func removeReaction(
        messageID: String,
        token: String
    ) async throws -> ServerMessageDTO {

        let data =
            try await
                APIClient.shared.request(
                    path:
                        "/messages/\(messageID)/reaction",
                    method:
                        "DELETE",
                    token:
                        token
                )

        return try
            JSONCoding.decoder.decode(
                ServerMessageDTO.self,
                from:
                    data
            )
    }

    // MARK: ========================================
    // MARK: DELETE MESSAGE
    // MARK: ========================================

    func deleteMessage(
        messageID: String,
        token: String
    ) async throws -> ServerMessageDTO {

        let data =
            try await
                APIClient.shared.request(
                    path:
                        "/messages/\(messageID)",
                    method:
                        "DELETE",
                    token:
                        token
                )

        return try
            JSONCoding.decoder.decode(
                ServerMessageDTO.self,
                from:
                    data
            )
    }

    // MARK: ========================================
    // MARK: EDIT MESSAGE
    // MARK: ========================================

    func editMessage(
        messageID: String,
        text: String,
        token: String
    ) async throws -> ServerMessageDTO {

        struct EditMessageRequest: Codable {
            let text: String
        }

        let body = try JSONCoding.encoder.encode(
            EditMessageRequest(text: text)
        )

        let data = try await APIClient.shared.request(
            path: "/messages/\(messageID)",
            method: "PATCH",
            token: token,
            body: body
        )

        return try JSONCoding.decoder.decode(
            ServerMessageDTO.self,
            from: data
        )
    }

    // MARK: ========================================
    // MARK: DELETE MESSAGE FOR ME
    // MARK: ========================================

    /// Hides a server message only for the current account. The peer's copy
    /// remains untouched; local storage still hides it immediately while the
    /// request is in flight.
    func deleteMessageForMe(
        messageID: String,
        token: String
    ) async throws -> ServerMessageDTO {

        let data = try await APIClient.shared.request(
            path: "/messages/\(messageID)/me",
            method: "DELETE",
            token: token
        )

        return try JSONCoding.decoder.decode(
            ServerMessageDTO.self,
            from: data
        )
    }
}

// MARK: ========================================
// MARK: SET REACTION DTO
// MARK: ========================================

private struct SetReactionDTO: Codable {

    let reaction: String
}
