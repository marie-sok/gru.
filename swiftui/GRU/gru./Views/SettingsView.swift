import LocalAuthentication
import SwiftUI
import UIKit

@MainActor
struct SettingsView: View {
    @State private var showLogoutConfirmation = false
    @AppStorage(GRUTheme.selectionKey) private var themeRaw = GRUAppTheme.blackMoonCat.rawValue
    @AppStorage("notifications") private var notificationsEnabled = true
    @AppStorage("showStatus") private var showOnlineStatus = true

    var body: some View {
        NavigationStack {
            ZStack {
                GRUAppBackdrop()

                List {
                    Section {
                        controlCenter
                    }
                    .listRowBackground(Color.clear)

                    Section {
                        NavigationLink {
                            ProfileView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "person.crop.circle.fill",
                                titleKey: "Профиль",
                                subtitleKey: "Имя, username, фото и описание"
                            )
                        }
                    }

                    Section(GRUL10n.text("Приватность и безопасность")) {
                        NavigationLink {
                            PrivacySettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "hand.raised.fill",
                                titleKey: "Конфиденциальность",
                                subtitleKey: "Онлайн, профиль и группы"
                            )
                        }

                        NavigationLink {
                            SecuritySettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "lock.shield.fill",
                                titleKey: "Безопасность",
                                subtitleKey: "Код-пароль, Face ID, сессии"
                            )
                        }

                        NavigationLink {
                            GRUReleaseSafetyCenterView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "checkmark.shield.fill",
                                titleKey: "Центр безопасности",
                                subtitleKey: "Жалобы, блокировки и данные аккаунта"
                            )
                        }
                    }

                    Section(GRUL10n.text("Общение")) {
                        NavigationLink {
                            NotificationsSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "bell.badge.fill",
                                titleKey: "Уведомления и звуки",
                                subtitleKey: "Сообщения и реакции"
                            )
                        }

                        NavigationLink {
                            ChatsSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "bubble.left.and.bubble.right.fill",
                                titleKey: "Чаты",
                                subtitleKey: "Жесты, сообщения и интерфейс"
                            )
                        }
                    }

                    Section(GRUL10n.text("Данные")) {
                        NavigationLink {
                            DataStorageSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "externaldrive.fill",
                                titleKey: "Данные и память",
                                subtitleKey: "Автозагрузка, качество, кэш"
                            )
                        }
                    }

                    Section(GRUL10n.text("Интерфейс")) {
                        NavigationLink {
                            AppearanceSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "paintpalette.fill",
                                titleKey: "Оформление",
                                subtitleKey: "Тема GRU, анимации, неон"
                            )
                        }

                        NavigationLink {
                            AccessibilitySettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "accessibility",
                                titleKey: "Доступность",
                                subtitleKey: "Контраст, движение, размеры"
                            )
                        }

                        NavigationLink {
                            LanguageSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "globe",
                                titleKey: "Язык и перевод",
                                subtitleKey: "Интерфейс и перевод сообщений"
                            )
                        }
                    }

                    Section(GRUL10n.text("Система")) {
                        NavigationLink {
                            SystemPermissionsSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "iphone",
                                titleKey: "Система и разрешения",
                                subtitleKey: "Камера, микрофон, фото, уведомления"
                            )
                        }

                        #if DEBUG
                        NavigationLink {
                            BackendSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "server.rack",
                                titleKey: "Backend GRU",
                                subtitle: GRUServerConfiguration.host
                            )
                        }
                        #endif

                        NavigationLink {
                            AboutGRUSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "info.circle.fill",
                                titleKey: "О GRU",
                                subtitleKey: "V12 RELEASE • release polish + safety"
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
            }
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

    private var controlCenter: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("GRU")
                            .font(.system(size: 25, weight: .black, design: .rounded))
                            .tracking(-0.8)

                        Text("V12 RELEASE CANDIDATE")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(Color.black.opacity(0.80))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(GRUColors.accent, in: Capsule())
                    }

                    Text(GRUL10n.text("Центр управления"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle().fill(GRUColors.accent.opacity(0.12))
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(GRUColors.accent)
                }
                .frame(width: 42, height: 42)
                .overlay { Circle().stroke(GRUColors.accent.opacity(0.28), lineWidth: 1) }
                .shadow(color: GRUColors.accent.opacity(0.24), radius: 12)
            }

            HStack(spacing: 8) {
                controlChip(icon: currentTheme.icon, text: GRUL10n.text(currentTheme.title))
                controlChip(icon: "sparkles", text: GRUL10n.text(currentTheme.subtitle))
                controlChip(icon: "server.rack", text: GRUServerConfiguration.host)
            }

            Divider().opacity(0.10)

            Toggle(isOn: $notificationsEnabled) {
                Label(GRUL10n.text("Уведомления"), systemImage: "bell.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(GRUColors.accent)

            Toggle(isOn: $showOnlineStatus) {
                Label(GRUL10n.text("Показывать онлайн"), systemImage: "dot.radiowaves.left.and.right")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(GRUColors.accent)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(GRUColors.card.opacity(0.88))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(GRUColors.neonGradient, lineWidth: 1.1)
                .opacity(0.58)
        }
        .shadow(color: GRUColors.accent.opacity(0.12), radius: 18, y: 8)
    }

    private var currentTheme: GRUAppTheme {
        GRUAppTheme(rawValue: themeRaw) ?? .blackMoonCat
    }

    private func controlChip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.white.opacity(0.045), in: Capsule())
            .overlay { Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1) }
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

