import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {

    var phone = ""
    var password = ""
    var nickname = ""

    var loading = false
    var error: String?

    // MARK: - Login

    func login() async -> Bool {
        guard validateLogin() else { return false }

        loading = true
        error = nil
        defer { loading = false }

        do {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🔐 LOGIN START")
            print("📱 phone:", cleanPhone)
            print("🌐 backend:", GRUServerConfiguration.httpBaseURL)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            let response = try await AuthService.shared.login(
                phone: cleanPhone,
                password: password
            )

            try await acceptFreshSession(
                response: response,
                fallbackNickname: nil
            )

            print("✅ LOGIN COMPLETE")
            print("👤 userID:", response.userId)
            return true
        } catch {
            rejectFailedAuth(error)
            return false
        }
    }

    // MARK: - Register

    func register() async -> Bool {
        guard validateRegistration() else { return false }

        loading = true
        error = nil
        defer { loading = false }

        do {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🆕 REGISTER START")
            print("📱 phone:", cleanPhone)
            print("👤 nickname:", cleanNickname)
            print("🌐 backend:", GRUServerConfiguration.httpBaseURL)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            let response = try await AuthService.shared.register(
                phone: cleanPhone,
                password: password,
                nickname: cleanNickname
            )

            try await acceptFreshSession(
                response: response,
                fallbackNickname: cleanNickname
            )

            print("✅ REGISTER COMPLETE")
            print("👤 userID:", response.userId)
            return true
        } catch {
            rejectFailedAuth(error)
            return false
        }
    }

    // MARK: - Fresh session transaction

    private func acceptFreshSession(
        response: AuthResponse,
        fallbackNickname: String?
    ) async throws {
        let cleanToken = response.token
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanUserID = response.userId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToken.isEmpty else {
            throw LoginViewModelError.emptyToken
        }

        guard !cleanUserID.isEmpty else {
            throw LoginViewModelError.emptyUserID
        }

        /*
         The auth response alone is not enough. Before MainView can ever see
         this session, prove that the same backend accepts the freshly issued
         JWT on an authenticated endpoint.
        */
        let probe = await APIClient.shared.probeServer(token: cleanToken)

        guard let statusCode = probe.statusCode,
              (200...299).contains(statusCode) else {
            throw LoginViewModelError.tokenRejected(
                statusCode: probe.statusCode,
                message: probe.message
            )
        }

        // Stop every reconnect path that still carries the previous JWT.
        WebSocketService.shared.resetSession()
        TokenStorage.shared.clear()
        ChatService.shared.clearAuthenticatedUser()
        CacheStorage.shared.clearCurrentUser()

        // Persist only the JWT that has just passed server validation.
        TokenStorage.shared.save(
            token: cleanToken,
            userID: cleanUserID
        )

        guard TokenStorage.shared.belongsToCurrentBackend else {
            TokenStorage.shared.clear()
            throw LoginViewModelError.backendBindingFailed
        }

        guard TokenStorage.shared.token == cleanToken else {
            TokenStorage.shared.clear()
            throw LoginViewModelError.tokenSaveFailed
        }

        guard TokenStorage.shared.userID == cleanUserID else {
            TokenStorage.shared.clear()
            throw LoginViewModelError.userIDSaveFailed
        }

        applyUser(
            response: response,
            fallbackNickname: fallbackNickname
        )

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ FRESH SESSION VERIFIED")
        print("✅ protected endpoint status:", statusCode)
        print("✅ backend binding:", TokenStorage.shared.storedBackend ?? "nil")
        print("🔐 token length:", cleanToken.count)
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    private func rejectFailedAuth(_ authError: Error) {
        WebSocketService.shared.resetSession()
        TokenStorage.shared.clear()
        ChatService.shared.clearAuthenticatedUser()

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("❌ AUTH ERROR")
        print(authError.localizedDescription)
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        error = authError.localizedDescription
    }

    // MARK: - Apply user

    private func applyUser(
        response: AuthResponse,
        fallbackNickname: String?
    ) {
        let displayName: String?

        if let nickname = response.nickname?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !nickname.isEmpty {
            displayName = nickname
        } else if let fallbackNickname {
            let clean = fallbackNickname
                .trimmingCharacters(in: .whitespacesAndNewlines)
            displayName = clean.isEmpty ? nil : clean
        } else {
            displayName = nil
        }

        ChatService.shared.applyAuthenticatedUser(
            serverID: response.userId,
            displayName: displayName
        )
    }

    // MARK: - Validation

    private func validateLogin() -> Bool {
        error = nil

        guard !cleanPhone.isEmpty else {
            error = GRUL10n.text("Введите номер телефона")
            return false
        }

        guard !password.isEmpty else {
            error = GRUL10n.text("Введите пароль")
            return false
        }

        return true
    }

    private func validateRegistration() -> Bool {
        error = nil

        guard !cleanPhone.isEmpty else {
            error = GRUL10n.text("Введите номер телефона")
            return false
        }

        guard !cleanNickname.isEmpty else {
            error = GRUL10n.text("Введите имя")
            return false
        }

        guard !password.isEmpty else {
            error = GRUL10n.text("Введите пароль")
            return false
        }

        guard password.count >= 6 else {
            error = GRUL10n.text("Пароль должен содержать минимум 6 символов")
            return false
        }

        return true
    }

    private var cleanPhone: String {
        phone.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canLogin: Bool {
        !cleanPhone.isEmpty && !password.isEmpty && !loading
    }

    var canRegister: Bool {
        !cleanPhone.isEmpty &&
        !cleanNickname.isEmpty &&
        !password.isEmpty &&
        !loading
    }
}

private enum LoginViewModelError: LocalizedError {
    case emptyToken
    case emptyUserID
    case tokenSaveFailed
    case userIDSaveFailed
    case backendBindingFailed
    case tokenRejected(statusCode: Int?, message: String)

    var errorDescription: String? {
        switch self {
        case .emptyToken:
            return GRUL10n.text("Сервер не вернул токен авторизации")
        case .emptyUserID:
            return GRUL10n.text("Сервер не вернул ID пользователя")
        case .tokenSaveFailed:
            return GRUL10n.text("Не удалось сохранить новую сессию")
        case .userIDSaveFailed:
            return GRUL10n.text("Не удалось сохранить ID новой сессии")
        case .backendBindingFailed:
            return GRUL10n.text("Новая сессия не привязалась к текущему backend")
        case .tokenRejected(let statusCode, let message):
            if let statusCode {
                return "Backend отклонил только что выданную сессию (HTTP \(statusCode)). \(message)"
            }
            return "Не удалось проверить новую сессию на backend. \(message)"
        }
    }
}
