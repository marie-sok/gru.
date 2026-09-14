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

        let data: Data
        do {
            data = try await APIClient.shared.request(
                path: "/auth/login",
                method: "POST",
                body: body
            )
        } catch APIError.unauthorized {
            // /auth/login has no established session to expire. A 401 here is
            // strictly a credential failure and must not be presented as a JWT
            // session-expiration error.
            throw GRUAuthServiceError.invalidCredentials
        }

        return try JSONCoding.decoder.decode(
            AuthResponse.self,
            from: data
        )
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

        return try JSONCoding.decoder.decode(
            AuthResponse.self,
            from: data
        )
    }
}

private enum GRUAuthServiceError: LocalizedError {
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return GRUL10n.text("Incorrect phone number or password.")
        }
    }
}
