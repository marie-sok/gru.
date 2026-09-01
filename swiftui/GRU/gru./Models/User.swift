
import Foundation

struct User: Identifiable, Codable, Hashable {

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

    // MARK: - Init

    init(
        id: UUID = UUID(),
        serverID: String? = nil,
        username: String,
        displayName: String,
        isOnline: Bool = false,
        avatarURL: String? = nil
    ) {

        self.id = id
        self.serverID = serverID
        self.username = username
        self.displayName = displayName
        self.isOnline = isOnline
        self.avatarURL = avatarURL
    }
}
