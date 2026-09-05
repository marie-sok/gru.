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

    private let sessionMigrationKey = "gru.sessionMigration.v1"

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
            checkSession()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                if resetBadgeOnOpen {
                    NotificationService.shared.clearBadge()
                }
                if biometricsEnabled && isAuthenticated && didFinishOnboarding && isBiometricLocked {
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
    func checkSession() {
        performOneTimeSessionResetIfNeeded()

        let token = TokenStorage.shared.token
        let userID = TokenStorage.shared.userID

        if let token,
           !token.isEmpty,
           let userID,
           !userID.isEmpty {
            ChatService.shared.restoreSession()
            applyLocalProfile()
            isAuthenticated = true

            if biometricsEnabled {
                isBiometricLocked = true
                authenticateWithBiometrics()
            }
        } else {
            isAuthenticated = false
        }

        isCheckingSession = false
    }

    func performOneTimeSessionResetIfNeeded() {
        let defaults = UserDefaults.standard
        let alreadyMigrated = defaults.bool(forKey: sessionMigrationKey)
        guard !alreadyMigrated else { return }

        TokenStorage.shared.clear()
        ChatService.shared.clearAuthenticatedUser()
        defaults.set(true, forKey: sessionMigrationKey)

        print("🧹 Old gru. session cleared")
    }

    func handleSessionInvalidated() {
        isCheckingSession = false

        withAnimation(.easeInOut(duration: 0.25)) {
            isAuthenticated = false
        }

        print("🔐 gru. session expired — LoginView")
    }

    func handleSuccessfulLogin() {
        guard
            let token = TokenStorage.shared.token,
            !token.isEmpty,
            let userID = TokenStorage.shared.userID,
            !userID.isEmpty
        else {
            print("❌ Login completed but session was not saved")
            isAuthenticated = false
            return
        }

        ChatService.shared.restoreSession()
        applyLocalProfile()

        withAnimation(.easeInOut(duration: 0.25)) {
            isAuthenticated = true
            if biometricsEnabled {
                isBiometricLocked = true
                authenticateWithBiometrics()
            }
        }

        print("✅ gru. session authenticated")
    }

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
        var error: NSError?
        let reason = "Разблокируйте доступ к приложению gru."

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
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
