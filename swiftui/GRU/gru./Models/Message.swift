import Foundation

struct Message: Identifiable, Codable {

    // MARK: - Local ID

    let id: UUID

    // MARK: - Server ID

    /// MongoDB ID сообщения.
    /// Пока сообщение не подтверждено сервером — nil.
    var serverID: String?

    // MARK: - Sender

    let senderID: UUID

    // MARK: - Content

    var text: String

    var sentAt: Date

    // MARK: - State

    var status: MessageStatus

    var deliveredAt: Date?

    var readAt: Date?

    var reaction: ReactionType?

    var isEdited: Bool = false

    var editedAt: Date?

    // MARK: - Reply

    private var replyReference: MessageReference?

    var replyTo: Message? {

        get {
            replyReference?.message
        }

        set {
            replyReference =
                newValue.map {
                    MessageReference($0)
                }
        }
    }

    // MARK: - Attachment

    var attachment: Attachment?

    // MARK: - Init

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
        self.replyReference =
            replyTo.map {
                MessageReference($0)
            }
        self.attachment = attachment
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {

        case id
        case serverID
        case senderID
        case text
        case sentAt
        case status
        case deliveredAt
        case readAt
        case reaction
        case isEdited
        case editedAt
        case replyTo
        case attachment
    }

    init(
        from decoder: Decoder
    ) throws {

        let container =
            try decoder.container(
                keyedBy: CodingKeys.self
            )

        id =
            try container.decode(
                UUID.self,
                forKey: .id
            )

        serverID =
            try container.decodeIfPresent(
                String.self,
                forKey: .serverID
            )

        senderID =
            try container.decode(
                UUID.self,
                forKey: .senderID
            )

        text =
            try container.decode(
                String.self,
                forKey: .text
            )

        sentAt =
            try container.decode(
                Date.self,
                forKey: .sentAt
            )

        status =
            try container.decode(
                MessageStatus.self,
                forKey: .status
            )

        deliveredAt =
            try container.decodeIfPresent(
                Date.self,
                forKey: .deliveredAt
            )

        readAt =
            try container.decodeIfPresent(
                Date.self,
                forKey: .readAt
            )

        isEdited = try container.decodeIfPresent(Bool.self, forKey: .isEdited) ?? false
        editedAt = try container.decodeIfPresent(Date.self, forKey: .editedAt)
        reaction =
            try container.decodeIfPresent(
                ReactionType.self,
                forKey: .reaction
            )

        attachment =
            try container.decodeIfPresent(
                Attachment.self,
                forKey: .attachment
            )

        if let reply =
            try container.decodeIfPresent(
                Message.self,
                forKey: .replyTo
            ) {

            replyReference =
                MessageReference(reply)

        } else {

            replyReference = nil
        }
    }

    func encode(
        to encoder: Encoder
    ) throws {

        var container =
            encoder.container(
                keyedBy: CodingKeys.self
            )

        try container.encode(
            id,
            forKey: .id
        )

        try container.encodeIfPresent(
            serverID,
            forKey: .serverID
        )

        try container.encode(
            senderID,
            forKey: .senderID
        )

        try container.encode(
            text,
            forKey: .text
        )

        try container.encode(
            sentAt,
            forKey: .sentAt
        )

        try container.encode(
            status,
            forKey: .status
        )

        try container.encodeIfPresent(
            deliveredAt,
            forKey: .deliveredAt
        )

        try container.encodeIfPresent(
            readAt,
            forKey: .readAt
        )

        try container.encode(isEdited, forKey: .isEdited)
        try container.encodeIfPresent(editedAt, forKey: .editedAt)
        try container.encodeIfPresent(
            reaction,
            forKey: .reaction
        )

        try container.encodeIfPresent(
            replyTo,
            forKey: .replyTo
        )

        try container.encodeIfPresent(
            attachment,
            forKey: .attachment
        )
    }

    mutating func applyServerState(
        _ serverMessage: ServerMessageDTO
    ) {

        let previousLocalPath =
            attachment?.localPath

        let previousFileName =
            attachment?.fileName

        serverID =
            serverMessage.id

        text =
            serverMessage.text

        sentAt =
            serverMessage.createdAt

        status =
            serverMessage.messageStatus

        deliveredAt =
            serverMessage.deliveredAt

        readAt =
            serverMessage.readAt

        reaction =
            serverMessage.reaction

        isEdited =
            serverMessage.isEdited ?? (serverMessage.editedAt != nil)

        editedAt =
            serverMessage.editedAt

        if var serverAttachment =
            serverMessage.attachment {

            if serverAttachment.localPath == nil,
               serverAttachment.fileName ==
                previousFileName {

                serverAttachment.localPath =
                    previousLocalPath
            }

            attachment =
                serverAttachment

        } else {

            attachment = nil
        }
    }
}

// MARK: - Message Reference

private final class MessageReference {

    let message: Message

    nonisolated init(
        _ message: Message
    ) {

        self.message = message
    }
}
