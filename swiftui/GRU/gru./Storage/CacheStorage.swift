import Foundation

/// Local cache for chats/messages.
/// Sensitive payloads are encrypted before touching disk and additionally use
/// iOS complete file protection. Existing plaintext v6/v7 cache remains
/// readable only for migration and is encrypted on the next save.
final class CacheStorage {

    static let shared = CacheStorage()

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let protector = GRUDataProtection.shared

    private let ioQueue = DispatchQueue(label: "sok.com.gru.cache.io", qos: .utility)
    private var inMemoryChats: [Chat]?
    private let memoryLock = NSLock()
    private var pendingSaveWorkItem: DispatchWorkItem?

    private init() {}

    // MARK: - Chats

    func saveChats(
        _ chats: [Chat],
        userID: String? = TokenStorage.shared.userID
    ) {
        memoryLock.lock()
        inMemoryChats = chats
        memoryLock.unlock()

        guard let targetURL = chatsURL(userID: userID) else { return }

        ioQueue.async { [weak self] in
            guard let self else { return }
            self.pendingSaveWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                do {
                    try self.writeProtected(
                        self.encoder.encode(chats),
                        to: targetURL
                    )
                    UserDefaults.standard.set(
                        Date(),
                        forKey: self.syncDateKey(userID: userID)
                    )
                    self.savePerChatMessagesAsync(chats)
                } catch {
                    print("❌ Chat cache protected save failed:", error.localizedDescription)
                }
            }

            self.pendingSaveWorkItem = workItem
            self.ioQueue.asyncAfter(deadline: .now() + 0.25, execute: workItem)
        }
    }

    func loadChats(
        userID: String? = TokenStorage.shared.userID
    ) -> [Chat] {
        memoryLock.lock()
        if let cached = inMemoryChats, !cached.isEmpty {
            memoryLock.unlock()
            return cached
        }
        memoryLock.unlock()

        guard let url = chatsURL(userID: userID) else { return [] }

        let fileURLToRead: URL
        if FileManager.default.fileExists(atPath: url.path) {
            fileURLToRead = url
        } else if let legacyURL = legacyChatsURL(userID: userID),
                  FileManager.default.fileExists(atPath: legacyURL.path) {
            fileURLToRead = legacyURL
        } else {
            return []
        }

        do {
            let protectedOrLegacy = try Data(contentsOf: fileURLToRead)
            let data = try protector.open(protectedOrLegacy)
            let loadedChats = try decoder.decode([Chat].self, from: data)

            memoryLock.lock()
            inMemoryChats = loadedChats
            memoryLock.unlock()

            // Migrate any legacy plaintext cache immediately.
            if !protectedOrLegacy.starts(with: Data("GRUENC1".utf8)) {
                saveChats(loadedChats, userID: userID)
            }
            return loadedChats
        } catch {
            print("❌ Chat cache protected load failed:", error.localizedDescription)
            return []
        }
    }

    func lastSyncDate(
        userID: String? = TokenStorage.shared.userID
    ) -> Date? {
        UserDefaults.standard.object(forKey: syncDateKey(userID: userID)) as? Date
    }

    // MARK: - Per-chat messages

    func saveMessages(
        _ messages: [Message],
        for chatID: String
    ) {
        guard let url = chatMessagesURL(chatID: chatID) else { return }

        ioQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.writeProtected(self.encoder.encode(messages), to: url)
            } catch {
                print("❌ Protected message cache save failed for \(chatID):", error.localizedDescription)
            }
        }
    }

    func loadMessages(
        for chatID: String
    ) -> [Message]? {
        guard let url = chatMessagesURL(chatID: chatID),
              FileManager.default.fileExists(atPath: url.path)
        else {
            return nil
        }

        do {
            let stored = try Data(contentsOf: url)
            let data = try protector.open(stored)
            let messages = try decoder.decode([Message].self, from: data)
            if !stored.starts(with: Data("GRUENC1".utf8)) {
                saveMessages(messages, for: chatID)
            }
            return messages
        } catch {
            print("❌ Protected message cache load failed:", error.localizedDescription)
            return nil
        }
    }

    private func savePerChatMessagesAsync(_ chats: [Chat]) {
        for chat in chats {
            let chatID = chat.serverID ?? chat.id.uuidString
            guard let url = chatMessagesURL(chatID: chatID),
                  let data = try? encoder.encode(chat.messages)
            else { continue }
            try? writeProtected(data, to: url)
        }
    }

    // MARK: - Users

    func saveUsers(_ users: [User]) {
        ioQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.writeProtected(self.encoder.encode(users), to: self.usersURL)
            } catch {
                print("❌ Protected user cache save failed:", error.localizedDescription)
            }
        }
    }

    func loadUsers() -> [User] {
        guard FileManager.default.fileExists(atPath: usersURL.path) else {
            return []
        }

        do {
            let stored = try Data(contentsOf: usersURL)
            let data = try protector.open(stored)
            let users = try decoder.decode([User].self, from: data)
            if !stored.starts(with: Data("GRUENC1".utf8)) {
                saveUsers(users)
            }
            return users
        } catch {
            print("❌ Protected user cache load failed:", error.localizedDescription)
            return []
        }
    }

    // MARK: - Clear

    func clearCurrentUser() {
        let userID = TokenStorage.shared.userID

        // Prevent a delayed save that was queued before logout/cache reset from
        // recreating sensitive files after the user explicitly cleared them.
        ioQueue.sync {
            pendingSaveWorkItem?.cancel()
            pendingSaveWorkItem = nil
        }

        memoryLock.lock()
        inMemoryChats = nil
        memoryLock.unlock()

        if let url = chatsURL(userID: userID) {
            try? FileManager.default.removeItem(at: url)
        }
        if let legacyURL = legacyChatsURL(userID: userID) {
            try? FileManager.default.removeItem(at: legacyURL)
        }

        removeFiles(withPrefix: "messages-", suffix: ".json")
        UserDefaults.standard.removeObject(forKey: syncDateKey(userID: userID))

        // These caches are also protected, but "clear cache" and logout must be
        // complete from the user's point of view rather than leaving sidecars.
        MediaCacheService.shared.clear()
        GRUVoiceTranscriptCache.shared.clear()
        LocalMessageDeletionStore.shared.clearCurrentUser()
    }

    func clear() {
        clearCurrentUser()
        try? FileManager.default.removeItem(at: usersURL)
        try? FileManager.default.removeItem(
            at: documentsDirectory.appendingPathComponent("chats.json")
        )
    }

    // MARK: - Protected disk IO

    private func writeProtected(_ plaintext: Data, to url: URL) throws {
        let ciphertext = try protector.seal(plaintext)
        try ciphertext.write(
            to: url,
            options: [.atomic, .completeFileProtection]
        )
    }

    private func removeFiles(withPrefix prefix: String, suffix: String) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files where file.lastPathComponent.hasPrefix(prefix)
            && file.lastPathComponent.hasSuffix(suffix) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

