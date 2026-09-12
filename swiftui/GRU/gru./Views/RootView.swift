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

    @State private var isSystemUnlockInFlight = false
    @State private var needsUnlockAfterBackground = false

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
                MainView()
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
            switch newPhase {
            case .active:
                if resetBadgeOnOpen {
                    NotificationService.shared.clearBadge()
                }

                // Only a real background transition arms the next unlock.
                // The LocalAuthentication sheet itself may move the app through
                // inactive/active, so consuming this flag before authentication
                // prevents a re-entrant Face ID loop on physical iPhones.
                guard needsUnlockAfterBackground,
                      biometricsEnabled,
                      isAuthenticated,
                      !isSystemUnlockInFlight else {
                    return
                }

                needsUnlockAfterBackground = false
                isCheckingSession = true

                Task {
                    let unlocked = await authenticateForAppAccess()
                    guard unlocked else {
                        returnToLoginAfterUnlockFailure()
                        return
                    }

                    isCheckingSession = false
                }

            case .background:
                guard biometricsEnabled, isAuthenticated else { return }
                needsUnlockAfterBackground = true

            default:
                break
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

        if biometricsEnabled {
            let unlocked = await authenticateForAppAccess()
            guard unlocked else {
                returnToLoginAfterUnlockFailure()
                return
            }
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

        dismissAnyKeyboard()
        ChatService.shared.restoreSession()
        applyLocalProfile()
        isAuthenticated = true
        needsUnlockAfterBackground = false

        DispatchQueue.main.async {
            dismissAnyKeyboard()
        }
    }

    // MARK: - System unlock

    func authenticateForAppAccess() async -> Bool {
        guard biometricsEnabled else { return true }
        guard !isSystemUnlockInFlight else { return false }

        isSystemUnlockInFlight = true
        defer { isSystemUnlockInFlight = false }

        let context = LAContext()
        context.interactionNotAllowed = false

        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            print("⚠️ Device-owner authentication unavailable: \(authError?.localizedDescription ?? "unknown")")
            return false
        }

        let reason = GRUL10n.text("Подтвердите личность для входа в GRU")

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) { success, error in
                if let error {
                    print("🔐 GRU unlock result: \(error.localizedDescription)")
                }
                continuation.resume(returning: success)
            }
        }
    }

    func returnToLoginAfterUnlockFailure() {
        // No custom lock screen and no retry loop. A cancelled/failed system
        // authentication returns to the normal sign-in surface.
        clearLocalSession()
        isAuthenticated = false
        isCheckingSession = false
        needsUnlockAfterBackground = false
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
        isSystemUnlockInFlight = false
        needsUnlockAfterBackground = false
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
