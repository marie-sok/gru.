//
//  RootView.swift
//  gru
//
//  Created by Maria Morozova on 23.08.2026.
//


import SwiftUI
import Combine

@MainActor
struct RootView: View {

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("gru.settings.security.hideSwitcherPreview") private var hideSwitcherPreview = true
    @AppStorage("gru.settings.notifications.resetOnOpen") private var resetBadgeOnOpen = true
    @AppStorage("gru.release.onboarding.v11") private var didFinishOnboarding = false

    @AppStorage(GRUTheme.selectionKey)
    private var themeRawValue = GRUAppTheme.obsidian.rawValue

    // MARK: - State

    @State
    private var isAuthenticated = false

    @State
    private var isCheckingSession = true

    // MARK: - One-Time Reset


    private let sessionMigrationKey =
        "gru.sessionMigration.v1"

    // MARK: - Body

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
                        Text("gru")
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
            if newPhase == .active && resetBadgeOnOpen {
                NotificationService.shared.clearBadge()
            }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(
                    for:
                        .gruSessionInvalidated
                )
        ) {
            _ in

            handleSessionInvalidated()
        }
        .preferredColorScheme(.dark)
        .tint(
            (GRUAppTheme(rawValue: themeRawValue) ?? .obsidian).accent
        )
    }
}

// MARK: - Session

private extension RootView {

    func checkSession() {

        performOneTimeSessionResetIfNeeded()

        let token =
            TokenStorage.shared.token

        let userID =
            TokenStorage.shared.userID

        if let token,
           !token.isEmpty,
           let userID,
           !userID.isEmpty {

            ChatService.shared.restoreSession()

            applyLocalProfile()

            isAuthenticated = true

        } else {

            isAuthenticated = false
        }

        isCheckingSession = false
    }

    func performOneTimeSessionResetIfNeeded() {

        let defaults =
            UserDefaults.standard

        let alreadyMigrated =
            defaults.bool(
                forKey: sessionMigrationKey
            )

        guard !alreadyMigrated else {
            return
        }

        /*
         Удаляем старую сессию,
         где сохранялся только JWT.
         */

        TokenStorage.shared.clear()

        ChatService.shared
            .clearAuthenticatedUser()

        defaults.set(
            true,
            forKey: sessionMigrationKey
        )

        print(
            "🧹 Old GRU session cleared"
        )
    }

    func handleSessionInvalidated() {

        isCheckingSession =
            false

        withAnimation(
            .easeInOut(
                duration:
                    0.25
            )
        ) {

            isAuthenticated =
                false
        }

        print(
            "🔐 GRU session expired — LoginView"
        )
    }

    func handleSuccessfulLogin() {

        guard
            let token =
                TokenStorage.shared.token,
            !token.isEmpty,
            let userID =
                TokenStorage.shared.userID,
            !userID.isEmpty
        else {

            print(
                "❌ Login completed but session was not saved"
            )

            isAuthenticated = false

            return
        }

        ChatService.shared.restoreSession()

        applyLocalProfile()

        withAnimation(
            .easeInOut(
                duration: 0.25
            )
        ) {

            isAuthenticated = true
        }

        print(
            "✅ GRU session authenticated"
        )
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

// MARK: - Loading

private extension RootView {

    var loadingView: some View {

        ZStack {

            GRUAppBackdrop()

            VStack(
                spacing: 16
            ) {

                Text("gru")
                    .font(
                        .system(
                            size: 32,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        GRUColors.text
                    )

                ProgressView()
            }
        }
    }
}


// MARK: - V11 Release Onboarding

private struct GRUReleaseOnboardingView: View {
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            GRUAppBackdrop()

            VStack(spacing: 12) {
                Text("gru")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .tracking(-1.8)

                Text("твой выход в мир")
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
        .accessibilityLabel("gru — твой выход в мир")
        .accessibilityHint("Коснитесь экрана, чтобы продолжить")
    }
}


// MARK: - Preview

#Preview {

    RootView()
}
