import Foundation

struct ServerReplyReferenceDTO: Codable {
    let messageId: String
    let senderId: String
    let text: String
}

struct ServerMessageDTO: Codable {
    let id: String
    let chatId: String
    let senderId: String
    let receiverId: String?
    let text: String

    let e2eeClientMessageId: String?
    let encryptedPayload: String?
    let encryptionVersion: String?
    let senderEphemeralPublicKey: String?
    let senderRecoveryEncryptedPayload: String?
    let senderRecoveryEphemeralPublicKey: String?
    let e2eeSignature: String?
    let senderKeyFingerprint: String?
    let senderSigningPublicKey: String?
    let senderKeyAgreementPublicKey: String?

    let createdAt: Date
    let deliveredAt: Date?
    let readAt: Date?
    let deletedAt: Date?
    let isEdited: Bool?
    let editedAt: Date?
    let reaction: ReactionType?
    let replyTo: ServerReplyReferenceDTO?
    let attachment: Attachment?

    enum CodingKeys: String, CodingKey {
        case id, chatId, senderId, receiverId, text
        case e2eeClientMessageId, encryptedPayload, encryptionVersion
        case senderEphemeralPublicKey
        case senderRecoveryEncryptedPayload, senderRecoveryEphemeralPublicKey
        case e2eeSignature, senderKeyFingerprint
        case senderSigningPublicKey, senderKeyAgreementPublicKey
        case createdAt, deliveredAt, readAt, deletedAt, isEdited, editedAt
        case reaction, replyTo, attachment
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        let decodedID = try c.decode(String.self, forKey: .id)
        let decodedChatID = try c.decode(String.self, forKey: .chatId)
        let decodedSenderID = try c.decode(String.self, forKey: .senderId)
        let decodedReceiverID = try c.decodeIfPresent(String.self, forKey: .receiverId)
        let legacyText = try c.decodeIfPresent(String.self, forKey: .text) ?? ""

        let decodedClientID = try c.decodeIfPresent(String.self, forKey: .e2eeClientMessageId)
        let decodedPayload = try c.decodeIfPresent(String.self, forKey: .encryptedPayload)
        let decodedVersion = try c.decodeIfPresent(String.self, forKey: .encryptionVersion)
        let decodedEphemeral = try c.decodeIfPresent(String.self, forKey: .senderEphemeralPublicKey)
        let decodedRecoveryPayload = try c.decodeIfPresent(String.self, forKey: .senderRecoveryEncryptedPayload)
        let decodedRecoveryEphemeral = try c.decodeIfPresent(String.self, forKey: .senderRecoveryEphemeralPublicKey)
        let decodedSignature = try c.decodeIfPresent(String.self, forKey: .e2eeSignature)
        let decodedFingerprint = try c.decodeIfPresent(String.self, forKey: .senderKeyFingerprint)
        let decodedSigningKey = try c.decodeIfPresent(String.self, forKey: .senderSigningPublicKey)
        let decodedAgreementKey = try c.decodeIfPresent(String.self, forKey: .senderKeyAgreementPublicKey)
        let decodedAttachment = try c.decodeIfPresent(Attachment.self, forKey: .attachment)

        id = decodedID
        chatId = decodedChatID
        senderId = decodedSenderID
        receiverId = decodedReceiverID
        e2eeClientMessageId = decodedClientID
        encryptedPayload = decodedPayload
        encryptionVersion = decodedVersion
        senderEphemeralPublicKey = decodedEphemeral
        senderRecoveryEncryptedPayload = decodedRecoveryPayload
        senderRecoveryEphemeralPublicKey = decodedRecoveryEphemeral
        e2eeSignature = decodedSignature
        senderKeyFingerprint = decodedFingerprint
        senderSigningPublicKey = decodedSigningKey
        senderKeyAgreementPublicKey = decodedAgreementKey

