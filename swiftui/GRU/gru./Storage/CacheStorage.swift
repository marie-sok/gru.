import Foundation

/// Высокопроизводительное асинхронное локальное хранилище данных приложения.
/// Все дисковые операции и кодирование JSON вынесены на фоновую очередь (non-blocking MainActor).
final class CacheStorage {

    static let shared = CacheStorage()

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // Очередь для синхронизации доступа к дисковым файлам
    private let ioQueue = DispatchQueue(label: "sok.com.gru.cache.io", qos: .utility)

    // Кэш в памяти для мгновенного доступа
    private var inMemoryChats: [Chat]?
    private let memoryLock = NSLock()

    // Таймер дебаунса для частых сохранений
    private var pendingSaveWorkItem: DispatchWorkItem?

    private init() {
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    // MARK: - Chats (Async Non-blocking)

    /// Сохраняет список чатов асинхронно в фоновом потоке.
    /// Не блокирует UI и MainActor при больших объемах данных.
    func saveChats(
        _ chats: [Chat],
        userID: String? = TokenStorage.shared.userID
    ) {
        memoryLock.lock()
        inMemoryChats = chats
        memoryLock.unlock()

        guard let targetURL = chatsURL(userID: userID) else { return }

        // Дебаунс 250мс: если за короткое время пришло несколько событий,
        // сохраняем на диск один раз итоговое состояние
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            self.pendingSaveWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                do {
                    let data = try self.encoder.encode(chats)
                    try data.write(to: targetURL, options: [.atomic])

                    // Сохраняем дату синхронизации
                    UserDefaults.standard.set(
                        Date(),
                        forKey: self.syncDateKey(userID: userID)
                    )

                    // Асинхронно сохраняем сообщения каждого чата в изолированные файлы
                    self.savePerChatMessagesAsync(chats)
                } catch {
                    print("❌ Chat cache async save failed:", error.localizedDescription)
                }
            }

            self.pendingSaveWorkItem = workItem
            self.ioQueue.asyncAfter(deadline: .now() + 0.25, execute: workItem)
        }
    }

    /// Загружает список чатов. Если есть кэш в памяти — отдает мгновенно.
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

        // Если актуального файла нет, проверяем legacy v6
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
            let data = try Data(contentsOf: fileURLToRead)
            let loadedChats = try decoder.decode([Chat].self, from: data)

            memoryLock.lock()
            inMemoryChats = loadedChats
            memoryLock.unlock()

            return loadedChats
        } catch {
            print("❌ Chat cache load failed:", error.localizedDescription)
            return []
        }
    }

    func lastSyncDate(
        userID: String? = TokenStorage.shared.userID
    ) -> Date? {
        UserDefaults.standard.object(forKey: syncDateKey(userID: userID)) as? Date
    }

    // MARK: - Per-Chat Messages Storage

    /// Сохраняет историю конкретного чата в отдельный файл
    func saveMessages(
        _ messages: [Message],
        for chatID: String
    ) {
        guard let url = chatMessagesURL(chatID: chatID) else { return }

        ioQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(messages)
                try data.write(to: url, options: [.atomic])
            } catch {
                print("❌ Failed to save per-chat messages for \(chatID):", error)
            }
        }
    }

    /// Загружает сообщения конкретного чата из отдельного файла
    func loadMessages(
        for chatID: String
    ) -> [Message]? {
        guard let url = chatMessagesURL(chatID: chatID),
              FileManager.default.fileExists(atPath: url.path)
        else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([Message].self, from: data)
        } catch {
            return nil
        }
    }

    private func savePerChatMessagesAsync(_ chats: [Chat]) {
        for chat in chats {
            let chatID = chat.serverID ?? chat.id.uuidString
            if let url = chatMessagesURL(chatID: chatID) {
                if let data = try? encoder.encode(chat.messages) {
                    try? data.write(to: url, options: [.atomic])
                }
            }
        }
    }

    // MARK: - Users

    func saveUsers(_ users: [User]) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(users)
                try data.write(to: self.usersURL, options: [.atomic])
            } catch {
                print("❌ User cache save failed:", error.localizedDescription)
            }
        }
    }

    func loadUsers() -> [User] {
        guard FileManager.default.fileExists(atPath: usersURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: usersURL)
            return try decoder.decode([User].self, from: data)
        } catch {
            print("❌ User cache load failed:", error.localizedDescription)
            return []
        }
    }

    // MARK: - Clear

    func clearCurrentUser() {
        let userID = TokenStorage.shared.userID

        memoryLock.lock()
        inMemoryChats = nil
        memoryLock.unlock()

        if let url = chatsURL(userID: userID) {
            try? FileManager.default.removeItem(at: url)
        }

        UserDefaults.standard.removeObject(forKey: syncDateKey(userID: userID))
    }

    func clear() {
        clearCurrentUser()
        try? FileManager.default.removeItem(at: usersURL)

        // Удаляем legacy кэши
        if let legacyURL = legacyChatsURL(userID: TokenStorage.shared.userID) {
            try? FileManager.default.removeItem(at: legacyURL)
        }
        try? FileManager.default.removeItem(
            at: documentsDirectory.appendingPathComponent("chats.json")
        )
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
