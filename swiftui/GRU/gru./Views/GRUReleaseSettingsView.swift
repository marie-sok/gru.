import SwiftUI
import UIKit

@MainActor
struct GRUReleaseSettingsView: View {
    @State private var showLogoutConfirmation = false
    @State private var backendProbe: GRUServerProbeResult?

    @AppStorage(GRUTheme.selectionKey)
    private var themeRaw = GRUAppTheme.blackMoonCat.rawValue

    @AppStorage("showStatus") private var showStatus = true
    @AppStorage("readReceipts") private var readReceipts = true
    @AppStorage("gru.settings.privacy.typing") private var typing = true
    @AppStorage("notifications") private var notifications = true
    @AppStorage("sounds") private var sounds = true
    @AppStorage("gru.settings.security.biometricsEnabled") private var biometrics = false
    @AppStorage("gru.settings.security.hideSwitcherPreview") private var hideSwitcherPreview = true
    @AppStorage("gru.settings.data.dataSaver") private var dataSaver = false

    private var currentTheme: GRUAppTheme {
        let candidate = GRUAppTheme(rawValue: themeRaw) ?? .blackMoonCat
        return GRUThemePolicy.allowed.contains(candidate) ? candidate : .blackMoonCat
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    identityCard
                    themeCard
                    messagingCard
                    securityCard
                    deviceCard
                    logoutCard
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .background(GRUAppBackdrop())
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            backendProbe = await APIClient.shared.probeServer()
        }
        .confirmationDialog(
            "Выйти из gru.?",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Выйти", role: .destructive) {
                logout()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Текущая сессия и локальный кэш аккаунта будут очищены.")
        }
    }
}

