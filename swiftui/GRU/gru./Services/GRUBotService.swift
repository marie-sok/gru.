import Foundation

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

    /// gru.bot must always answer. A live backend/provider response is preferred,
    /// but transport, auth, decode and provider failures fall back locally.
    func ask(
        text: String,
        history: [GRUBotTurnDTO]
    ) async throws -> GRUBotResponseDTO {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return localFallback(for: text, reason: "empty-input")
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
                reply: """
                Могу помочь с текстом прямо сейчас. Пришли исходник или скажи три вещи: кому пишем, что нужно получить в результате и какой нужен тон. Я соберу готовую версию без лишней воды.
                """,
                model: "gru-local-writer"
            )
        }

        if lower.contains("привет") ||
            lower == "hi" ||
            lower.contains("hello") ||
            lower.contains("ты тут") {
            return GRUBotResponseDTO(
                reply: "Привет. Я здесь и отвечаю. Можем поболтать, разобрать задачу, написать текст или собрать план — кидай тему как есть.",
                model: "gru-local-chat"
            )
        }

        return GRUBotResponseDTO(
            reply: """
            Я получил: «\(text)».

            Серверный AI-канал сейчас не дал быстрый ответ, поэтому я переключился на встроенный резервный режим вместо молчания. Могу продолжить разговор, разложить задачу, сравнить варианты, подготовить текст или план. Добавь цель или главный вопрос — отвечу дальше.
            """,
            model: "gru-local-chat"
        )
    }
}