        createdAt = try c.decode(Date.self, forKey: .createdAt)
        deliveredAt = try c.decodeIfPresent(Date.self, forKey: .deliveredAt)
        readAt = try c.decodeIfPresent(Date.self, forKey: .readAt)
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        isEdited = try c.decodeIfPresent(Bool.self, forKey: .isEdited)
        editedAt = try c.decodeIfPresent(Date.self, forKey: .editedAt)
        reaction = try c.decodeIfPresent(ReactionType.self, forKey: .reaction)
        replyTo = try c.decodeIfPresent(ServerReplyReferenceDTO.self, forKey: .replyTo)
        attachment = decodedAttachment

        if decodedVersion == GRUE2EEV2.protocolVersion,
           let clientID = decodedClientID,
           let payload = decodedPayload,
           let ephemeral = decodedEphemeral,
           let recoveryPayload = decodedRecoveryPayload,
           let recoveryEphemeral = decodedRecoveryEphemeral,
           let signature = decodedSignature,
           let fingerprint = decodedFingerprint {
            let envelope = GRUE2EEEnvelopeV2(
                version: GRUE2EEV2.protocolVersion,
                clientMessageId: clientID,
                encryptedPayload: payload,
                senderEphemeralPublicKey: ephemeral,
                senderRecoveryEncryptedPayload: recoveryPayload,
                senderRecoveryEphemeralPublicKey: recoveryEphemeral,
                signature: signature,
                senderKeyFingerprint: fingerprint
            )

            text = Self.resolveE2EEV2Text(
                envelope: envelope,
                serverMessageID: decodedID,
                chatID: decodedChatID,
                senderID: decodedSenderID,
                receiverID: decodedReceiverID,
                senderSigningPublicKey: decodedSigningKey,
                senderKeyAgreementPublicKey: decodedAgreementKey,
                attachmentRemoteURL: decodedAttachment?.remoteURL
            )
        } else if decodedVersion == GRUE2EE.protocolVersion,
                  let clientID = decodedClientID,
                  let payload = decodedPayload,
                  let ephemeral = decodedEphemeral,
                  let signature = decodedSignature,
                  let fingerprint = decodedFingerprint {
            let envelope = GRUE2EEEnvelope(
                version: GRUE2EE.protocolVersion,
                clientMessageId: clientID,
                encryptedPayload: payload,
                senderEphemeralPublicKey: ephemeral,
                signature: signature,
                senderKeyFingerprint: fingerprint
            )

            text = Self.resolveE2EEV1Text(
                envelope: envelope,
                serverMessageID: decodedID,
                chatID: decodedChatID,
                senderID: decodedSenderID,
                receiverID: decodedReceiverID,
                senderSigningPublicKey: decodedSigningKey,
                senderKeyAgreementPublicKey: decodedAgreementKey,
                attachmentRemoteURL: decodedAttachment?.remoteURL
            )
        } else if decodedVersion != nil {
            text = "🔒 Неподдерживаемая версия защищённого сообщения"
        } else {
            text = legacyText
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(chatId, forKey: .chatId)
        try c.encode(senderId, forKey: .senderId)
        try c.encodeIfPresent(receiverId, forKey: .receiverId)
        try c.encode(text, forKey: .text)
        try c.encodeIfPresent(e2eeClientMessageId, forKey: .e2eeClientMessageId)
        try c.encodeIfPresent(encryptedPayload, forKey: .encryptedPayload)
        try c.encodeIfPresent(encryptionVersion, forKey: .encryptionVersion)
        try c.encodeIfPresent(senderEphemeralPublicKey, forKey: .senderEphemeralPublicKey)
        try c.encodeIfPresent(senderRecoveryEncryptedPayload, forKey: .senderRecoveryEncryptedPayload)
        try c.encodeIfPresent(senderRecoveryEphemeralPublicKey, forKey: .senderRecoveryEphemeralPublicKey)
        try c.encodeIfPresent(e2eeSignature, forKey: .e2eeSignature)
        try c.encodeIfPresent(senderKeyFingerprint, forKey: .senderKeyFingerprint)
        try c.encodeIfPresent(senderSigningPublicKey, forKey: .senderSigningPublicKey)
        try c.encodeIfPresent(senderKeyAgreementPublicKey, forKey: .senderKeyAgreementPublicKey)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(deliveredAt, forKey: .deliveredAt)
        try c.encodeIfPresent(readAt, forKey: .readAt)
        try c.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try c.encodeIfPresent(isEdited, forKey: .isEdited)
        try c.encodeIfPresent(editedAt, forKey: .editedAt)
        try c.encodeIfPresent(reaction, forKey: .reaction)
        try c.encodeIfPresent(replyTo, forKey: .replyTo)
        try c.encodeIfPresent(attachment, forKey: .attachment)
    }

