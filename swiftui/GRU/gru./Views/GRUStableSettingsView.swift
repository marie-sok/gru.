import LocalAuthentication
import SwiftUI
import UIKit

@MainActor
struct GRUStableSettingsView: View {
    @State private var showLogoutConfirmation = false
    @AppStorage(GRUTheme.selectionKey) private var themeRaw = GRUAppTheme.blackMoonCat.rawValue

    private var currentTheme: GRUAppTheme {
        let candidate = GRUAppTheme(rawValue: themeRaw) ?? .blackMoonCat
        return GRUThemePolicy.allowed.contains(candidate) ? candidate : .blackMoonCat
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        row(
                            icon: "person.crop.circle.fill",
                            title: "Профиль",
                            subtitle: "Имя, username, фото и описание"
                        )
                    }
                }

                Section(GRUL10n.text("Приватность и безопасность")) {
                    NavigationLink {
                        GRUStablePrivacySettingsView()
                    } label: {
                        row(
                            icon: "hand.raised.fill",
                            title: "Конфиденциальность",
                            subtitle: "Online, прочтение и индикатор набора"
                        )
                    }

                    NavigationLink {
                        GRUStableSecuritySettingsView()
                    } label: {
                        row(
                            icon: "lock.shield.fill",
                            title: "Безопасность",
                            subtitle: "Face ID, код устройства и защита превью"
                        )
                    }
                }

                Section(GRUL10n.text("Общение")) {
                    NavigationLink {
                        GRUStableNotificationSettingsView()
                    } label: {
                        row(
                            icon: "bell.badge.fill",
                            title: "Уведомления и звуки",
                            subtitle: "Уведомления, звук, текст и badge"
                        )
                    }

                    NavigationLink {
                        GRUStableChatSettingsView()
                    } label: {
                        row(
                            icon: "bubble.left.and.bubble.right.fill",
                            title: "Чаты",
                            subtitle: "Жесты, отправка, реакции и медиа"
                        )
                    }
                }

                Section(GRUL10n.text("Интерфейс")) {
                    NavigationLink {
                        GRUStableAppearanceSettingsView()
                    } label: {
                        row(
                            icon: currentTheme.icon,
                            title: "Оформление",
                            subtitle: currentTheme.title
                        )
                    }

                    NavigationLink {
                        GRUStableAccessibilitySettingsView()
                    } label: {
                        row(
                            icon: "accessibility",
                            title: "Доступность",
                            subtitle: "Движение, контраст и тактильная отдача"
                        )
                    }

                    NavigationLink {
                        GRUStableLanguageSettingsView()
                    } label: {
                        row(
                            icon: "globe",
                            title: "Язык и перевод",
                            subtitle: "Русский и English"
                        )
                    }
                }

                Section(GRUL10n.text("Данные")) {
                    NavigationLink {
                        GRUStableDataSettingsView()
                    } label: {
                        row(
                            icon: "externaldrive.fill",
                            title: "Данные и память",
                            subtitle: "Автозагрузка, мобильный трафик и кэш"
                        )
                    }
                }

                Section(GRUL10n.text("Система")) {
                    NavigationLink {
                        GRUStablePermissionsView()
                    } label: {
                        row(
                            icon: "iphone",
                            title: "Система и разрешения",
                            subtitle: "Камера, микрофон, фото, контакты и уведомления"
                        )
                    }

                    NavigationLink {
                        GRUStableAboutView()
                    } label: {
                        row(
                            icon: "info.circle.fill",
                            title: "О GRU",
                            subtitle: "Версия приложения и среда подключения"
                        )
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        Label(
                            GRUL10n.text("Выйти из аккаунта"),
                            systemImage: "rectangle.portrait.and.arrow.right"
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle(GRUL10n.text("Настройки"))
            .navigationBarTitleDisplayMode(.large)
        }
        .confirmationDialog(
            GRUL10n.text("Выйти из GRU?"),
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button(GRUL10n.text("Выйти"), role: .destructive) {
                logout()
            }
            Button(GRUL10n.text("Отмена"), role: .cancel) {}
        } message: {
            Text(GRUL10n.text("Локальный кэш этого аккаунта будет очищен."))
        }
    }

    private func row(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(GRUColors.accent)
                .frame(width: 34, height: 34)
                .background(GRUColors.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(GRUL10n.text(title))
                    .font(.body.weight(.semibold))
                Text(GRUL10n.text(subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 3)
    }

    private func logout() {
        CacheStorage.shared.clearCurrentUser()
        WebSocketService.shared.resetSession()
        TokenStorage.shared.clear()
        ChatService.shared.clearAuthenticatedUser()
        NotificationService.shared.removeAllNotifications()
        NotificationService.shared.clearBadge()
        NotificationCenter.default.post(name: .gruSessionInvalidated, object: nil)
    }
}

@MainActor
private struct GRUStablePrivacySettingsView: View {
    @AppStorage("showStatus") private var showStatus = true
    @AppStorage("readReceipts") private var readReceipts = true
    @AppStorage("gru.settings.privacy.typing") private var typing = true

    var body: some View {
        Form {
            Section(GRUL10n.text("Приватность")) {
                Toggle(GRUL10n.text("Показывать online-статус"), isOn: $showStatus)
                Toggle(GRUL10n.text("Отчёты о прочтении"), isOn: $readReceipts)
                Toggle(GRUL10n.text("Показывать «печатает…»"), isOn: $typing)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(GRUL10n.text("Конфиденциальность"))
    }
}

@MainActor
private struct GRUStableSecuritySettingsView: View {
    @AppStorage("gru.settings.security.hideSwitcherPreview") private var hidePreview = true
    @AppStorage("gru.settings.security.biometricsEnabled") private var biometricsEnabled = false
    @State private var biometricTitle = "Face ID / Touch ID"

    var body: some View {
        Form {
            Section(GRUL10n.text("Безопасность устройства")) {
                Toggle(GRUL10n.text("Скрывать превью приложения"), isOn: $hidePreview)

                Toggle(
                    GRUL10n.format("Защита %@", GRUL10n.text(biometricTitle)),
                    isOn: Binding(
                        get: { biometricsEnabled },
                        set: { enabled in
                            guard enabled else {
                                biometricsEnabled = false
                                return
                            }
                            authenticateBeforeEnabling()
                        }
                    )
                )
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(GRUL10n.text("Безопасность"))
        .onAppear { detectBiometrics() }
    }

    private func detectBiometrics() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricTitle = "Код устройства"
            return
        }

        switch context.biometryType {
        case .faceID: biometricTitle = "Face ID"
        case .touchID: biometricTitle = "Touch ID"
        case .opticID: biometricTitle = "Optic ID"
        default: biometricTitle = "Биометрия"
        }
    }

    private func authenticateBeforeEnabling() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            biometricsEnabled = false
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: GRUL10n.text("Подтвердите включение защиты для входа в GRU")
        ) { success, _ in
            DispatchQueue.main.async {
                biometricsEnabled = success
            }
        }
    }
}

@MainActor
private struct GRUStableNotificationSettingsView: View {
    @AppStorage("notifications") private var notifications = true
    @AppStorage("sounds") private var sounds = true
    @AppStorage("gru.settings.notifications.messagePreview") private var preview = true
    @AppStorage("gru.settings.notifications.badge") private var badge = true
    @AppStorage("gru.settings.notifications.resetOnOpen") private var resetBadge = true

    var body: some View {
        Form {
            Section(GRUL10n.text("Сообщения")) {
                Toggle(GRUL10n.text("Уведомления"), isOn: $notifications)
                Toggle(GRUL10n.text("Звук"), isOn: $sounds)
                Toggle(GRUL10n.text("Показывать текст сообщения"), isOn: $preview)
                Toggle(GRUL10n.text("Счётчик на иконке"), isOn: $badge)
                Toggle(GRUL10n.text("Сбрасывать счётчик при открытии"), isOn: $resetBadge)
            }

            Section {
                Button(GRUL10n.text("Запросить разрешение iOS")) {
                    Task { await NotificationService.shared.requestPermission() }
                }

                Button(GRUL10n.text("Открыть настройки уведомлений iOS")) {
                    guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(GRUL10n.text("Уведомления"))
    }
}

@MainActor
private struct GRUStableChatSettingsView: View {
    @AppStorage("gru.settings.chats.sendByReturn") private var sendByReturn = false
    @AppStorage("gru.settings.chats.swipeReply") private var swipeReply = true
    @AppStorage("gru.settings.chats.quickReactions") private var quickReactions = true
    @AppStorage("gru.settings.chats.compactMode") private var compactMode = false
    @AppStorage("gru.settings.chats.autoplayVideo") private var autoplayVideo = true
    @AppStorage("gru.settings.chats.videoNoteAutoplay") private var videoNoteAutoplay = true

    var body: some View {
        Form {
            Section(GRUL10n.text("Отправка")) {
                Toggle(GRUL10n.text("Отправка по Return"), isOn: $sendByReturn)
                Toggle(GRUL10n.text("Свайп для ответа"), isOn: $swipeReply)
                Toggle(GRUL10n.text("Быстрые реакции"), isOn: $quickReactions)
            }

            Section(GRUL10n.text("Интерфейс")) {
                Toggle(GRUL10n.text("Компактный список чатов"), isOn: $compactMode)
            }

            Section(GRUL10n.text("Медиа")) {
                Toggle(GRUL10n.text("Автовоспроизведение обычного видео"), isOn: $autoplayVideo)
                Toggle(GRUL10n.text("Автовоспроизведение видео-сообщений"), isOn: $videoNoteAutoplay)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(GRUL10n.text("Чаты"))
    }
}

@MainActor
private struct GRUStableAppearanceSettingsView: View {
    @AppStorage(GRUTheme.selectionKey) private var themeRaw = GRUAppTheme.blackMoonCat.rawValue
    @AppStorage("gru.settings.appearance.neonGlow") private var neon = true
    @AppStorage("gru.settings.appearance.gradientBubbles") private var gradientBubbles = true
    @AppStorage("gru.settings.appearance.dynamicBackground") private var dynamicBackground = true

    var body: some View {
        Form {
            Section(GRUL10n.text("Темы")) {
                ForEach(GRUThemePolicy.allowed) { theme in
                    Button {
                        themeRaw = theme.rawValue
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: theme.icon)
                                .foregroundStyle(theme.accent)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(GRUL10n.text(theme.title))
                                    .foregroundStyle(.primary)
                                    .font(.body.weight(.semibold))
                                Text(GRUL10n.text(theme.subtitle))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if theme.rawValue == themeRaw {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(theme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section(GRUL10n.text("Эффекты")) {
                Toggle(GRUL10n.text("Неоновое свечение"), isOn: $neon)
                Toggle(GRUL10n.text("Градиентные сообщения"), isOn: $gradientBubbles)
                Toggle(GRUL10n.text("Живой фон"), isOn: $dynamicBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(GRUL10n.text("Оформление"))
        .onAppear {
            let selected = GRUAppTheme(rawValue: themeRaw)
            if selected == nil || !GRUThemePolicy.allowed.contains(selected!) {
                themeRaw = GRUAppTheme.blackMoonCat.rawValue
            }
        }
    }
}

@MainActor
private struct GRUStableAccessibilitySettingsView: View {
    @AppStorage("gru.settings.accessibility.reduceMotion") private var reduceMotion = false
    @AppStorage("gru.settings.accessibility.highContrast") private var highContrast = false
    @AppStorage("gru.settings.accessibility.haptics") private var haptics = true

    var body: some View {
        Form {
            Toggle(GRUL10n.text("Уменьшить движение"), isOn: $reduceMotion)
            Toggle(GRUL10n.text("Повышенный контраст"), isOn: $highContrast)
            Toggle(GRUL10n.text("Тактильная отдача"), isOn: $haptics)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(GRUL10n.text("Доступность"))
    }
}

@MainActor
private struct GRUStableLanguageSettingsView: View {
    @AppStorage(GRUAppLanguage.storageKey) private var languageRaw = GRUAppLanguage.defaultLanguage.rawValue

    var body: some View {
        Form {
            Section(GRUL10n.text("Интерфейс")) {
                Picker(GRUL10n.text("Язык"), selection: $languageRaw) {
                    ForEach(GRUAppLanguage.allCases) { language in
                        Text("\(language.nativeTitle)  \(language.badge)")
                            .tag(language.rawValue)
                    }
                }
                .pickerStyle(.inline)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(GRUL10n.text("Язык и перевод"))
    }
}

@MainActor
private struct GRUStableDataSettingsView: View {
    @State private var showClearCache = false
    @AppStorage("gru.settings.data.autoPhoto") private var autoPhoto = true
    @AppStorage("gru.settings.data.autoVideo") private var autoVideo = false
    @AppStorage("gru.settings.data.dataSaver") private var dataSaver = false

    var body: some View {
        Form {
            Section(GRUL10n.text("Автозагрузка")) {
                Toggle(GRUL10n.text("Фото"), isOn: $autoPhoto)
                Toggle(GRUL10n.text("Видео"), isOn: $autoVideo)
                Toggle(GRUL10n.text("Экономия мобильного трафика"), isOn: $dataSaver)
            }

            Section {
                Button(GRUL10n.text("Очистить локальный кэш"), role: .destructive) {
                    showClearCache = true
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(GRUL10n.text("Данные и память"))
        .confirmationDialog(
            GRUL10n.text("Очистить локальный кэш?"),
            isPresented: $showClearCache,
            titleVisibility: .visible
        ) {
            Button(GRUL10n.text("Очистить"), role: .destructive) {
                CacheStorage.shared.clearCurrentUser()
            }
            Button(GRUL10n.text("Отмена"), role: .cancel) {}
        }
    }
}

@MainActor
private struct GRUStablePermissionsView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section(GRUL10n.text("Разрешения iOS")) {
                permission("Камера", icon: "camera.fill")
                permission("Микрофон", icon: "mic.fill")
                permission("Фото и видео", icon: "photo.fill")
                permission("Контакты", icon: "person.crop.circle.fill")
                permission("Уведомления", icon: "bell.fill")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(GRUL10n.text("Система"))
    }

    private func permission(_ title: String, icon: String) -> some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        } label: {
            Label(GRUL10n.text(title), systemImage: icon)
        }
    }
}

@MainActor
private struct GRUStableAboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9.0"
    }

    var body: some View {
        Form {
            Section("GRU") {
                LabeledContent(GRUL10n.text("Версия"), value: version)
                LabeledContent(GRUL10n.text("Среда"), value: GRUServerConfiguration.environmentTitle)
            }

            Section(GRUL10n.text("Подключение")) {
                Label(GRUL10n.text("Защищённое HTTPS-соединение"), systemImage: "lock.fill")
                Label(GRUL10n.text("Realtime подключение активно после входа"), systemImage: "bolt.fill")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(GRUL10n.text("О GRU"))
    }
}