// MARK: - Path Helpers

private extension CacheStorage {

    var documentsDirectory: URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }

    var usersURL: URL {
        documentsDirectory.appendingPathComponent("users-v7.json")
    }

    func chatsURL(userID: String?) -> URL? {
        guard let cacheID = cacheIdentifier(userID) else { return nil }
        return documentsDirectory.appendingPathComponent("chats-v7-\(cacheID).json")
    }

    func legacyChatsURL(userID: String?) -> URL? {
        guard let cacheID = cacheIdentifier(userID) else { return nil }
        return documentsDirectory.appendingPathComponent("chats-v6-\(cacheID).json")
    }

    func chatMessagesURL(chatID: String) -> URL? {
        let safeID = chatID.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        guard !safeID.isEmpty else { return nil }
        return documentsDirectory.appendingPathComponent("messages-\(safeID).json")
    }

    func syncDateKey(userID: String?) -> String {
        let cacheID = cacheIdentifier(userID) ?? "anonymous"
        return "gru.cache.lastSync.v7.\(cacheID)"
    }

    func cacheIdentifier(_ userID: String?) -> String? {
        guard let userID else { return nil }
        let cleanValue = userID.filter {
            $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_"
        }
        guard !cleanValue.isEmpty else { return nil }
        return String(cleanValue.prefix(80))
    }
}