private struct SettingsNavigationRow: View {
    let icon: String
    let titleKey: String
    let subtitleKey: String?
    let subtitle: String?

    init(icon: String, titleKey: String, subtitleKey: String) {
        self.icon = icon
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.subtitle = nil
    }

    init(icon: String, titleKey: String, subtitle: String) {
        self.icon = icon
        self.titleKey = titleKey
        self.subtitleKey = nil
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(GRUColors.accent)
                .frame(width: 34, height: 34)
                .background(GRUColors.accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(GRUL10n.text(titleKey))
                    .font(.body.weight(.semibold))

                Text(subtitleKey.map(GRUL10n.text) ?? subtitle ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 3)
    }
}

private struct PrivacySettingsView: View {
    @AppStorage("showStatus") private var showStatus = true
    @AppStorage("readReceipts") private var readReceipts = true
    @AppStorage("gru.settings.privacy.typing") private var typing = true

    var body: some View {
        Form {
            Section {
                Toggle(GRUL10n.text("Показывать online-статус"), isOn: $showStatus)
                Toggle(GRUL10n.text("Отчёты о прочтении"), isOn: $readReceipts)
                Toggle(GRUL10n.text("Показывать «печатает…»"), isOn: $typing)
            } header: {
                Text(GRUL10n.text("Работает сразу"))
            } footer: {
                Text(GRUL10n.text("Эти параметры подключены к ChatView/ChatRow и realtime-логике GRU."))
            }

            Section {
                capability("Последняя активность", "Backend")
                capability("Кто видит фото профиля", "Backend")
                capability("Добавление в группы", "Backend")
                capability("Заблокированные пользователи", "Backend")
            } header: {
                Text(GRUL10n.text("Требует серверной политики"))
            }
        }
        .navigationTitle(GRUL10n.text("Конфиденциальность"))
    }

    private func capability(_ title: String, _ state: String) -> some View {
        LabeledContent(GRUL10n.text(title), value: GRUL10n.text(state))
            .foregroundStyle(.secondary)
    }
}

private struct SecuritySettingsView: View {
    @AppStorage("gru.settings.security.hideSwitcherPreview") private var hidePreview = true
    @AppStorage("gru.settings.security.biometricsEnabled") private var biometricsEnabled = false
    @State private var biometricType = "Face ID / Touch ID"