    var messageStatus: MessageStatus {
        if readAt != nil { return .read }
        if deliveredAt != nil { return .delivered }
        return .sent
    }

    var e2eeEnvelope: GRUE2EEEnvelope? {
        guard encryptionVersion == GRUE2EE.protocolVersion,
              let e2eeClientMessageId,
              let encryptedPayload,
              let senderEphemeralPublicKey,
              let e2eeSignature,
              let senderKeyFingerprint
        else { return nil }

        return GRUE2EEEnvelope(
            version: GRUE2EE.protocolVersion,
            clientMessageId: e2eeClientMessageId,
            encryptedPayload: encryptedPayload,
            senderEphemeralPublicKey: senderEphemeralPublicKey,
            signature: e2eeSignature,
            senderKeyFingerprint: senderKeyFingerprint
        )
    }

    var e2eeEnvelopeV2: GRUE2EEEnvelopeV2? {
        guard encryptionVersion == GRUE2EEV2.protocolVersion,
              let e2eeClientMessageId,
              let encryptedPayload,
              let senderEphemeralPublicKey,
              let senderRecoveryEncryptedPayload,
              let senderRecoveryEphemeralPublicKey,
              let e2eeSignature,
              let senderKeyFingerprint
        else { return nil }

        return GRUE2EEEnvelopeV2(
            version: GRUE2EEV2.protocolVersion,
            clientMessageId: e2eeClientMessageId,
            encryptedPayload: encryptedPayload,
            senderEphemeralPublicKey: senderEphemeralPublicKey,
            senderRecoveryEncryptedPayload: senderRecoveryEncryptedPayload,
            senderRecoveryEphemeralPublicKey: senderRecoveryEphemeralPublicKey,
            signature: e2eeSignature,
            senderKeyFingerprint: senderKeyFingerprint
        )
    }

    func replacingText(_ plaintext: String) -> ServerMessageDTO {
        ServerMessageDTO(
            id: id,
            chatId: chatId,
            senderId: senderId,
            receiverId: receiverId,
            text: plaintext,
            e2eeClientMessageId: e2eeClientMessageId,
            encryptedPayload: encryptedPayload,
            encryptionVersion: encryptionVersion,
            senderEphemeralPublicKey: senderEphemeralPublicKey,
            senderRecoveryEncryptedPayload: senderRecoveryEncryptedPayload,
            senderRecoveryEphemeralPublicKey: senderRecoveryEphemeralPublicKey,
            e2eeSignature: e2eeSignature,
            senderKeyFingerprint: senderKeyFingerprint,
            senderSigningPublicKey: senderSigningPublicKey,
            senderKeyAgreementPublicKey: senderKeyAgreementPublicKey,
            createdAt: createdAt,
            deliveredAt: deliveredAt,
            readAt: readAt,
            deletedAt: deletedAt,
            isEdited: isEdited,
            editedAt: editedAt,
            reaction: reaction,
            replyTo: replyTo,
            attachment: attachment
        )
    }

