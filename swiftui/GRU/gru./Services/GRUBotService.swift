import Foundation

extension Notification.Name {
    static let gruBotOpenChats = Notification.Name("gru.bot.action.openChats")
    static let gruBotOpenContacts = Notification.Name("gru.bot.action.openContacts")
    static let gruBotOpenSettings = Notification.Name("gru.bot.action.openSettings")
    static let gruBotOpenTestLab = Notification.Name("gru.bot.action.openTestLab")
}

struct GRUBotTurnDTO: Codable {
    let role: String
    let text: String
}

struct GRUBotRequestDTO: Encodable {
    let text: String
    let history: [GRUBotTurnDTO]
}

struct GRUBotResponseDTO: Decodable {
    let reply: String
    let model: String?
}

@MainActor
final class GRUBotService {
    static let shared = GRUBotService()

    private let session: URLSession
    private let timeout: TimeInterval = 7

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 7
        configuration.timeoutIntervalForResource = 8
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    /// First execute deterministic in-app commands locally. Everything else
    /// goes to the server AI and always falls back locally if transport fails.
    func ask(
        text: String,
        history: [GRUBotTurnDTO]
    ) async throws -> GRUBotResponseDTO {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return localFallback(for: text, reason: "empty-input")
        }

        if let action = performLocalAction(for: clean) {
            return action
        }

        guard let token = TokenStorage.shared.token,
              !token.isEmpty else {
            return localFallback(for: clean, reason: "missing-session")
        }

        guard let url = URL(
            string: "\(GRUServerConfiguration.httpBaseURL)/bot/chat"
        ) else {
            return localFallback(for: clean, reason: "invalid-url")
        }

