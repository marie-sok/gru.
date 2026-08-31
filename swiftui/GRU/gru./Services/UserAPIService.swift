import Foundation

struct UserSafetyStateDTO: Codable, Hashable {
    let blocked: Bool
}

private struct ReportUserPayload: Codable {
    let chatId: String?
    let reason: String
    let details: String?
}

final class UserAPIService {

    static let shared = UserAPIService()

    private init() {}

    func searchUsers(
        nickname: String,
        token: String
    ) async throws -> [UserSearchDTO] {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "nickname", value: nickname)]
        let query = components.percentEncodedQuery ?? ""

        let data = try await APIClient.shared.request(
            path: "/users/search?\(query)",
            method: "GET",
            token: token
        )

        return try JSONCoding.decoder.decode([UserSearchDTO].self, from: data)
    }

    func safetyState(
        userID: String,
        token: String
    ) async throws -> UserSafetyStateDTO {
        let data = try await APIClient.shared.request(
            path: "/users/\(userID)/safety",
            method: "GET",
            token: token
        )
        return try JSONCoding.decoder.decode(UserSafetyStateDTO.self, from: data)
    }

    func setBlocked(
        _ blocked: Bool,
        userID: String,
        token: String
    ) async throws -> UserSafetyStateDTO {
        let data = try await APIClient.shared.request(
            path: "/users/\(userID)/block",
            method: blocked ? "POST" : "DELETE",
            token: token
        )
        return try JSONCoding.decoder.decode(UserSafetyStateDTO.self, from: data)
    }

    func reportUser(
        userID: String,
        chatID: String?,
        reason: String,
        details: String?,
        token: String
    ) async throws {
        let payload = ReportUserPayload(
            chatId: chatID,
            reason: reason,
            details: details
        )
        let body = try JSONCoding.encoder.encode(payload)
        _ = try await APIClient.shared.request(
            path: "/users/\(userID)/report",
            method: "POST",
            token: token,
            body: body
        )
    }

    func deleteMyAccount(token: String) async throws {
        _ = try await APIClient.shared.request(
            path: "/users/me",
            method: "DELETE",
            token: token
        )
    }
}
