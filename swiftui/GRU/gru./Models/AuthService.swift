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

        await publishE2EEIdentityIfPossible(token: response.token)
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

        await publishE2EEIdentityIfPossible(token: response.token)
        return response
    }

    /// Authentication must remain usable even if an existing account has a
    /// different pinned device identity. In that case E2EE sending fails closed
    /// later and the signed key-rotation/multi-device flow can resolve it.
    private func publishE2EEIdentityIfPossible(token: String) async {
        do {
            _ = try await E2EEAPIService.shared.publishIdentity(token: token)
        } catch {
            #if DEBUG
            print("⚠️ E2EE identity publish deferred:", error.localizedDescription)
            #endif
        }
    }
}