    var body: some View {
        Form {
            Section {
                Toggle(GRUL10n.text("Скрывать превью приложения"), isOn: $hidePreview)
                Toggle(GRUL10n.format("Защита %@", GRUL10n.text(biometricType)), isOn: Binding(
                    get: { biometricsEnabled },
                    set: { newValue in
                        if newValue {
                            requestBiometricAuth { biometricsEnabled = $0 }
                        } else {
                            biometricsEnabled = false
                        }
                    }
                ))
            } header: {
                Text(GRUL10n.text("Безопасность устройства"))
            } footer: {
                Text(GRUL10n.text("При включении Face ID / Touch ID приложение запрашивает биометрию при каждом открытии."))
            }

            Section {
                capability("Защищённое хранилище (Keychain)", "Активно")
                capability("Активные устройства", "Backend")
                capability("Двухэтапная проверка", "Backend")
                capability("Шифрование сессии", "TLS 1.3 / WSS")
            } header: {
                Text(GRUL10n.text("Безопасность аккаунта"))
            }
        }
        .navigationTitle(GRUL10n.text("Безопасность"))
        .onAppear { detectBiometricType() }
    }

    private func detectBiometricType() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID: biometricType = "Face ID"
            case .touchID: biometricType = "Touch ID"
            case .opticID: biometricType = "Optic ID"
            default: biometricType = "Биометрия"
            }
        } else {
            biometricType = "Код-пароль / Биометрия"
        }
    }

    private func requestBiometricAuth(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        let reason = GRUL10n.text("Подтвердите включение защиты для входа в GRU")
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async { completion(success) }
            }
        } else {
            completion(false)
        }
    }

    private func capability(_ title: String, _ state: String) -> some View {
        HStack {
            Text(GRUL10n.text(title))
            Spacer()
            Text(GRUL10n.text(state))
                .font(.caption.weight(.bold))
                .foregroundStyle(GRUColors.accent)
        }
    }
}

private struct NotificationsSettingsView: View {
    @AppStorage("notifications") private var notifications = true
    @AppStorage("sounds") private var sounds = true
    @AppStorage("gru.settings.notifications.messagePreview") private var preview = true
    @AppStorage("gru.settings.notifications.badge") private var badge = true
    @AppStorage("gru.settings.notifications.resetOnOpen") private var resetBadge = true

    var body: some View {
        Form {
            Section {
                Toggle(GRUL10n.text("Уведомления"), isOn: $notifications)
                Toggle(GRUL10n.text("Звук"), isOn: $sounds)
                Toggle(GRUL10n.text("Показывать текст сообщения"), isOn: $preview)
                Toggle(GRUL10n.text("Счётчик на иконке"), isOn: $badge)
                Toggle(GRUL10n.text("Сбрасывать счётчик при открытии"), isOn: $resetBadge)
            } header: {
                Text(GRUL10n.text("Работает сразу"))
            } footer: {
                Text(GRUL10n.text("NotificationService читает эти параметры непосредственно перед созданием уведомления."))
            }

            Section {
                Button(GRUL10n.text("Запросить разрешение iOS")) {
                    Task { await NotificationService.shared.requestPermission() }
                }
            }

            Section {
                LabeledContent(GRUL10n.text("Отдельные правила для групп"), value: "Backend")
                LabeledContent(GRUL10n.text("Упоминания"), value: "Backend")
            } header: {
                Text(GRUL10n.text("Каналы следующего уровня"))
            }
        }
        .navigationTitle(GRUL10n.text("Уведомления"))
    }
}

