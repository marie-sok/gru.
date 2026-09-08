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

    var messageStatus: MessageStatus {
        if readAt != nil { return .read }
        if deliveredAt != nil { return .delivered }
        return .sent
    }

    var e2eeEnvelope: GRUE2EEEnvelope? {
        guard let encryptedPayload,
              let encryptionVersion,
              let senderEphemeralPublicKey,
              let e2eeSignature,
              let senderKeyFingerprint
        else { return nil }

        return GRUE2EEEnvelope(
            version: encryptionVersion,
            encryptedPayload: encryptedPayload,
            senderEphemeralPublicKey: senderEphemeralPublicKey,
            signature: e2eeSignature,
            senderKeyFingerprint: senderKeyFingerprint
        )
    }
}
