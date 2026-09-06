
import Foundation

struct User: Identifiable, Codable, Hashable {

    private enum CodingKeys: String, CodingKey {
        case id
        case serverID
        case username
        case displayName
        case isOnline
        case avatarURL
        case avatarData
        case isBot
    }

    // MARK: - Local ID

    let id: UUID

    // MARK: - Server ID

    /// MongoDB ID пользователя.
    ///
    /// Например:
    /// 6a3f7345349acc08d5b9a9ed
    var serverID: String?

    // MARK: - Profile

    var username: String

    var displayName: String

    var isOnline: Bool

    var avatarURL: String?

    /// Локальная копия выбранного аватара. Нужна до появления стабильного
    /// серверного endpoint загрузки профиля и совместима со старым avatarURL.
    var avatarData: Data?

    /// Встроенный GRU Bot не притворяется серверным пользователем.
    var isBot: Bool

    // MARK: - Init

    init(
        id: UUID = UUID(),
        serverID: String? = nil,
        username: String,
        displayName: String,
        isOnline: Bool = false,
        avatarURL: String? = nil,
        avatarData: Data? = nil,
        isBot: Bool = false
    ) {

        self.id = id
        self.serverID = serverID
        self.username = username
        self.displayName = displayName
        self.isOnline = isOnline
        self.avatarURL = avatarURL
        self.avatarData = avatarData
        self.isBot = isBot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        serverID = try container.decodeIfPresent(String.self, forKey: .serverID)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decode(String.self, forKey: .displayName)
        isOnline = try container.decodeIfPresent(Bool.self, forKey: .isOnline) ?? false
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        avatarData = try container.decodeIfPresent(Data.self, forKey: .avatarData)
        isBot = try container.decodeIfPresent(Bool.self, forKey: .isBot) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(serverID, forKey: .serverID)
        try container.encode(username, forKey: .username)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(isOnline, forKey: .isOnline)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try container.encodeIfPresent(avatarData, forKey: .avatarData)
        try container.encode(isBot, forKey: .isBot)
    }
}