private struct ChatsSettingsView: View {
    @AppStorage("gru.settings.chats.sendByReturn") private var sendByReturn = false
    @AppStorage("gru.settings.chats.swipeReply") private var swipeReply = true
    @AppStorage("gru.settings.chats.autoplayVideo") private var autoplayVideo = true
    @AppStorage("gru.settings.chats.compactMode") private var compactMode = false
    @AppStorage("gru.settings.chats.wallpaperBlur") private var wallpaperBlur = false
    @AppStorage("gru.settings.chats.textScale") private var textScale = 1.0
    @AppStorage("gru.settings.chats.quickReactions") private var quickReactions = true
    @AppStorage("gru.settings.chats.videoNoteAutoplay") private var videoNoteAutoplay = true

    var body: some View {
        Form {
            Section(GRUL10n.text("Сообщения")) {
                Toggle(GRUL10n.text("Отправка по Return"), isOn: $sendByReturn)
                Toggle(GRUL10n.text("Свайп для ответа"), isOn: $swipeReply)
                Toggle(GRUL10n.text("Быстрые реакции"), isOn: $quickReactions)
            }

            Section(GRUL10n.text("Медиа")) {
                Toggle(GRUL10n.text("Автовоспроизведение обычного видео"), isOn: $autoplayVideo)
                Toggle(GRUL10n.text("Автовоспроизведение видео-сообщений"), isOn: $videoNoteAutoplay)
            }

            Section(GRUL10n.text("Интерфейс")) {
                Toggle(GRUL10n.text("Компактный список чатов"), isOn: $compactMode)
                Toggle(GRUL10n.text("Размытие фонового рисунка"), isOn: $wallpaperBlur)

                VStack(alignment: .leading, spacing: 8) {
                    Text(GRUL10n.format("Размер текста сообщений: %d%%", Int(textScale * 100)))
                    Slider(value: $textScale, in: 0.85...1.35)
                }
            }
        }
        .navigationTitle(GRUL10n.text("Чаты"))
    }
}

private struct DataStorageSettingsView: View {
    @State private var showClearCache = false

    var body: some View {
        Form {
            Section {
                Button(GRUL10n.text("Очистить локальный кэш"), role: .destructive) {
                    showClearCache = true
                }
            } header: {
                Text(GRUL10n.text("Локальные данные"))
            } footer: {
                Text(GRUL10n.text("Удаляется только локальный кэш текущего аккаунта; сообщения на сервере не удаляются."))
            }

            Section {
                LabeledContent(GRUL10n.text("Автозагрузка по Wi‑Fi"), value: GRUL10n.text("следующий модуль"))
                LabeledContent(GRUL10n.text("Экономия мобильного трафика"), value: GRUL10n.text("следующий модуль"))
                LabeledContent(GRUL10n.text("Качество загрузки"), value: GRUL10n.text("следующий модуль"))
                LabeledContent(GRUL10n.text("Срок хранения медиа"), value: GRUL10n.text("следующий модуль"))
            } header: {
                Text("Media pipeline")
            }
        }
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

private struct AppearanceSettingsView: View {
    @AppStorage(GRUTheme.selectionKey) private var theme = GRUAppTheme.blackMoonCat.rawValue
    @AppStorage("gru.settings.appearance.neonGlow") private var neon = true
    @AppStorage("gru.settings.appearance.gradientBubbles") private var gradientBubbles = true
    @AppStorage("gru.settings.appearance.dynamicBackground") private var dynamicBackground = true
    @AppStorage("gru.settings.appearance.largeAvatars") private var largeAvatars = false

    private var selectedTheme: GRUAppTheme {
        GRUAppTheme(rawValue: theme) ?? .blackMoonCat
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(GRUL10n.text(selectedTheme.title))
                        .font(.title3.weight(.black))
                    Text(GRUL10n.text(selectedTheme.subtitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    GRUSignatureWallpaper(theme: selectedTheme, intensity: 0.78)
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            Label(GRUL10n.text("Предпросмотр темы"), systemImage: selectedTheme.icon)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.18), in: Capsule())
                                .padding(12)
                        }
                }
                .padding(.vertical, 4)
            } header: {
                Text(GRUL10n.text("Текущая тема"))
            }

