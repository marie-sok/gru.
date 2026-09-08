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
    let e2eeSignature: String?
    let senderKeyFingerprint: String?

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
        case senderEphemeralPublicKey, e2eeSignature, senderKeyFingerprint
        case createdAt, deliveredAt, readAt, deletedAt, isEdited, editedAt
        case reaction, replyTo, attachment
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        chatId = try c.decode(String.self, forKey: .chatId)
        senderId = try c.decode(String.self, forKey: .senderId)
        receiverId = try c.decodeIfPresent(String.self, forKey: .receiverId)

        // E2EE records deliberately carry no server-readable plaintext.
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""

        e2eeClientMessageId = try c.decodeIfPresent(String.self, forKey: .e2eeClientMessageId)
        encryptedPayload = try c.decodeIfPresent(String.self, forKey: .encryptedPayload)
        encryptionVersion = try c.decodeIfPresent(String.self, forKey: .encryptionVersion)
        senderEphemeralPublicKey = try c.decodeIfPresent(String.self, forKey: .senderEphemeralPublicKey)
        e2eeSignature = try c.decodeIfPresent(String.self, forKey: .e2eeSignature)
        senderKeyFingerprint = try c.decodeIfPresent(String.self, forKey: .senderKeyFingerprint)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        deliveredAt = try c.decodeIfPresent(Date.self, forKey: .deliveredAt)
        readAt = try c.decodeIfPresent(Date.self, forKey: .readAt)
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        isEdited = try c.decodeIfPresent(Bool.self, forKey: .isEdited)
        editedAt = try c.decodeIfPresent(Date.self, forKey: .editedAt)
        reaction = try c.decodeIfPresent(ReactionType.self, forKey: .reaction)
        replyTo = try c.decodeIfPresent(ServerReplyReferenceDTO.self, forKey: .replyTo)
        attachment = try c.decodeIfPresent(Attachment.self, forKey: .attachment)
    }

    var messageStatus: MessageStatus {
        if readAt != nil { return .read }
        if deliveredAt != nil { return .delivered }
        return .sent
    }

    var e2eeEnvelope: GRUE2EEEnvelope? {
        guard let e2eeClientMessageId,
              let encryptedPayload,
              let encryptionVersion,
              let senderEphemeralPublicKey,
              let e2eeSignature,
              let senderKeyFingerprint
        else { return nil }

        return GRUE2EEEnvelope(
            version: encryptionVersion,
            clientMessageId: e2eeClientMessageId,
            encryptedPayload: encryptedPayload,
            senderEphemeralPublicKey: senderEphemeralPublicKey,
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
            e2eeSignature: e2eeSignature,
            senderKeyFingerprint: senderKeyFingerprint,
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
        id: String, chatId: String, senderId: String, receiverId: String?, text: String,
        e2eeClientMessageId: String?, encryptedPayload: String?, encryptionVersion: String?,
        senderEphemeralPublicKey: String?, e2eeSignature: String?, senderKeyFingerprint: String?,
        createdAt: Date, deliveredAt: Date?, readAt: Date?, deletedAt: Date?, isEdited: Bool?,
        editedAt: Date?, reaction: ReactionType?, replyTo: ServerReplyReferenceDTO?, attachment: Attachment?
    ) {
        self.id = id; self.chatId = chatId; self.senderId = senderId; self.receiverId = receiverId; self.text = text
        self.e2eeClientMessageId = e2eeClientMessageId; self.encryptedPayload = encryptedPayload
        self.encryptionVersion = encryptionVersion; self.senderEphemeralPublicKey = senderEphemeralPublicKey
        self.e2eeSignature = e2eeSignature; self.senderKeyFingerprint = senderKeyFingerprint
        self.createdAt = createdAt; self.deliveredAt = deliveredAt; self.readAt = readAt; self.deletedAt = deletedAt
        self.isEdited = isEdited; self.editedAt = editedAt; self.reaction = reaction; self.replyTo = replyTo
        self.attachment = attachment
    }
}
