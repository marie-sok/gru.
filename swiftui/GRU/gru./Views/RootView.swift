//
//  RootView.swift
//  gru.
//
//  Created by Maria Morozova on 23.08.2026.
//

import SwiftUI
import Combine
import LocalAuthentication

@MainActor
struct RootView: View {

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("gru.settings.security.hideSwitcherPreview") private var hideSwitcherPreview = true
    @AppStorage("gru.settings.notifications.resetOnOpen") private var resetBadgeOnOpen = true
    @AppStorage("gru.release.onboarding.v11") private var didFinishOnboarding = false
    @AppStorage("gru.settings.security.biometricsEnabled") private var biometricsEnabled = false
    @State private var isBiometricLocked = false

    @AppStorage(GRUTheme.selectionKey)
    private var themeRawValue = GRUAppTheme.blackMoonCat.rawValue

    @State private var isAuthenticated = false
    @State private var isCheckingSession = true

    /*
     v3 is a deliberate hard boundary for the beta auth rewrite.
     It purges every old Keychain/UserDefaults session exactly once so no JWT
     created by the previous storage implementation can enter this build.
    */
    private let sessionMigrationKey = "gru.sessionMigration.v3"

    var body: some View {
        ZStack {
            Group {
                if isCheckingSession {
                    loadingView
                } else if !didFinishOnboarding {
                    GRUReleaseOnboardingView {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            didFinishOnboarding = true
                        }
                    }
                } else if isAuthenticated {
                    MainView()
                        .blur(radius: (isBiometricLocked && biometricsEnabled) ? 18 : 0)
                        .disabled(isBiometricLocked && biometricsEnabled)
                        .overlay {
                            if isBiometricLocked && biometricsEnabled {
                                biometricLockOverlay
                            }
                        }
                } else {
                    LoginView(
                        onLogin: {
                            handleSuccessfulLogin()
                        }
                    )
                }
            }

            if hideSwitcherPreview && scenePhase != .active {
                ZStack {
                    GRUAppBackdrop()
                    VStack(spacing: 12) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(GRUColors.accent)
                        Text("gru.")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .task {
            await checkSession()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                if resetBadgeOnOpen {
                    NotificationService.shared.clearBadge()
                }

                if biometricsEnabled &&
                    isAuthenticated &&
                    didFinishOnboarding &&
                    isBiometricLocked {
                    authenticateWithBiometrics()
                }
            } else if newPhase == .background {
                if biometricsEnabled && isAuthenticated {
                    isBiometricLocked = true
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .gruSessionInvalidated)
        ) { _ in
            handleSessionInvalidated()
        }
        .preferredColorScheme(.dark)
        .tint(
            (GRUAppTheme(rawValue: themeRawValue) ?? .blackMoonCat).accent
        )
    }
}

private extension RootView {

    // MARK: - Bootstrap session gate

    func checkSession() async {
        performOneTimeHardSessionResetIfNeeded()

        guard let token = TokenStorage.shared.token,
              !token.isEmpty,
              let userID = TokenStorage.shared.userID,
              !userID.isEmpty,
              TokenStorage.shared.belongsToCurrentBackend else {
            isAuthenticated = false
            isCheckingSession = false
            return
        }

        let probe = await APIClient.shared.probeServer(token: token)

        guard let statusCode = probe.statusCode,
              (200...299).contains(statusCode) else {
            if probe.statusCode == 401 || probe.statusCode == 403 {
                clearLocalSession()
                print("🧹 Persisted GRU session rejected by backend")
            } else {
                print("⚠️ GRU session not admitted: \(probe.message)")
            }

            // Hard beta policy: never enter authenticated UI unless the current
            // backend has actually accepted the persisted JWT in this launch.
            isAuthenticated = false
            isCheckingSession = false
            return
        }

        activateAuthenticatedSession(
            token: token,
            userID: userID
        )

        isCheckingSession = false

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ PERSISTED SESSION VERIFIED")
        print("✅ HTTP:", statusCode)
        print("🌐 backend:", GRUServerConfiguration.httpBaseURL)
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    // MARK: - Login callback gate

    func handleSuccessfulLogin() {
        isCheckingSession = true
        isAuthenticated = false

        Task {
            await finalizeSuccessfulLogin()
        }
    }

    func finalizeSuccessfulLogin() async {
        guard let token = TokenStorage.shared.token,
              !token.isEmpty,
              let userID = TokenStorage.shared.userID,
              !userID.isEmpty,
              TokenStorage.shared.belongsToCurrentBackend else {
            clearLocalSession()
            isCheckingSession = false
            isAuthenticated = false
            print("❌ Login callback received without a complete backend-bound session")
            return
        }

        // Second server confirmation closes the gap between LoginViewModel and
        // MainView. MainView cannot start chat/WebSocket work until this passes.
        let probe = await APIClient.shared.probeServer(token: token)

        guard let statusCode = probe.statusCode,
              (200...299).contains(statusCode) else {
            clearLocalSession()
            isCheckingSession = false
            isAuthenticated = false
            print("❌ Fresh GRU session failed final gate: \(probe.message)")
            return
        }

        activateAuthenticatedSession(
            token: token,
            userID: userID
        )

        isCheckingSession = false

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ FINAL SESSION GATE PASSED")
        print("✅ HTTP:", statusCode)
        print("👤 userID:", userID)
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    func activateAuthenticatedSession(
        token: String,
        userID: String
    ) {
        guard TokenStorage.shared.token == token,
              TokenStorage.shared.userID == userID else {
            isAuthenticated = false
            return
        }

        ChatService.shared.restoreSession()
        applyLocalProfile()
        isAuthenticated = true

        if biometricsEnabled {
            isBiometricLocked = true
            authenticateWithBiometrics()
        }
    }

    // MARK: - Hard migration / clear

    func performOneTimeHardSessionResetIfNeeded() {
        let defaults = UserDefaults.standard
        let alreadyMigrated = defaults.bool(forKey: sessionMigrationKey)
        guard !alreadyMigrated else { return }

        WebSocketService.shared.resetSession()
        TokenStorage.shared.purgeAllKnownSessions()
        ChatService.shared.clearAuthenticatedUser()
        CacheStorage.shared.clearCurrentUser()
        NotificationService.shared.removeAllNotifications()
        NotificationService.shared.clearBadge()

        defaults.set(true, forKey: sessionMigrationKey)

        print("🧹 All pre-v3 GRU beta sessions purged")
    }

    func clearLocalSession() {
        CacheStorage.shared.clearCurrentUser()
        WebSocketService.shared.resetSession()
        TokenStorage.shared.clear()
        ChatService.shared.clearAuthenticatedUser()
        NotificationService.shared.removeAllNotifications()
        NotificationService.shared.clearBadge()
    }

    func handleSessionInvalidated() {
        clearLocalSession()
        isCheckingSession = false

        withAnimation(.easeInOut(duration: 0.25)) {
            isAuthenticated = false
        }

        print("🔐 GRU session invalidated — LoginView")
    }

    // MARK: - Local profile

    func applyLocalProfile() {
        let profile = ProfileStorage.shared
        let service = ChatService.shared

        profile.applyFallbackNickname(service.currentUser.displayName)
        service.currentUser.username = profile.username

        let nickname = profile.nickname
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !nickname.isEmpty {
            service.currentUser.displayName = nickname
        }
    }
}

private extension RootView {
    var loadingView: some View {
        ZStack {
            GRUAppBackdrop()

            VStack(spacing: 16) {
                Text("gru.")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(GRUColors.text)

                ProgressView()
            }
        }
    }
}

private struct GRUReleaseOnboardingView: View {
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            GRUAppBackdrop()

            VStack(spacing: 12) {
                Text("gru.")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .tracking(-1.8)

                Text("Your gateway to the world")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onFinish()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("gru. — Your gateway to the world")
        .accessibilityHint("Коснитесь экрана, чтобы продолжить")
    }
}

#Preview {
    RootView()
}

private extension RootView {
    var biometricLockOverlay: some View {
        ZStack {
            GRUAppBackdrop()

            VStack(spacing: 24) {
                Image(systemName: "faceid")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(GRUColors.accent)

                VStack(spacing: 8) {
                    Text("gru. заблокирован")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(GRUColors.text)

                    Text("Для доступа требуется подтверждение личности")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    authenticateWithBiometrics()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                        Text("Разблокировать")
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(GRUColors.accent)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
            .padding(32)
        }
        .transition(.opacity)
    }

    func authenticateWithBiometrics() {
        guard biometricsEnabled && isAuthenticated else { return }

        let context = LAContext()
        var authError: NSError?
        let reason = "Разблокируйте доступ к приложению gru."

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isBiometricLocked = false
                        }
                    }
                }
            }
        } else {
            isBiometricLocked = false
        }
    }
}