            Section(GRUL10n.text("Коллекция тем")) {
                ForEach(GRUAppTheme.customThemes) { item in
                    Button {
                        theme = item.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(item.previewGradient)
                                .frame(width: 52, height: 52)
                                .overlay {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.94))
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(GRUL10n.text(item.title))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(GRUL10n.text(item.subtitle))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if item.rawValue == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(item.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Section(GRUL10n.text("Эффекты")) {
                Toggle(GRUL10n.text("Неоновое свечение"), isOn: $neon)
                Toggle(GRUL10n.text("Градиентные сообщения"), isOn: $gradientBubbles)
                Toggle(GRUL10n.text("Живой фон"), isOn: $dynamicBackground)
                Toggle(GRUL10n.text("Крупные аватары"), isOn: $largeAvatars)
            }
        }
        .navigationTitle(GRUL10n.text("Оформление"))
    }
}

private struct AccessibilitySettingsView: View {
    @AppStorage("gru.settings.accessibility.reduceMotion") private var reduceMotion = false
    @AppStorage("gru.settings.accessibility.highContrast") private var highContrast = false
    @AppStorage("gru.settings.accessibility.haptics") private var haptics = true

    var body: some View {
        Form {
            Toggle(GRUL10n.text("Уменьшить движение"), isOn: $reduceMotion)
            Toggle(GRUL10n.text("Повышенный контраст"), isOn: $highContrast)
            Toggle(GRUL10n.text("Тактильная отдача"), isOn: $haptics)
        }
        .navigationTitle(GRUL10n.text("Доступность"))
    }
}

private struct LanguageSettingsView: View {
    @AppStorage(GRUAppLanguage.storageKey)
    private var languageRaw = GRUAppLanguage.defaultLanguage.rawValue

    var body: some View {
        Form {
            Section(GRUL10n.text("Интерфейс")) {
                Picker(GRUL10n.text("Язык"), selection: $languageRaw) {
                    ForEach(GRUAppLanguage.allCases) { language in
                        HStack {
                            Text(language.nativeTitle)
                            Spacer()
                            Text(language.badge)
                                .foregroundStyle(.secondary)
                        }
                        .tag(language.rawValue)
                    }
                }
                .pickerStyle(.inline)
            }

            Section(GRUL10n.text("Перевод сообщений")) {
                LabeledContent(GRUL10n.text("Автоопределение языка"), value: "RU + EN")
                LabeledContent(GRUL10n.text("Перевод сообщения"), value: GRUL10n.text("Скоро"))
            }
        }
        .navigationTitle(GRUL10n.text("Язык и перевод"))
    }
}

private struct SystemPermissionsSettingsView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section(GRUL10n.text("Разрешения iOS")) {
                permissionButton("Камера", icon: "camera.fill")
                permissionButton("Микрофон", icon: "mic.fill")
                permissionButton("Фото и видео", icon: "photo.fill")
                permissionButton("Контакты", icon: "person.crop.circle.fill")
                permissionButton("Уведомления", icon: "bell.fill")
            }
        }
        .navigationTitle(GRUL10n.text("Система"))
    }

    private func permissionButton(_ title: String, icon: String) -> some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        } label: {
            Label(GRUL10n.text(title), systemImage: icon)
        }
    }
}

private struct BackendSettingsView: View {
    @State private var host = GRUServerConfiguration.host
    @State private var port = String(GRUServerConfiguration.port)
    @State private var showInvalidHost = false
    @State private var showApplied = false