private extension GRUReleaseSettingsView {
    var identityCard: some View {
        NavigationLink {
            ProfileView()
        } label: {
            HStack(spacing: 13) {
                GRUNeonIcon(
                    systemName: "person.crop.circle.fill",
                    size: 40,
                    iconSize: 16
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Профиль")
                        .font(.headline)
                        .foregroundStyle(GRUColors.text)
                    Text("имя • nickname • bio • аватар")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Circle()
                        .fill(backendColor)
                        .frame(width: 8, height: 8)
                    Text(backendTitle)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .releaseCard()
        }
        .buttonStyle(.plain)
    }

    var themeCard: some View {
        NavigationLink {
            GRUReleaseThemesView()
        } label: {
            ZStack(alignment: .bottomLeading) {
                GRUSignatureWallpaper(
                    theme: currentTheme,
                    intensity: 1.0,
                    animated: false
                )
                .frame(height: 138)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Темы")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.72))

                        Text(GRUThemePolicy.displayName(for: currentTheme))
                            .font(.system(size: 21, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("9 фирменных animated micro-art сцен")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    Spacer()

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(currentTheme.accent)
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(currentTheme.accent.opacity(0.28), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    var messagingCard: some View {
        VStack(spacing: 0) {
            releaseToggle("Уведомления", icon: "bell.fill", isOn: $notifications)
            releaseDivider
            releaseToggle("Звук", icon: "speaker.wave.2.fill", isOn: $sounds)
            releaseDivider
            releaseToggle("Показывать online", icon: "circle.fill", isOn: $showStatus)
            releaseDivider
            releaseToggle("Отчёты о прочтении", icon: "checkmark.circle.fill", isOn: $readReceipts)
            releaseDivider
            releaseToggle("Показывать «печатает…»", icon: "ellipsis.bubble.fill", isOn: $typing)
            releaseDivider
            releaseToggle("Экономия трафика", icon: "antenna.radiowaves.left.and.right", isOn: $dataSaver)
        }
        .releaseCard()
    }

    var securityCard: some View {
        VStack(spacing: 0) {
            releaseToggle("Face ID / код устройства", icon: "faceid", isOn: $biometrics)
            releaseDivider
            releaseToggle("Скрывать превью приложения", icon: "eye.slash.fill", isOn: $hideSwitcherPreview)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(GRUColors.accent)
                    .frame(width: 22)
                Text("Защита экрана активна для записи и трансляции. Снимок экрана iOS можно обнаружить только после события.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .releaseCard()
    }

    var deviceCard: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 12) {
                GRUNeonIcon(systemName: "iphone", size: 36, iconSize: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Разрешения iPhone")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(GRUColors.text)
                    Text("камера • микрофон • фото • контакты • локальная сеть")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .releaseCard()
        }
        .buttonStyle(.plain)
    }

    var logoutCard: some View {
        Button(role: .destructive) {
            showLogoutConfirmation = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Выйти из аккаунта")
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                Color.red.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    var backendTitle: String {
        guard let backendProbe else { return "checking" }
        if backendProbe.isReachable {
            if let code = backendProbe.statusCode, (200...299).contains(code) {
                return "backend online"
            }
            return "backend reachable"
        }
        return "backend offline"
    }

    var backendColor: Color {
        guard let backendProbe else { return .secondary }
        return backendProbe.isReachable ? GRUColors.accent : .red
    }

    var releaseDivider: some View {
        Divider()
            .overlay(GRUColors.separator)
            .padding(.leading, 50)
    }

    func releaseToggle(
        _ title: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GRUColors.accent)
                    .frame(width: 28, height: 28)
                    .background(GRUColors.accent.opacity(0.10), in: Circle())
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .tint(GRUColors.accent)
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
    }

    func logout() {
        CacheStorage.shared.clearCurrentUser()
        WebSocketService.shared.resetSession()
        TokenStorage.shared.clear()
        ChatService.shared.clearAuthenticatedUser()
        NotificationService.shared.removeAllNotifications()
        NotificationService.shared.clearBadge()

        NotificationCenter.default.post(
            name: .gruSessionInvalidated,
            object: nil
        )
    }
}

@MainActor
struct GRUReleaseThemesView: View {
    @AppStorage(GRUTheme.selectionKey)
    private var themeRaw = GRUAppTheme.blackMoonCat.rawValue

    @AppStorage("gru.settings.appearance.dynamicBackground")
    private var dynamicBackground = true

    @AppStorage("gru.settings.accessibility.reduceMotion")
    private var reduceMotion = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var selectedTheme: GRUAppTheme {
        let candidate = GRUAppTheme(rawValue: themeRaw) ?? .blackMoonCat
        return GRUThemePolicy.allowed.contains(candidate) ? candidate : .blackMoonCat
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                livePreview
                motionControls

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(GRUThemePolicy.allowed) { theme in
                        themeTile(theme)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(GRUAppBackdrop())
        .navigationTitle("Темы")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            GRUThemePolicy.migrateIfNeeded()
        }
    }
}

private extension GRUReleaseThemesView {
    var livePreview: some View {
        ZStack(alignment: .bottomLeading) {
            GRUSignatureWallpaper(
                theme: selectedTheme,
                intensity: 1.0,
                animated: dynamicBackground && !reduceMotion
            )
            .frame(height: 238)

            LinearGradient(
                colors: [.clear, .black.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(selectedTheme.accent)
                        .frame(width: 7, height: 7)
                    Text(dynamicBackground && !reduceMotion ? "LIVE" : "STATIC")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Text(GRUThemePolicy.displayName(for: selectedTheme))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(selectedTheme.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(2)
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(selectedTheme.accent.opacity(0.40), lineWidth: 1)
        }
        .shadow(color: selectedTheme.accent.opacity(0.14), radius: 24)
    }

    var motionControls: some View {
        HStack(spacing: 10) {
            compactToggle(
                title: "Живой фон",
                icon: "sparkles",
                isOn: $dynamicBackground
            )

            compactToggle(
                title: "Меньше движения",
                icon: "figure.walk.motion",
                isOn: $reduceMotion
            )
        }
    }

    func compactToggle(
        title: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(GRUColors.accent)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
        }
        .toggleStyle(.switch)
        .tint(GRUColors.accent)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .releaseCard()
    }

    func themeTile(_ theme: GRUAppTheme) -> some View {
        let isSelected = theme == selectedTheme

        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                themeRaw = theme.rawValue
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            ZStack(alignment: .bottomLeading) {
                GRUSignatureWallpaper(
                    theme: theme,
                    intensity: 1.0,
                    animated: false
                )
                .frame(height: 166)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.74)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: theme.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme.accent)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(theme.accent)
                        }
                    }

                    Text(GRUThemePolicy.displayName(for: theme))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                .padding(11)
            }
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(
                        isSelected ? theme.accent.opacity(0.95) : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 1.6 : 1
                    )
            }
            .scaleEffect(isSelected ? 1.0 : 0.985)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(GRUThemePolicy.displayName(for: theme))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension View {
    func releaseCard() -> some View {
        self
            .background(
                GRUColors.card.opacity(0.82),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.055), lineWidth: 1)
            }
    }
}