        do {
            let body = try JSONCoding.encoder.encode(
                GRUBotRequestDTO(
                    text: clean,
                    history: Array(history.suffix(30))
                )
            )

            var request = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: timeout
            )
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            print("🤖 gru.bot request ->", url.absoluteString)

            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                return localFallback(for: clean, reason: "non-http-response")
            }

            guard (200...299).contains(http.statusCode) else {
                print("⚠️ gru.bot HTTP", http.statusCode, "-> local fallback")
                return localFallback(
                    for: clean,
                    reason: "http-\(http.statusCode)"
                )
            }

            let decoded = try JSONCoding.decoder.decode(
                GRUBotResponseDTO.self,
                from: data
            )

            let reply = decoded.reply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reply.isEmpty else {
                return localFallback(for: clean, reason: "empty-reply")
            }

            print("✅ gru.bot reply model:", decoded.model ?? "unknown")
            return GRUBotResponseDTO(reply: reply, model: decoded.model)

        } catch {
            print(
                "⚠️ gru.bot transport/decode fallback:",
                error.localizedDescription
            )
            return localFallback(
                for: clean,
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Real in-app actions

    private func performLocalAction(for source: String) -> GRUBotResponseDTO? {
        let lower = normalized(source)

        if wantsOpen(lower, words: ["настрой", "settings"]) {
            NotificationCenter.default.post(name: .gruBotOpenSettings, object: nil)
            return actionReply("Открываю настройки.")
        }

        if wantsOpen(lower, words: ["контакт", "люди", "people", "contacts"]) {
            NotificationCenter.default.post(name: .gruBotOpenContacts, object: nil)
            return actionReply("Открываю людей и контакты.")
        }

        if lower.contains("тест") && lower.contains("чат") &&
            (lower.contains("открой") || lower.contains("покажи") || lower.contains("open")) {
            NotificationCenter.default.post(name: .gruBotOpenChats, object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                NotificationCenter.default.post(name: .gruBotOpenTestLab, object: nil)
            }
            return actionReply("Открываю gru. test lab.")
        }

        if wantsOpen(lower, words: ["чат", "chats"]) {
            NotificationCenter.default.post(name: .gruBotOpenChats, object: nil)
            return actionReply("Открываю список чатов.")
        }

        if lower.contains("следующ") && lower.contains("тем") || lower.contains("next theme") {
            let allowed = GRUThemePolicy.allowed
            let raw = UserDefaults.standard.string(forKey: GRUTheme.selectionKey)
            let current = GRUAppTheme(rawValue: raw ?? "") ?? .blackMoonCat
            let index = allowed.firstIndex(of: current) ?? 0
            let next = allowed[(index + 1) % allowed.count]
            applyTheme(next)
            return actionReply("Готово. Включила \(GRUThemePolicy.displayName(for: next)).")
        }

        if isThemeCommand(lower), let theme = requestedTheme(in: lower) {
            applyTheme(theme)
            return actionReply("Готово. Тема \(GRUThemePolicy.displayName(for: theme)) включена.")
        }

        if isMotionCommand(lower) {
            let disable =
                lower.contains("выключ") ||
                lower.contains("отключ") ||
                lower.contains("убери") ||
                lower.contains("статич") ||
                lower.contains("off") ||
                lower.contains("stop")

            UserDefaults.standard.set(
                !disable,
                forKey: "gru.settings.appearance.dynamicBackground"
            )
            UserDefaults.standard.set(
                disable,
                forKey: "gru.settings.accessibility.reduceMotion"
            )

            return actionReply(
                disable
                    ? "Готово. Анимация тем выключена."
                    : "Готово. Живые анимированные темы включены."
            )
        }

        return nil
    }

    private func wantsOpen(_ lower: String, words: [String]) -> Bool {
        let openVerb =
            lower.contains("открой") ||
            lower.contains("покажи") ||
            lower.contains("перейди") ||
            lower.contains("open") ||
            lower.contains("show") ||
            lower.contains("go to")

        return openVerb && words.contains { lower.contains($0) }
    }

    private func isThemeCommand(_ lower: String) -> Bool {
        lower.contains("тем") ||
        lower.contains("theme") ||
        lower.contains("фон") ||
        lower.contains("background") ||
        lower.contains("включи") ||
        lower.contains("поставь") ||
        lower.contains("смени")
    }

    private func isMotionCommand(_ lower: String) -> Bool {
        lower.contains("анимац") ||
        lower.contains("живой фон") ||
        lower.contains("живые темы") ||
        lower.contains("движение тем") ||
        lower.contains("animated background") ||
        lower.contains("theme animation")
    }

    private func requestedTheme(in lower: String) -> GRUAppTheme? {
        let aliases: [(GRUAppTheme, [String])] = [
            (.blackMoonCat, ["black moon", "black moon cat", "лунный кот", "черная луна", "чёрная луна"]),
            (.neonCatDemon, ["neon demon", "neon demon cat", "демон", "неоновый демон"]),
            (.bloodDragon, ["blood dragon", "кровавый дракон", "дракон"]),
            (.forestWitch, ["forest witch", "лесная ведьма", "ведьма"]),
            (.cyberMidnight, ["cyber midnight", "кибер полночь", "кибер"]),
            (.ultravioletUnicorn, ["ultraviolet unicorn", "единорог", "ультрафиолетовый единорог"]),
            (.powderPrincess, ["powder princess", "пудровая принцесса", "принцесса"]),
            (.greenAcidMonster, ["green acid monster", "кислотный монстр", "acid monster", "монстр"]),
            (.ironKnight, ["iron knight", "железный рыцарь", "рыцарь"])
        ]

        for (theme, names) in aliases {
            if names.contains(where: { lower.contains($0) }) {
                return theme
            }
        }

        return nil
    }

    private func applyTheme(_ theme: GRUAppTheme) {
        guard GRUThemePolicy.allowed.contains(theme) else { return }
        UserDefaults.standard.set(theme.rawValue, forKey: GRUTheme.selectionKey)
        UserDefaults.standard.set(true, forKey: "gru.settings.appearance.dynamicBackground")
        UserDefaults.standard.set(false, forKey: "gru.settings.accessibility.reduceMotion")
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
    }

    private func actionReply(_ text: String) -> GRUBotResponseDTO {
        print("⚡️ gru.bot action:", text)
        return GRUBotResponseDTO(
            reply: text,
            model: "gru-action-router"
        )
    }

    private func normalized(_ source: String) -> String {
        source
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "!", with: " ")
            .replacingOccurrences(of: "?", with: " ")
    }

    // MARK: - Guaranteed text fallback

    private func localFallback(
        for source: String,
        reason: String
    ) -> GRUBotResponseDTO {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        let asksForPlan =
            lower.contains("план") ||
            lower.contains("сплан") ||
            lower.contains("по шаг") ||
            lower.contains("plan") ||
            lower.contains("steps") ||
            lower.contains("schedule")

        let asksToWrite =
            lower.contains("напиши") ||
            lower.contains("перепиши") ||
            lower.contains("текст") ||
            lower.contains("write") ||
            lower.contains("rewrite")

        print("🛟 gru.bot local fallback reason:", reason)

        if asksForPlan {
            return GRUBotResponseDTO(
                reply: """
                Соберу рабочий план по запросу «\(text)».

                1. Зафиксируй конечный результат одним предложением.
                2. Отдели обязательное от желательного и выпиши ограничения.
                3. Разбей работу на 3–5 коротких этапов с понятным результатом каждого.
                4. Начни с шага, который снимает самый большой риск или зависимость.
                5. После первого результата пересобери следующие шаги по фактам.

                Следующий шаг: напиши срок и что уже готово — я помогу сделать план точнее.
                """,
                model: "gru-local-planner"
            )
        }

        if asksToWrite {
            return GRUBotResponseDTO(
                reply: "Могу помочь с текстом прямо сейчас. Пришли исходник или скажи три вещи: кому пишем, что нужно получить в результате и какой нужен тон. Я соберу готовую версию без лишней воды.",
                model: "gru-local-writer"
            )
        }

        if lower.contains("привет") ||
            lower == "hi" ||
            lower.contains("hello") ||
            lower.contains("ты тут") {
            return GRUBotResponseDTO(
                reply: "Привет. Я здесь и отвечаю. Ещё я умею выполнять команды приложения: менять тему, включать живой фон, открывать чаты, людей, настройки и test lab.",
                model: "gru-local-chat"
            )
        }

        return GRUBotResponseDTO(
            reply: """
            Я получил: «\(text)».

            Серверный AI-канал сейчас не дал быстрый ответ, поэтому я переключился на встроенный резервный режим вместо молчания. Могу продолжить разговор или выполнить команды приложения — например «включи Blood Dragon», «следующая тема», «включи анимацию тем», «открой настройки» или «открой тестовый чат».
            """,
            model: "gru-local-chat"
        )
    }
}