    var body: some View {
        Form {
            Section(GRUL10n.text("Сервер")) {
                TextField(GRUL10n.text("IP или hostname"), text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                TextField(GRUL10n.text("Порт"), text: $port)
                    .keyboardType(.numberPad)
                LabeledContent("HTTP", value: "http://\(host):\(port)")
                LabeledContent("WebSocket", value: "ws://\(host):\(port)/ws")
                LabeledContent(GRUL10n.text("Среда"), value: GRUServerConfiguration.environmentTitle)
            }

            Section {
                Button(GRUL10n.text("Применить и переподключить")) { apply() }
                Button(GRUL10n.text("Автоматический адрес")) {
                    GRUServerConfiguration.resetToAutomaticHost()
                    host = GRUServerConfiguration.host
                    port = String(GRUServerConfiguration.port)
                    reconnect()
                    showApplied = true
                }
            }
        }
        .navigationTitle("Backend GRU")
        .alert(GRUL10n.text("Неверный адрес"), isPresented: $showInvalidHost) {
            Button(GRUL10n.text("Понятно"), role: .cancel) {}
        } message: {
            Text(GRUL10n.text("Укажи IP или hostname без http://, порта и пути, а также порт 1–65535."))
        }
        .alert(GRUL10n.text("Готово"), isPresented: $showApplied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(GRUL10n.text("Backend сохранён. Realtime переподключён."))
        }
    }

    private func apply() {
        guard GRUServerConfiguration.setCustomPort(port),
              GRUServerConfiguration.setCustomHost(host) else {
            showInvalidHost = true
            return
        }
        host = GRUServerConfiguration.host
        port = String(GRUServerConfiguration.port)
        reconnect()
        showApplied = true
    }

    private func reconnect() {
        let socket = WebSocketService.shared
        socket.disconnect()
        if let token = TokenStorage.shared.token, !token.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                socket.connect(token: token)
            }
        }
        Task { await ChatService.shared.loadChats() }
    }
}

private struct AboutGRUSettingsView: View {
    var body: some View {
        Form {
            Section("GRU") {
                LabeledContent(GRUL10n.text("Клиент"), value: "V12 Release")
                LabeledContent("Network", value: GRUServerConfiguration.environmentTitle)
            }

            Section(GRUL10n.text("Возможности")) {
                Label("Realtime WebSocket", systemImage: "bolt.fill")
                Label(GRUL10n.text("Фото, видео и документы"), systemImage: "photo.on.rectangle.angled")
                Label(GRUL10n.text("Голосовые сообщения"), systemImage: "waveform")
                Label(GRUL10n.text("Видео-сообщения: tap / hold / lock / cancel"), systemImage: "video.circle.fill")
                Label(GRUL10n.text("Ответы и реакции"), systemImage: "arrowshape.turn.up.left.fill")
                Label(GRUL10n.text("Локальный кэш"), systemImage: "externaldrive.fill")
                Label(GRUL10n.text("15 GRU signature themes + animated wallpapers"), systemImage: "paintpalette.fill")
                Label(GRUL10n.text("Report / Block / Account deletion"), systemImage: "checkmark.shield.fill")
                Label(GRUL10n.text("Privacy Manifest + release audit"), systemImage: "checkmark.seal.fill")
            }
        }
        .navigationTitle(GRUL10n.text("О GRU"))
    }
}

private struct GRUReleaseSafetyCenterView: View {
    @Environment(\.openURL) private var openURL
    @State private var deletePhrase = ""
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var infoMessage: String?
    @State private var errorMessage: String?

    private var canDelete: Bool {
        deletePhrase.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DELETE"
    }

