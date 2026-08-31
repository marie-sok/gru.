import Foundation

final class CacheStorage {

    static let shared = CacheStorage()

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    // MARK: - Chats

    func saveChats(
        _ chats: [Chat],
        userID: String? = TokenStorage.shared.userID
    ) {

        guard let url = chatsURL(userID: userID) else {
            return
        }

        do {
            let data = try encoder.encode(chats)
            try data.write(
                to: url,
                options: [.atomic]
            )

            UserDefaults.standard.set(
                Date(),
                forKey: syncDateKey(userID: userID)
            )

        } catch {
            print(
                "❌ Chat cache save:",
                error.localizedDescription
            )
        }
    }

    func loadChats(
        userID: String? = TokenStorage.shared.userID
    ) -> [Chat] {

        guard let url = chatsURL(userID: userID),
              FileManager.default.fileExists(
                atPath: url.path
              )
        else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(
                [Chat].self,
                from: data
            )

        } catch {
            print(
                "❌ Chat cache load:",
                error.localizedDescription
            )
            return []
        }
    }

    func lastSyncDate(
        userID: String? = TokenStorage.shared.userID
    ) -> Date? {

        UserDefaults.standard.object(
            forKey: syncDateKey(userID: userID)
        ) as? Date
    }

    // MARK: - Users

    func saveUsers(
        _ users: [User]
    ) {

        do {
            let data = try encoder.encode(users)
            try data.write(
                to: usersURL,
                options: [.atomic]
            )

        } catch {
            print(
                "❌ User cache save:",
                error.localizedDescription
            )
        }
    }

    func loadUsers() -> [User] {

        guard FileManager.default.fileExists(
            atPath: usersURL.path
        ) else {
            return []
        }

        do {
            let data = try Data(contentsOf: usersURL)
            return try decoder.decode(
                [User].self,
                from: data
            )

        } catch {
            print(
                "❌ User cache load:",
                error.localizedDescription
            )
            return []
        }
    }

    // MARK: - Clear

    func clearCurrentUser() {
        let userID = TokenStorage.shared.userID

        if let url = chatsURL(userID: userID) {
            try? FileManager.default.removeItem(at: url)
        }

        UserDefaults.standard.removeObject(
            forKey: syncDateKey(userID: userID)
        )
    }

    func clear() {
        clearCurrentUser()
        try? FileManager.default.removeItem(at: usersURL)

        // V5 and earlier used one unscoped file.
        try? FileManager.default.removeItem(
            at: documentsDirectory
                .appendingPathComponent("chats.json")
        )
    }
}

private extension CacheStorage {

    var documentsDirectory: URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }

    var usersURL: URL {
        documentsDirectory
            .appendingPathComponent("users-v6.json")
    }

    func chatsURL(
        userID: String?
    ) -> URL? {

        guard let cacheID = cacheIdentifier(userID) else {
            return nil
        }

        return documentsDirectory
            .appendingPathComponent(
                "chats-v6-\(cacheID).json"
            )
    }

    func syncDateKey(
        userID: String?
    ) -> String {

        let cacheID = cacheIdentifier(userID) ?? "anonymous"
        return "gru.cache.lastSync.v6.\(cacheID)"
    }

    func cacheIdentifier(
        _ userID: String?
    ) -> String? {

        guard let userID else {
            return nil
        }

        let cleanValue = userID.filter {
            $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_"
        }

        guard !cleanValue.isEmpty else {
            return nil
        }

        return String(cleanValue.prefix(80))
    }
}
