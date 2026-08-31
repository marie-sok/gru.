
import Foundation

final class ChatAPIService {

    static let shared =
        ChatAPIService()

    private init() {}

    // MARK: - Get Chats

    func getChats(
        token: String
    ) async throws -> [ServerChatDTO] {

        let data =
            try await APIClient.shared.request(
                path: "/chats",
                method: "GET",
                token: token
            )

        return try JSONCoding.decoder.decode(
            [ServerChatDTO].self,
            from: data
        )
    }

    // MARK: - Create Chat

    func createChat(
        userID: String,
        token: String
    ) async throws -> ServerChatDTO {

        let request =
            CreateServerChatDTO(
                userId: userID
            )

        let body =
            try JSONCoding.encoder.encode(
                request
            )

        let data =
            try await APIClient.shared.request(
                path: "/chats",
                method: "POST",
                token: token,
                body: body
            )

        return try JSONCoding.decoder.decode(
            ServerChatDTO.self,
            from: data
        )
    }

    // MARK: - Delete Chat For Everyone

    func deleteChat(
        chatID: String,
        token: String
    ) async throws {
        _ = try await APIClient.shared.request(
            path: "/chats/\(chatID)",
            method: "DELETE",
            token: token
        )
    }
}

// MARK: - Request

private struct CreateServerChatDTO:
    Encodable {

    let userId: String
}
