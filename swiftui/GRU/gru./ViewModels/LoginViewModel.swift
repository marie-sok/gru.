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

    // A fresh login is not allowed to enter MainView while the server already
    // pins another E2EE identity and this installation cannot prove possession
    // of the matching private keys.
    var needsE2EERecovery = false
    var recoveryCodeInput = ""
    var recoveryError: String?

    // Shown once when this installation creates or repairs the recovery backup.
    // The value never goes to the GRU backend.
    var pendingRecoveryCode: String?

    // MARK: - Login

    func login() async -> Bool {
        guard validateLogin() else { return false }

        loading = true
        error = nil
        recoveryError = nil
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

            let ready = try await acceptFreshSession(
                response: response,
                fallbackNickname: nil
            )

            if ready {
                print("✅ LOGIN COMPLETE")
                print("👤 userID:", response.userId)
            } else {
                print("🔐 LOGIN PAUSED FOR E2EE RECOVERY")
            }
            return ready
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
        recoveryError = nil
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

            let ready = try await acceptFreshSession(
                response: response,
                fallbackNickname: cleanNickname
            )

            if ready {
                print("✅ REGISTER COMPLETE")
                print("👤 userID:", response.userId)
            }
            return ready
        } catch {
            rejectFailedAuth(error)
            return false
        }
    }

    // MARK: - E2EE recovery gate

    func restoreE2EEIdentity(recoveryCode: String? = nil) async -> Bool {
        guard let token = TokenStorage.shared.token, !token.isEmpty,
              let userID = TokenStorage.shared.userID, !userID.isEmpty else {
            recoveryError = GRUL10n.text("Сессия недоступна. Войдите снова.")
            return false
        }

        loading = true
        recoveryError = nil
        defer { loading = false }

        do {
            let code = recoveryCode?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            try await GRUE2EERecoveryService.shared.restoreIdentity(
                token: token,
                userID: userID,
                recoveryCode: (code?.isEmpty == false) ? code : nil
            )

            // A restore is complete only if the exact recovered public identity
            // still equals the account identity pinned by the backend.
            let serverIdentity = try await E2EEAPIService.shared.identity(
                for: userID,
                token: token
            )
            let localIdentity = try GRUE2EE.shared.publicIdentity()
            guard localIdentity == serverIdentity.identity else {
                throw GRUE2EERecoveryError.identityMismatch
            }

            needsE2EERecovery = false
            recoveryCodeInput = ""
            recoveryError = nil
            return true
        } catch {
            recoveryError = error.localizedDescription
            return false
        }
    }

    func cancelE2EERecovery() {
        needsE2EERecovery = false
        recoveryCodeInput = ""
        recoveryError = nil
        pendingRecoveryCode = nil
        WebSocketService.shared.resetSession()
        TokenStorage.shared.clear()
        ChatService.shared.clearAuthenticatedUser()
        CacheStorage.shared.clearCurrentUser()
    }

    func acknowledgeRecoveryCode() {
        pendingRecoveryCode = nil
    }

    // MARK: - Fresh session transaction

    private func acceptFreshSession(
        response: AuthResponse,
        fallbackNickname: String?
    ) async throws -> Bool {
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

        let probe = await APIClient.shared.probeServer(token: cleanToken)

        guard let statusCode = probe.statusCode,
              (200...299).contains(statusCode) else {
            throw LoginViewModelError.tokenRejected(
                statusCode: probe.statusCode,
                message: probe.message
            )
        }

        WebSocketService.shared.resetSession()
        TokenStorage.shared.clear()
        ChatService.shared.clearAuthenticatedUser()
        CacheStorage.shared.clearCurrentUser()

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

        let e2eeReady = try await prepareE2EEForAuthenticatedSession(
            token: cleanToken,
            userID: cleanUserID
        )

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ FRESH SESSION VERIFIED")
        print("✅ protected endpoint status:", statusCode)
        print("✅ backend binding:", TokenStorage.shared.storedBackend ?? "nil")
        print("🔐 token length:", cleanToken.count)
        print("🔐 E2EE ready:", e2eeReady)
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        return e2eeReady
    }

    /// Never call publicIdentity() until we know whether the server already has
    /// an identity. publicIdentity() creates keys when they are absent; doing it
    /// first on a reinstall would create the exact accidental identity change
    /// this gate is designed to prevent.
    private func prepareE2EEForAuthenticatedSession(
        token: String,
        userID: String
    ) async throws -> Bool {
        needsE2EERecovery = false
        recoveryError = nil
        pendingRecoveryCode = nil

        let serverIdentity: E2EEKeyDTO?
        do {
            serverIdentity = try await E2EEAPIService.shared.identity(
                for: userID,
                token: token
            )
        } catch APIError.notFound {
            serverIdentity = nil
        }

        let recoveryStatus = GRUE2EERecoveryService.shared.status(userID: userID)

        if let serverIdentity {
            // Existing account identity: do not generate any local replacement.
            guard recoveryStatus.hasLocalIdentity else {
                needsE2EERecovery = true
                return false
            }

            let localIdentity = try GRUE2EE.shared.publicIdentity()
            guard localIdentity == serverIdentity.identity else {
                needsE2EERecovery = true
                return false
            }

            // Existing device may predate the recovery feature. Repair that
            // before allowing beta use, rather than waiting for the next phone.
            let hasRemoteBackup = try await remoteRecoveryBackupExists(token: token)
            if !recoveryStatus.hasSynchronizedRecoveryKey || !hasRemoteBackup {
                let created = try await GRUE2EERecoveryService.shared.createOrRefreshBackup(
                    token: token,
                    userID: userID
                )
                pendingRecoveryCode = created.recoveryCode
            }
            return true
        }

        // No server identity yet: this is a new account or a pre-E2EE account.
        // Only here is it safe to generate and publish a fresh local identity.
        _ = try await E2EEAPIService.shared.publishIdentity(token: token)
        let created = try await GRUE2EERecoveryService.shared.createOrRefreshBackup(
            token: token,
            userID: userID
        )
        pendingRecoveryCode = created.recoveryCode
        return true
    }

    private func remoteRecoveryBackupExists(token: String) async throws -> Bool {
        do {
            _ = try await APIClient.shared.request(
                path: "/e2ee/recovery/me",
                method: "GET",
                token: token
            )
            return true
        } catch APIError.notFound {
            return false
        }
    }

    private func rejectFailedAuth(_ authError: Error) {
        WebSocketService.shared.resetSession()
        TokenStorage.shared.clear()
        ChatService.shared.clearAuthenticatedUser()

        needsE2EERecovery = false
        recoveryCodeInput = ""
        recoveryError = nil
        pendingRecoveryCode = nil

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("❌ AUTH ERROR")
        print(authError.localizedDescription)
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        error = localizedAuthError(authError)
    }

    private func localizedAuthError(_ authError: Error) -> String {
        let raw = authError.localizedDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = raw.lowercased()

        if normalized.contains("user already exists") {
            return GRUL10n.text("An account with this phone number already exists.")
        }

        if normalized.contains("user not found") {
            return GRUL10n.text("No account found for this phone number.")
        }

        if normalized.contains("wrong password") {
            return GRUL10n.text("Incorrect password.")
        }

        return raw.isEmpty
            ? GRUL10n.text("Authentication failed.")
            : raw
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
            error = GRUL10n.text("Enter your phone number.")
            return false
        }

        guard isPhonePlausible else {
            error = GRUL10n.text("Enter a valid phone number with country code.")
            return false
        }

        guard !password.isEmpty else {
            error = GRUL10n.text("Enter your password.")
            return false
        }

        return true
    }

    private func validateRegistration() -> Bool {
        error = nil

        guard !cleanPhone.isEmpty else {
            error = GRUL10n.text("Enter your phone number.")
            return false
        }

        guard isPhonePlausible else {
            error = GRUL10n.text("Enter a valid phone number with country code.")
            return false
        }

        guard !cleanNickname.isEmpty else {
            error = GRUL10n.text("Enter a nickname.")
            return false
        }

        guard !password.isEmpty else {
            error = GRUL10n.text("Enter your password.")
            return false
        }

        guard password.count >= 6 else {
            error = GRUL10n.text("Password must contain at least 6 characters.")
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

    private var phoneDigitCount: Int {
        cleanPhone.filter { $0.isNumber }.count
    }

    private var isPhonePlausible: Bool {
        (7...15).contains(phoneDigitCount)
    }

    var canLogin: Bool {
        isPhonePlausible && !password.isEmpty && !loading
    }

    var canRegister: Bool {
        isPhonePlausible && !cleanNickname.isEmpty && password.count >= 6 && !loading
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
                return GRUL10n.format(
                    "Backend rejected the new session (HTTP %d). %@",
                    statusCode,
                    message
                )
            }
            return GRUL10n.format(
                "Could not verify the new session on the backend. %@",
                message
            )
        }
    }
}