    private init(
        id: String,
        chatId: String,
        senderId: String,
        receiverId: String?,
        text: String,
        e2eeClientMessageId: String?,
        encryptedPayload: String?,
        encryptionVersion: String?,
        senderEphemeralPublicKey: String?,
        senderRecoveryEncryptedPayload: String?,
        senderRecoveryEphemeralPublicKey: String?,
        e2eeSignature: String?,
        senderKeyFingerprint: String?,
        senderSigningPublicKey: String?,
        senderKeyAgreementPublicKey: String?,
        createdAt: Date,
        deliveredAt: Date?,
        readAt: Date?,
        deletedAt: Date?,
        isEdited: Bool?,
        editedAt: Date?,
        reaction: ReactionType?,
        replyTo: ServerReplyReferenceDTO?,
        attachment: Attachment?
    ) {
        self.id = id
        self.chatId = chatId
        self.senderId = senderId
        self.receiverId = receiverId
        self.text = text
        self.e2eeClientMessageId = e2eeClientMessageId
        self.encryptedPayload = encryptedPayload
        self.encryptionVersion = encryptionVersion
        self.senderEphemeralPublicKey = senderEphemeralPublicKey
        self.senderRecoveryEncryptedPayload = senderRecoveryEncryptedPayload
        self.senderRecoveryEphemeralPublicKey = senderRecoveryEphemeralPublicKey
        self.e2eeSignature = e2eeSignature
        self.senderKeyFingerprint = senderKeyFingerprint
        self.senderSigningPublicKey = senderSigningPublicKey
        self.senderKeyAgreementPublicKey = senderKeyAgreementPublicKey
        self.createdAt = createdAt
        self.deliveredAt = deliveredAt
        self.readAt = readAt
        self.deletedAt = deletedAt
        self.isEdited = isEdited
        self.editedAt = editedAt
        self.reaction = reaction
        self.replyTo = replyTo
        self.attachment = attachment
    }

    private static func resolveE2EEV2Text(
        envelope: GRUE2EEEnvelopeV2,
        serverMessageID: String,
        chatID: String,
        senderID: String,
        receiverID: String?,
        senderSigningPublicKey: String?,
        senderKeyAgreementPublicKey: String?,
        attachmentRemoteURL: String?
    ) -> String {
        guard let currentUserID = TokenStorage.shared.userID else {
            return "🔒 Защищённое сообщение"
        }

        if senderID == currentUserID {
            if let cached = GRUE2EESentMessageStore.shared.plaintext(
                userID: currentUserID,
                clientMessageID: envelope.clientMessageId
            ) {
                return resolveVerifiedPayload(cached, attachmentRemoteURL: attachmentRemoteURL)
            }

            guard let receiverID, !receiverID.isEmpty else {
                return "🔒 Защищённая копия отправителя недоступна"
            }

            do {
                let currentIdentity = try GRUE2EE.shared.publicIdentity()
                if let signingKey = senderSigningPublicKey,
                   let agreementKey = senderKeyAgreementPublicKey {
                    let embedded = GRUE2EEPublicIdentity(
                        keyAgreementPublicKey: agreementKey,
                        signingPublicKey: signingKey
                    )
                    guard embedded == currentIdentity else {
                        return "🔒 Личность отправителя не совпадает"
                    }
                }

                let plaintext = try GRUE2EEV2.shared.decryptForSenderRecovery(
                    envelope: envelope,
                    chatID: chatID,
                    senderID: currentUserID,
                    receiverID: receiverID,
                    senderIdentity: currentIdentity
                )
                return resolveVerifiedPayload(plaintext, attachmentRemoteURL: attachmentRemoteURL)
            } catch {
                return "🔒 Не удалось восстановить исходящее сообщение"
            }
        }

        guard receiverID == currentUserID,
              let signingKey = senderSigningPublicKey,
              !signingKey.isEmpty,
              let agreementKey = senderKeyAgreementPublicKey,
              !agreementKey.isEmpty else {
            return "🔒 Защищённое сообщение"
        }

        let senderIdentity = GRUE2EEPublicIdentity(
            keyAgreementPublicKey: agreementKey,
            signingPublicKey: signingKey
        )
        let trustState = GRUE2EE.shared.trustState(for: senderID, identity: senderIdentity)
        if case .keyChanged = trustState {
            return "🔒 Ключ отправителя изменился"
        }

        do {
            let plaintext = try GRUE2EEV2.shared.decryptForRecipient(
                envelope: envelope,
                chatID: chatID,
                senderID: senderID,
                receiverID: currentUserID,
                senderIdentity: senderIdentity
            )

            if case .firstSeen = trustState {
                try GRUE2EE.shared.trust(identity: senderIdentity, for: senderID)
            }

            guard GRUE2EEReplayGuard.shared.accept(
                clientMessageID: envelope.clientMessageId,
                serverMessageID: serverMessageID
            ) else {
                return "🔒 Повтор защищённого сообщения заблокирован"
            }

            return resolveVerifiedPayload(plaintext, attachmentRemoteURL: attachmentRemoteURL)
        } catch {
            return "🔒 Не удалось расшифровать сообщение"
        }
    }

