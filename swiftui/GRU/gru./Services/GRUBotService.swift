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
            throw APIError.unauthorized
        }

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
    }
}
