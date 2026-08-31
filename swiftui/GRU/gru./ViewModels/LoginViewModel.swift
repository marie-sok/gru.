import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {

    // MARK: - Input

    var phone = ""
    var password = ""
    var nickname = ""

    // MARK: - State

    var loading = false
    var error: String?

    // MARK: - Login

    func login() async -> Bool {

        guard validateLogin() else {
            return false
        }

        loading = true
        error = nil

        defer {
            loading = false
        }

        do {

            print("")
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )
            print(
                "🔐 LOGIN START"
            )
            print(
                "📱 phone:",
                cleanPhone
            )
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            let response =
                try await AuthService.shared.login(
                    phone: cleanPhone,
                    password: password
                )

            print(
                "✅ LOGIN RESPONSE RECEIVED"
            )

            /*
             Важно:
             старый WebSocket мог продолжать
             reconnect с предыдущим JWT.
             Сначала полностью его останавливаем.
             */

            WebSocketService.shared
                .resetSession()

            /*
             Очищаем старую локальную
             авторизованную сессию.
             */

            TokenStorage.shared
                .clear()

            ChatService.shared
                .clearAuthenticatedUser()

            /*
             Сохраняем только что
             полученный JWT.
             */

            try saveAndVerifySession(
                response: response
            )

            /*
             Обновляем currentUser
             только после успешного
             сохранения сессии.
             */

            applyUser(
                response: response
            )

            print("")
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )
            print(
                "✅ LOGIN COMPLETE"
            )
            print(
                "👤 userID:",
                response.userId
            )
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            return true

        } catch {

            handleError(
                error
            )

            return false
        }
    }

    // MARK: - Register

    func register() async -> Bool {

        guard validateRegistration() else {
            return false
        }

        loading = true
        error = nil

        defer {
            loading = false
        }

        do {

            print("")
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )
            print(
                "🆕 REGISTER START"
            )
            print(
                "📱 phone:",
                cleanPhone
            )
            print(
                "👤 nickname:",
                cleanNickname
            )
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            let response =
                try await AuthService.shared.register(
                    phone: cleanPhone,
                    password: password,
                    nickname: cleanNickname
                )

            print(
                "✅ REGISTER RESPONSE RECEIVED"
            )

            /*
             Убираем любое старое
             WebSocket-соединение.
             */

            WebSocketService.shared
                .resetSession()

            /*
             Полностью заменяем
             предыдущую сессию.
             */

            TokenStorage.shared
                .clear()

            ChatService.shared
                .clearAuthenticatedUser()

            try saveAndVerifySession(
                response: response
            )

            applyUser(
                response: response,
                fallbackNickname:
                    cleanNickname
            )

            print("")
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )
            print(
                "✅ REGISTER COMPLETE"
            )
            print(
                "👤 userID:",
                response.userId
            )
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            return true

        } catch {

            handleError(
                error
            )

            return false
        }
    }

    // MARK: - Save + Verify Session

    private func saveAndVerifySession(
        response: AuthResponse
    ) throws {

        let cleanToken =
            response.token
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let cleanUserID =
            response.userId
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !cleanToken.isEmpty else {

            throw LoginViewModelError
                .emptyToken
        }

        guard !cleanUserID.isEmpty else {

            throw LoginViewModelError
                .emptyUserID
        }

        TokenStorage.shared.save(
            token: cleanToken,
            userID: cleanUserID
        )

        let savedToken =
            TokenStorage.shared.token

        let savedUserID =
            TokenStorage.shared.userID

        // MARK: Safe JWT Diagnostics

        print("")
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
        print(
            "🔐 SESSION SAVE CHECK"
        )
        print(
            "🔐 LOGIN TOKEN LENGTH:",
            cleanToken.count
        )
        print(
            "💾 SAVED TOKEN LENGTH:",
            savedToken?.count ?? 0
        )
        print(
            "✅ TOKEN SAVED CORRECTLY:",
            savedToken == cleanToken
        )
        print(
            "✅ USER ID SAVED CORRECTLY:",
            savedUserID == cleanUserID
        )
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        /*
         Сам JWT специально
         никогда не выводим в Console.
         */

        guard savedToken == cleanToken else {

            TokenStorage.shared
                .clear()

            throw LoginViewModelError
                .tokenSaveFailed
        }

        guard savedUserID == cleanUserID else {

            TokenStorage.shared
                .clear()

            throw LoginViewModelError
                .userIDSaveFailed
        }
    }

    // MARK: - Apply User

    private func applyUser(
        response: AuthResponse,
        fallbackNickname: String? = nil
    ) {

        let displayName: String?

        if let nickname =
            response.nickname?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                ),
           !nickname.isEmpty {

            displayName =
                nickname

        } else if let fallbackNickname {

            let cleanFallback =
                fallbackNickname
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            displayName =
                cleanFallback.isEmpty
                ? nil
                : cleanFallback

        } else {

            displayName =
                nil
        }

        ChatService.shared
            .applyAuthenticatedUser(
                serverID:
                    response.userId,
                displayName:
                    displayName
            )
    }

    // MARK: - Validation Login

    private func validateLogin() -> Bool {

        error = nil

        guard !cleanPhone.isEmpty else {

            error =
                "Введите номер телефона"

            return false
        }

        guard !password.isEmpty else {

            error =
                "Введите пароль"

            return false
        }

        return true
    }

    // MARK: - Validation Registration

    private func validateRegistration() -> Bool {

        error = nil

        guard !cleanPhone.isEmpty else {

            error =
                "Введите номер телефона"

            return false
        }

        guard !cleanNickname.isEmpty else {

            error =
                "Введите имя"

            return false
        }

        guard !password.isEmpty else {

            error =
                "Введите пароль"

            return false
        }

        guard password.count >= 6 else {

            error =
                "Пароль должен содержать минимум 6 символов"

            return false
        }

        return true
    }

    // MARK: - Error

    private func handleError(
        _ error: Error
    ) {

        print("")
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
        print(
            "❌ AUTH ERROR"
        )
        print(
            error.localizedDescription
        )
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        self.error =
            error.localizedDescription
    }

    // MARK: - Helpers

    private var cleanPhone: String {

        phone.trimmingCharacters(
            in:
                .whitespacesAndNewlines
        )
    }

    private var cleanNickname: String {

        nickname.trimmingCharacters(
            in:
                .whitespacesAndNewlines
        )
    }

    var canLogin: Bool {

        !cleanPhone.isEmpty &&
        !password.isEmpty &&
        !loading
    }

    var canRegister: Bool {

        !cleanPhone.isEmpty &&
        !cleanNickname.isEmpty &&
        !password.isEmpty &&
        !loading
    }
}

// MARK: - Login View Model Error

private enum LoginViewModelError:
    LocalizedError {

    case emptyToken
    case emptyUserID
    case tokenSaveFailed
    case userIDSaveFailed

    var errorDescription: String? {

        switch self {

        case .emptyToken:

            return
                "Сервер не вернул токен авторизации"

        case .emptyUserID:

            return
                "Сервер не вернул ID пользователя"

        case .tokenSaveFailed:

            return
                "Не удалось сохранить новую сессию"

        case .userIDSaveFailed:

            return
                "Не удалось сохранить данные пользователя"
        }
    }
}
