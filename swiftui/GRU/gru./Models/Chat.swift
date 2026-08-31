
import Foundation

struct Chat: Identifiable, Codable {

    // MARK: - Local ID

    let id: UUID

    // MARK: - Server ID

    /// MongoDB id чата.
    /// Например: "6a3f752e349acc08d5b9a9ee"
    var serverID: String?

    // MARK: - Content

    var users: [User]

    var messages: [Message]

    // MARK: - Chat Info

    var title: String?

    var avatar: String?

    var isGroup: Bool

    // MARK: - State

    var unreadCount: Int

    var isPinned: Bool

    var isMuted: Bool

    var isArchived: Bool

    var draft: String

    // MARK: - Dates

    var createdAt: Date

    var updatedAt: Date

    // MARK: - Init

    init(
        id: UUID = UUID(),
        serverID: String? = nil,
        users: [User],
        messages: [Message] = [],
        title: String? = nil,
        avatar: String? = nil,
        isGroup: Bool = false,
        unreadCount: Int = 0,
        isPinned: Bool = false,
        isMuted: Bool = false,
        isArchived: Bool = false,
        draft: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {

        self.id = id
        self.serverID = serverID
        self.users = users
        self.messages = messages
        self.title = title
        self.avatar = avatar
        self.isGroup = isGroup
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.isArchived = isArchived
        self.draft = draft
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Helpers

    var lastMessage: Message? {
        messages.last
    }

    var lastActivity: Date {
        lastMessage?.sentAt ?? updatedAt
    }
}