    private static func resolveE2EEV1Text(
        envelope: GRUE2EEEnvelope,
        serverMessageID: String,
        chatID: String,
        senderID: String,
        receiverID: String?,
        senderSigningPublicKey: String?,
        senderKeyAgreementPublicKey: String?,
        attachmentRemoteURL: String?
    ) -> String {
        guard let currentUserID = TokenStorage.shared.userID else {
            return "🔒 Защищённое сообщение"
        }

        if senderID == currentUserID {
            guard let plaintext = GRUE2EESentMessageStore.shared.plaintext(
                userID: currentUserID,
                clientMessageID: envelope.clientMessageId
            ) else {
                return "🔒 Исходящая история v1 доступна только на исходном устройстве"
            }
            return resolveVerifiedPayload(plaintext, attachmentRemoteURL: attachmentRemoteURL)
        }

        guard receiverID == currentUserID,
              let signingKey = senderSigningPublicKey,
              !signingKey.isEmpty,
              let agreementKey = senderKeyAgreementPublicKey,
              !agreementKey.isEmpty else {
            return "🔒 Защищённое сообщение"
        }

        let senderIdentity = GRUE2EEPublicIdentity(
            keyAgreementPublicKey: agreementKey,
            signingPublicKey: signingKey
        )
        let trustState = GRUE2EE.shared.trustState(for: senderID, identity: senderIdentity)

        if case .keyChanged = trustState {
            return "🔒 Ключ отправителя изменился"
        }

        do {
            let plaintext = try GRUE2EE.shared.decrypt(
                envelope: envelope,
                chatID: chatID,
                senderID: senderID,
                receiverID: currentUserID,
                senderIdentity: senderIdentity
            )

            if case .firstSeen = trustState {
                try GRUE2EE.shared.trust(identity: senderIdentity, for: senderID)
            }

            guard GRUE2EEReplayGuard.shared.accept(
                clientMessageID: envelope.clientMessageId,
                serverMessageID: serverMessageID
            ) else {
                return "🔒 Повтор защищённого сообщения заблокирован"
            }

            return resolveVerifiedPayload(plaintext, attachmentRemoteURL: attachmentRemoteURL)
        } catch {
            return "🔒 Не удалось расшифровать сообщение"
        }
    }

    private static func resolveVerifiedPayload(
        _ plaintext: String,
        attachmentRemoteURL: String?
    ) -> String {
        guard GRUE2EEMediaKeyStore.isMediaKeyPayload(plaintext) else {
            return plaintext
        }

        if let attachmentRemoteURL, !attachmentRemoteURL.isEmpty {
            GRUE2EEMediaKeyStore.shared.register(
                keyPayload: plaintext,
                remoteURL: attachmentRemoteURL
            )
        }

        return ""
    }
}
