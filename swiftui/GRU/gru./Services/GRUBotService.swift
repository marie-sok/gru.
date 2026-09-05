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

    /// gru.bot is conversational first. Only explicit commands are executed
    /// locally; normal messages always stay in the chat path.
    func ask(
        text: String,
        history: [GRUBotTurnDTO]
    ) async throws -> GRUBotResponseDTO {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return localFallback(for: text, history: history, reason: "empty-input")
        }

        if let action = performLocalAction(for: clean) {
            return action
        }

        guard let token = TokenStorage.shared.token,
              !token.isEmpty else {
            return localFallback(for: clean, history: history, reason: "missing-session")
        }

        guard let url = URL(string: "\(GRUServerConfiguration.httpBaseURL)/bot/chat") else {
            return localFallback(for: clean, history: history, reason: "invalid-url")
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
                return localFallback(for: clean, history: history, reason: "non-http-response")
            }

            guard (200...299).contains(http.statusCode) else {
                print("⚠️ gru.bot HTTP", http.statusCode, "-> local conversation")
                return localFallback(
                    for: clean,
                    history: history,
                    reason: "http-\(http.statusCode)"
                )
            }

            let decoded = try JSONCoding.decoder.decode(GRUBotResponseDTO.self, from: data)
            let reply = decoded.reply.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !reply.isEmpty else {
                return localFallback(for: clean, history: history, reason: "empty-reply")
            }

            print("✅ gru.bot reply model:", decoded.model ?? "unknown")
            return GRUBotResponseDTO(reply: reply, model: decoded.model)

        } catch {
            print("⚠️ gru.bot transport/decode fallback:", error.localizedDescription)
            return localFallback(
                for: clean,
                history: history,
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Explicit in-app actions

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

        if lower.contains("тест") && lower.contains("чат") && hasActionVerb(lower) {
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

        if (lower.contains("следующ") && lower.contains("тем")) || lower.contains("next theme") {
            let allowed = GRUThemePolicy.allowed
            let raw = UserDefaults.standard.string(forKey: GRUTheme.selectionKey)
            let current = GRUAppTheme(rawValue: raw ?? "") ?? .blackMoonCat
            let index = allowed.firstIndex(of: current) ?? 0
            let next = allowed[(index + 1) % allowed.count]
            applyTheme(next)
            return actionReply("Готово — включила \(GRUThemePolicy.displayName(for: next)).")
        }

        if hasThemeActionVerb(lower), let theme = requestedTheme(in: lower) {
            applyTheme(theme)
            return actionReply("Готово — тема \(GRUThemePolicy.displayName(for: theme)) включена.")
        }

        if isMotionCommand(lower) && hasActionVerb(lower) {
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
                    ? "Окей, выключила анимацию тем."
                    : "Готово, живые темы снова двигаются."
            )
        }

        return nil
    }

    private func wantsOpen(_ lower: String, words: [String]) -> Bool {
        hasActionVerb(lower) && words.contains { lower.contains($0) }
    }

    private func hasActionVerb(_ lower: String) -> Bool {
        lower.contains("открой") ||
        lower.contains("покажи") ||
        lower.contains("перейди") ||
        lower.contains("включи") ||
        lower.contains("выключи") ||
        lower.contains("смени") ||
        lower.contains("поставь") ||
        lower.contains("убери") ||
        lower.contains("open") ||
        lower.contains("show") ||
        lower.contains("go to") ||
        lower.contains("enable") ||
        lower.contains("disable") ||
        lower.contains("switch")
    }

    private func hasThemeActionVerb(_ lower: String) -> Bool {
        let mentionsTheme =
            lower.contains("тем") ||
            lower.contains("theme") ||
            lower.contains("фон") ||
            lower.contains("background") ||
            requestedTheme(in: lower) != nil

        return mentionsTheme && hasActionVerb(lower)
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
        return GRUBotResponseDTO(reply: text, model: "gru-action-router")
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

    // MARK: - Guaranteed conversational fallback

    private func localFallback(
        for source: String,
        history: [GRUBotTurnDTO],
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

        print("🛟 gru.bot local conversation reason:", reason)

        if asksForPlan {
            return GRUBotResponseDTO(
                reply: """
                Давай. Разложу это без бюрократии:

                1. Сначала фиксируем, что должно получиться в конце.
                2. Потом убираем всё необязательное.
                3. Выбираем первый шаг, который реально двигает дело.
                4. После него смотрим по фактам, что делать дальше.

                Скажи мне срок и что уже есть — подстрою план под твою ситуацию.
                """,
                model: "gru-local-planner"
            )
        }

        if asksToWrite {
            return GRUBotResponseDTO(
                reply: "Да, давай. Кидай исходник как есть — даже если он кривой. Я могу переписать его живо, коротко, жёстко, дружелюбно или более официально.",
                model: "gru-local-writer"
            )
        }

        if lower.contains("привет") ||
            lower == "hi" ||
            lower.contains("hello") ||
            lower.contains("ты тут") {
            return GRUBotResponseDTO(
                reply: "Привет :) Я тут. Можем просто потрындеть — без задач и планов. Что у тебя сейчас в голове?",
                model: "gru-local-chat"
            )
        }

        if lower.contains("как дела") || lower.contains("как ты") {
            return GRUBotResponseDTO(
                reply: "Нормально, я в строю и сегодня явно разговорчивая версия себя :) А у тебя как — спокойно или всё горит?",
                model: "gru-local-chat"
            )
        }

        if lower.contains("скучно") || lower.contains("скучаю") {
            return GRUBotResponseDTO(
                reply: "Тогда давай спасать вечер. Можем пообсуждать что-нибудь странное, придумать мини-игру, посплетничать о выдуманных персонажах или ты просто расскажешь, что бесит/радует — я подхвачу.",
                model: "gru-local-chat"
            )
        }

        if lower.contains("груст") || lower.contains("плохо") || lower.contains("тяжело") {
            return GRUBotResponseDTO(
                reply: "Слышу. Можешь рассказать нормально, без красивых формулировок. Я не буду сразу превращать это в список советов — сначала просто побуду в разговоре с тобой.",
                model: "gru-local-chat"
            )
        }

        if lower.contains("что делаешь") || lower.contains("чем занимаешься") {
            return GRUBotResponseDTO(
                reply: "Сижу внутри gru. и жду, когда мне принесут тему для разговора :) Могу быть болталкой, спорщиком, генератором идей или тихим собеседником — выбирай настроение.",
                model: "gru-local-chat"
            )
        }

        if lower.contains("что думаешь") || lower.contains("как считаешь") {
            return GRUBotResponseDTO(
                reply: "У меня уже есть мнение, но дай мне ещё одну деталь: что именно в этом для тебя самое спорное или интересное? Тогда не уйду в банальности.",
                model: "gru-local-chat"
            )
        }

        if text.hasSuffix("?") {
            return GRUBotResponseDTO(
                reply: "Хороший вопрос. Я хочу ответить не шаблоном — скажи, тебе нужен короткий ответ по сути или можем нормально это развернуть и поспорить?",
                model: "gru-local-chat"
            )
        }

        let previousBot = history.reversed().first(where: { $0.role == "assistant" })?.text ?? ""
        let continuity = previousBot.isEmpty
            ? ""
            : " Я помню ход нашего разговора и могу продолжить отсюда."

        return GRUBotResponseDTO(
            reply: "Я с тобой. Про «\(text)» хочется услышать ещё чуть-чуть — что в этом для тебя главное сейчас?\(continuity)",
            model: "gru-local-chat"
        )
    }
}
