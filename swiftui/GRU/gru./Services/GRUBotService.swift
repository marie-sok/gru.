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

    private init() {}

    func ask(
        text: String,
        history: [GRUBotTurnDTO]
    ) async throws -> GRUBotResponseDTO {
        guard let token = TokenStorage.shared.token,
              !token.isEmpty else {
            return localFallback(for: text)
        }

        do {
            let body = try JSONCoding.encoder.encode(
                GRUBotRequestDTO(
                    text: text,
                    history: history
                )
            )

            let data = try await APIClient.shared.request(
                path: "/bot/chat",
                method: "POST",
                token: token,
                body: body
            )

            return try JSONCoding.decoder.decode(
                GRUBotResponseDTO.self,
                from: data
            )
        } catch {
            print("⚠️ gru.bot backend unavailable, using local fallback:", error)
            return localFallback(for: text)
        }
    }

    private func localFallback(for source: String) -> GRUBotResponseDTO {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        let asksForPlan =
            lower.contains("план") ||
            lower.contains("сплан") ||
            lower.contains("по шаг") ||
            lower.contains("plan") ||
            lower.contains("steps") ||
            lower.contains("schedule")

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

        if lower.contains("привет") || lower == "hi" || lower.contains("hello") {
            return GRUBotResponseDTO(
                reply: "Привет. Я на связи. Можем поболтать, разобрать мысль или собрать план — кидай тему как есть.",
                model: "gru-local-chat"
            )
        }

        return GRUBotResponseDTO(
            reply: "Я понял: «\(text)». Сейчас серверный AI-канал недоступен, поэтому я отвечаю в резервном режиме. Могу помочь разложить задачу, сравнить варианты, сформулировать текст или собрать план. Добавь цель и главный вопрос — продолжим.",
            model: "gru-local-chat"
        )
    }
}
