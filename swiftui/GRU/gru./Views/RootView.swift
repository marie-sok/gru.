//
//  RootView.swift
//  gru.
//
//  Created by Maria Morozova on 23.08.2026.
//

import SwiftUI
import Combine
import LocalAuthentication
import UIKit

@MainActor
struct RootView: View {

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("gru.settings.notifications.resetOnOpen") private var resetBadgeOnOpen = true
    @AppStorage("gru.release.onboarding.v11") private var didFinishOnboarding = false
    @AppStorage("gru.settings.security.biometricsEnabled") private var biometricsEnabled = false
    @State private var isBiometricLocked = false
    @State private var isBiometricPromptInFlight = false
    @State private var suppressAutomaticBiometricRetry = false

    @AppStorage(GRUTheme.selectionKey)
    private var themeRawValue = GRUAppTheme.blackMoonCat.rawValue

    @AppStorage(GRUAppLanguage.storageKey)
    private var appLanguageRawValue = GRUAppLanguage.defaultLanguage.rawValue

    @State private var isAuthenticated = false
    @State private var isCheckingSession = true

    /*
     v3 is a deliberate hard boundary for the beta auth rewrite.
     It purges every old Keychain/UserDefaults session exactly once so no JWT
     created by the previous storage implementation can enter this build.
    */
    private let sessionMigrationKey = "gru.sessionMigration.v3"

    private var appLanguage: GRUAppLanguage {
        GRUAppLanguage(rawValue: appLanguageRawValue) ?? .defaultLanguage
    }

    var body: some View {
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
                ZStack {
                    MainView()
                        .allowsHitTesting(!(isBiometricLocked && biometricsEnabled))

                    if isBiometricLocked && biometricsEnabled {
                        biometricLockOverlay
                            .zIndex(100)
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
        .task {
            await checkSession()
        }
        .onChange(of: isAuthenticated) { _, authenticated in
            if authenticated {
                dismissAnyKeyboard()
                DispatchQueue.main.async {
                    dismissAnyKeyboard()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                if resetBadgeOnOpen {
                    NotificationService.shared.clearBadge()
                }

                // LocalAuthentication may temporarily move the scene through
                // inactive/active while the system sheet is visible. Never
                // interpret that transition as a new unlock request.
                if biometricsEnabled &&
                    isAuthenticated &&
                    didFinishOnboarding &&
                    isBiometricLocked &&
                    !isBiometricPromptInFlight &&
                    !suppressAutomaticBiometricRetry {
                    authenticateWithBiometrics(userInitiated: false)
                }
            } else if newPhase == .background {
                // Only a real background transition re-arms biometric lock.
                if biometricsEnabled &&
                    isAuthenticated &&
                    !isBiometricPromptInFlight {
                    isBiometricLocked = true
                    suppressAutomaticBiometricRetry = false
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .gruSessionInvalidated)
        ) { _ in
            handleSessionInvalidated()
        }
        .preferredColorScheme(.dark)
        .environment(\.locale, appLanguage.locale)
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

            isAuthenticated = false
            isCheckingSession = false
            return
        }

        activateAuthenticatedSession(
            token: token,
            userID: userID,
            requireBiometricUnlock: true
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
        dismissAnyKeyboard()
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
            userID: userID,
            requireBiometricUnlock: false
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
        userID: String,
        requireBiometricUnlock: Bool
    ) {
        guard TokenStorage.shared.token == token,
              TokenStorage.shared.userID == userID else {
            isAuthenticated = false
            return
        }

        dismissAnyKeyboard()
        ChatService.shared.restoreSession()
        applyLocalProfile()
        isAuthenticated = true

        DispatchQueue.main.async {
            dismissAnyKeyboard()
        }

        if biometricsEnabled && requireBiometricUnlock {
            isBiometricLocked = true
            suppressAutomaticBiometricRetry = false

            // Let the authenticated SwiftUI hierarchy settle before asking
            // LocalAuthentication to present its system sheet. This avoids a
            // visible hitch when the secure screenshot canvas is also mounting.
            Task { @MainActor in
                await Task.yield()
                guard isAuthenticated,
                      biometricsEnabled,
                      isBiometricLocked else { return }
                authenticateWithBiometrics(userInitiated: false)
            }
        } else {
            isBiometricLocked = false
            isBiometricPromptInFlight = false
            suppressAutomaticBiometricRetry = false
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
        isBiometricLocked = false
        isBiometricPromptInFlight = false
        suppressAutomaticBiometricRetry = false
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

    func dismissAnyKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
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

                Text(GRUL10n.text("Your gateway to the world"))
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
        .accessibilityLabel("gru. — \(GRUL10n.text("Your gateway to the world"))")
        .accessibilityHint(GRUL10n.text("Коснитесь экрана, чтобы продолжить"))
    }
}

#Preview {
    RootView()
}

private extension RootView {
    var biometricLockOverlay: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "faceid")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(GRUColors.accent)

                VStack(spacing: 8) {
                    Text(GRUL10n.text("gru. заблокирован"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(GRUColors.text)

                    Text(GRUL10n.text("Для доступа требуется подтверждение личности"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    suppressAutomaticBiometricRetry = false
                    authenticateWithBiometrics(userInitiated: true)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                        Text(GRUL10n.text("Разблокировать"))
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
                .disabled(isBiometricPromptInFlight)
                .padding(.top, 12)
            }
            .padding(32)
        }
    }

    func authenticateWithBiometrics(userInitiated: Bool) {
        guard biometricsEnabled && isAuthenticated else { return }
        guard !isBiometricPromptInFlight else { return }
        guard userInitiated || !suppressAutomaticBiometricRetry else { return }

        isBiometricPromptInFlight = true

        let context = LAContext()
        context.interactionNotAllowed = false

        var authError: NSError?
        let reason = GRUL10n.text("Разблокируйте доступ к приложению gru.")

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            isBiometricPromptInFlight = false
            isBiometricLocked = false
            suppressAutomaticBiometricRetry = false
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        ) { success, _ in
            DispatchQueue.main.async {
                isBiometricPromptInFlight = false

                if success {
                    suppressAutomaticBiometricRetry = false
                    // Avoid animating the entire secure-hosted hierarchy after
                    // Face ID. Removing the lightweight lock overlay in one
                    // transaction is visibly smoother on physical devices.
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        isBiometricLocked = false
                    }
                } else {
                    isBiometricLocked = true
                    suppressAutomaticBiometricRetry = true
                }
            }
        }
    }
}