    var body: some View {
        Form {
            Section {
                releaseStatusRow(icon: "exclamationmark.bubble.fill", title: "Жалобы", detail: "Доступны в профиле собеседника", state: "READY")
                releaseStatusRow(icon: "line.3.horizontal.decrease.circle.fill", title: "Фильтр контента", detail: "Антиспам + backend moderation rules", state: "ACTIVE")
                releaseStatusRow(icon: "person.crop.circle.badge.xmark", title: "Блокировка", detail: "Backend отклоняет новые сообщения", state: "READY")
                releaseStatusRow(icon: "trash.slash.fill", title: "Удаление у всех", detail: "Без служебной заглушки", state: "READY")
            } header: {
                Text(GRUL10n.text("Защита общения"))
            } footer: {
                Text(GRUL10n.text("Жалобы сохраняются на backend для модерации. Заблокированный пользователь не сможет обмениваться с вами новыми сообщениями."))
            }

            Section {
                releaseLinkRow(title: "Политика конфиденциальности", icon: "hand.raised.fill", infoKey: "GRUPrivacyPolicyURL")
                releaseLinkRow(title: "Поддержка GRU", icon: "questionmark.bubble.fill", infoKey: "GRUSupportURL")
            } header: {
                Text("Privacy & Support")
            }

            Section {
                Button {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                } label: {
                    Label(GRUL10n.text("Открыть разрешения GRU"), systemImage: "gearshape.fill")
                }
            } header: {
                Text(GRUL10n.text("Разрешения iOS"))
            }

            Section {
                Text(GRUL10n.text("Удаление аккаунта удаляет профиль, чаты и связанные медиа с backend GRU. Это действие нельзя отменить."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField(GRUL10n.text("Введите DELETE"), text: $deletePhrase)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        if isDeleting { ProgressView().controlSize(.small) }
                        Text(GRUL10n.text(isDeleting ? "Удаление…" : "Удалить аккаунт и данные"))
                    }
                }
                .disabled(!canDelete || isDeleting)
            } header: {
                Text(GRUL10n.text("Удаление аккаунта"))
            } footer: {
                Text(GRUL10n.text("Для защиты от случайного удаления сначала введите DELETE."))
            }
        }
        .navigationTitle(GRUL10n.text("Центр безопасности"))
        .confirmationDialog(
            GRUL10n.text("Удалить аккаунт навсегда?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(GRUL10n.text("Удалить аккаунт"), role: .destructive) { deleteAccount() }
            Button(GRUL10n.text("Отмена"), role: .cancel) {}
        } message: {
            Text(GRUL10n.text("Профиль, переписки и медиа будут удалены с backend GRU."))
        }
        .alert("GRU", isPresented: Binding(
            get: { infoMessage != nil || errorMessage != nil },
            set: { if !$0 { infoMessage = nil; errorMessage = nil } }
        )) {
            Button(GRUL10n.text("Понятно"), role: .cancel) {
                infoMessage = nil
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? infoMessage ?? "")
        }
    }

    @ViewBuilder
    private func releaseLinkRow(title: String, icon: String, infoKey: String) -> some View {
        let rawValue = (Bundle.main.object(forInfoDictionaryKey: infoKey) as? String) ?? ""
        let cleanValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: cleanValue)
        let isHTTPS = url?.scheme?.lowercased() == "https"

        if let url, isHTTPS {
            Button { openURL(url) } label: {
                HStack(spacing: 12) {
                    Label(GRUL10n.text(title), systemImage: icon)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GRUColors.accent)
                }
            }
        } else {
            HStack(spacing: 12) {
                Label(GRUL10n.text(title), systemImage: icon)
                Spacer()
                Text("NEED URL")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func releaseStatusRow(icon: String, title: String, detail: String, state: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(GRUColors.accent)
                .frame(width: 34, height: 34)
                .background(GRUColors.accent.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(GRUL10n.text(title)).font(.subheadline.weight(.semibold))
                Text(GRUL10n.text(detail)).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()
            Text(state)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(GRUColors.accent)
        }
    }

    private func deleteAccount() {
        guard canDelete, let token = TokenStorage.shared.token else { return }
        isDeleting = true
        Task {
            do {
                try await UserAPIService.shared.deleteMyAccount(token: token)
                await MainActor.run {
                    CacheStorage.shared.clearCurrentUser()
                    WebSocketService.shared.resetSession()
                    TokenStorage.shared.clear()
                    ChatService.shared.clearAuthenticatedUser()
                    NotificationService.shared.removeAllNotifications()
                    NotificationService.shared.clearBadge()
                    isDeleting = false
                    NotificationCenter.default.post(name: .gruSessionInvalidated, object: nil)
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
