import Foundation

// MARK: ========================================
// MARK: SERVER REPLY REFERENCE
// MARK: ========================================

struct ServerReplyReferenceDTO: Codable {

    let messageId: String

    let senderId: String

    let text: String
}

// MARK: ========================================
// MARK: SERVER MESSAGE
// MARK: ========================================

struct ServerMessageDTO: Codable {

    let id: String

    let chatId: String

    let senderId: String

    let receiverId: String?

    let text: String

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

        if readAt != nil {
            return .read
        }

        if deliveredAt != nil {
            return .delivered
        }

        return .sent
    }
}
