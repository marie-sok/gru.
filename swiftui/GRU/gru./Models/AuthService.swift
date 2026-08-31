
import Foundation

final class AuthService {

    static let shared = AuthService()

    private init() {}

    // MARK: - Login

    func login(
        phone: String,
        password: String
    ) async throws -> AuthResponse {

        let request = LoginRequest(
            phone: phone,
            password: password
        )

        let body = try JSONCoding.encoder.encode(
            request
        )

        let data = try await APIClient.shared.request(
            path: "/auth/login",
            method: "POST",
            body: body
        )

        let response = try JSONCoding.decoder.decode(
            AuthResponse.self,
            from: data
        )

        return response
    }

    // MARK: - Register

    func register(
        phone: String,
        password: String,
        nickname: String
    ) async throws -> AuthResponse {

        let request = RegisterRequest(
            phone: phone,
            password: password,
            nickname: nickname
        )

        let body = try JSONCoding.encoder.encode(
            request
        )

        let data = try await APIClient.shared.request(
            path: "/auth/register",
            method: "POST",
            body: body
        )

        let response = try JSONCoding.decoder.decode(
            AuthResponse.self,
            from: data
        )

        return response
    }
}
