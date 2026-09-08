import Foundation

struct Message: Identifiable, Codable {

    let id: UUID
    var serverID: String?
    let senderID: UUID
    var text: String
    var sentAt: Date
    var status: MessageStatus
    var deliveredAt: Date?
    var readAt: Date?
    var reaction: ReactionType?
    var isEdited: Bool = false
    var editedAt: Date?
    var isQueuedForRetry: Bool = false

    private var replyReference: MessageReference?

    var replyTo: Message? {
        get { replyReference?.message }
        set { replyReference = newValue.map { MessageReference($0) } }
    }

    var attachment: Attachment?

    init(
        id: UUID = UUID(),
        serverID: String? = nil,
        senderID: UUID,
        text: String,
        sentAt: Date = Date(),
        status: MessageStatus = .sending,
        deliveredAt: Date? = nil,
        readAt: Date? = nil,
        reaction: ReactionType? = nil,
        isEdited: Bool = false,
        editedAt: Date? = nil,
        isQueuedForRetry: Bool = false,
        replyTo: Message? = nil,
        attachment: Attachment? = nil
    ) {
        self.id = id
        self.serverID = serverID
        self.senderID = senderID
        self.text = text
        self.sentAt = sentAt
        self.status = status
        self.deliveredAt = deliveredAt
        self.readAt = readAt
        self.reaction = reaction
        self.isEdited = isEdited
        self.editedAt = editedAt
        self.isQueuedForRetry = isQueuedForRetry
        self.replyReference = replyTo.map { MessageReference($0) }
        self.attachment = attachment
    }

    enum CodingKeys: String, CodingKey {
        case id, serverID, senderID, text, sentAt, status, deliveredAt, readAt
        case reaction, isEdited, editedAt, isQueuedForRetry, replyTo, attachment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        serverID = try container.decodeIfPresent(String.self, forKey: .serverID)
        senderID = try container.decode(UUID.self, forKey: .senderID)
        text = try container.decode(String.self, forKey: .text)
        sentAt = try container.decode(Date.self, forKey: .sentAt)
        status = try container.decode(MessageStatus.self, forKey: .status)
        deliveredAt = try container.decodeIfPresent(Date.self, forKey: .deliveredAt)
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
        isEdited = try container.decodeIfPresent(Bool.self, forKey: .isEdited) ?? false
        editedAt = try container.decodeIfPresent(Date.self, forKey: .editedAt)
        isQueuedForRetry = try container.decodeIfPresent(Bool.self, forKey: .isQueuedForRetry) ?? false
        reaction = try container.decodeIfPresent(ReactionType.self, forKey: .reaction)
        attachment = try container.decodeIfPresent(Attachment.self, forKey: .attachment)
        if let reply = try container.decodeIfPresent(Message.self, forKey: .replyTo) {
            replyReference = MessageReference(reply)
        } else {
            replyReference = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(serverID, forKey: .serverID)
        try container.encode(senderID, forKey: .senderID)
        try container.encode(text, forKey: .text)
        try container.encode(sentAt, forKey: .sentAt)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(deliveredAt, forKey: .deliveredAt)
        try container.encodeIfPresent(readAt, forKey: .readAt)
        try container.encode(isEdited, forKey: .isEdited)
        try container.encodeIfPresent(editedAt, forKey: .editedAt)
        try container.encode(isQueuedForRetry, forKey: .isQueuedForRetry)
        try container.encodeIfPresent(reaction, forKey: .reaction)
        try container.encodeIfPresent(replyTo, forKey: .replyTo)
        try container.encodeIfPresent(attachment, forKey: .attachment)
    }

    mutating func applyServerState(_ serverMessage: ServerMessageDTO) {
        let previousLocalPath = attachment?.localPath
        let previousFileName = attachment?.fileName

        serverID = serverMessage.id

        // The E2EE endpoint intentionally returns no plaintext. Never erase
        // the optimistic/local plaintext merely because the server confirms
        // an opaque encrypted envelope.
        if serverMessage.e2eeEnvelope == nil || !serverMessage.text.isEmpty {
            text = serverMessage.text
        }

        sentAt = serverMessage.createdAt
        status = serverMessage.messageStatus
        deliveredAt = serverMessage.deliveredAt
        readAt = serverMessage.readAt
        reaction = serverMessage.reaction
        isEdited = serverMessage.isEdited ?? (serverMessage.editedAt != nil)
        editedAt = serverMessage.editedAt
        isQueuedForRetry = false

        if var serverAttachment = serverMessage.attachment {
            if serverAttachment.localPath == nil,
               serverAttachment.fileName == previousFileName {
                serverAttachment.localPath = previousLocalPath
            }
            attachment = serverAttachment
        } else if serverMessage.e2eeEnvelope == nil {
            attachment = nil
        }
    }
}

private final class MessageReference {
    let message: Message
    nonisolated init(_ message: Message) {
        self.message = message
    }
}
