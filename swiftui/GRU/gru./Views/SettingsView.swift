import SwiftUI
import UIKit

@MainActor
struct SettingsView: View {
    @State private var showLogoutConfirmation = false
    @AppStorage(GRUTheme.selectionKey) private var themeRaw = GRUAppTheme.obsidian.rawValue
    @AppStorage("notifications") private var notificationsEnabled = true
    @AppStorage("showStatus") private var showOnlineStatus = true

    var body: some View {
        NavigationStack {
            ZStack {
                GRUAppBackdrop()

                List {
                    Section {
                        v8ControlCenter
                    }
                    .listRowBackground(Color.clear)

                    Section {
                        NavigationLink {
                            ProfileView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "person.crop.circle.fill",
                                title: "Профиль",
                                subtitle: "Имя, username, фото и описание"
                            )
                        }
                    }

                    Section("Приватность и безопасность") {
                        NavigationLink {
                            PrivacySettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "hand.raised.fill",
                                title: "Конфиденциальность",
                                subtitle: "Онлайн, профиль и группы"
                            )
                        }

                        NavigationLink {
                            SecuritySettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "lock.shield.fill",
                                title: "Безопасность",
                                subtitle: "Код-пароль, Face ID, сессии"
                            )
                        }

                        NavigationLink {
                            GRUReleaseSafetyCenterView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "checkmark.shield.fill",
                                title: "Центр безопасности",
                                subtitle: "Жалобы, блокировки и данные аккаунта"
                            )
                        }
                    }

                    Section("Общение") {
                        NavigationLink {
                            NotificationsSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "bell.badge.fill",
                                title: "Уведомления и звуки",
                                subtitle: "Сообщения и реакции"
                            )
                        }

                        NavigationLink {
                            ChatsSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "bubble.left.and.bubble.right.fill",
                                title: "Чаты",
                                subtitle: "Жесты, сообщения и интерфейс"
                            )
                        }

                    }

                    Section("Данные") {
                        NavigationLink {
                            DataStorageSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "externaldrive.fill",
                                title: "Данные и память",
                                subtitle: "Автозагрузка, качество, кэш"
                            )
                        }
                    }

                    Section("Интерфейс") {
                        NavigationLink {
                            AppearanceSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "paintpalette.fill",
                                title: "Оформление",
                                subtitle: "Тема GRU, анимации, неон"
                            )
                        }

                        NavigationLink {
                            AccessibilitySettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "accessibility",
                                title: "Доступность",
                                subtitle: "Контраст, движение, размеры"
                            )
                        }

                        NavigationLink {
                            LanguageSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "globe",
                                title: "Язык и перевод",
                                subtitle: "Интерфейс и перевод сообщений"
                            )
                        }
                    }

                    Section("Система") {
                        NavigationLink {
                            SystemPermissionsSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "iphone",
                                title: "Система и разрешения",
                                subtitle: "Камера, микрофон, фото, уведомления"
                            )
                        }

                        #if DEBUG
                        NavigationLink {
                            BackendSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "server.rack",
                                title: "Backend GRU",
                                subtitle: GRUServerConfiguration.host
                            )
                        }
                        #endif

                        NavigationLink {
                            AboutGRUSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                icon: "info.circle.fill",
                                title: "О GRU",
                                subtitle: "V12 RELEASE • release polish + safety"
                            )
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            showLogoutConfirmation = true
                        } label: {
                            Label(
                                "Выйти из аккаунта",
                                systemImage: "rectangle.portrait.and.arrow.right"
                            )
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
        }
        .confirmationDialog(
            "Выйти из GRU?",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Выйти", role: .destructive) {
                logout()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Локальный кэш этого аккаунта будет очищен.")
        }
    }

    private var v8ControlCenter: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("GRU")
                            .font(.system(size: 25, weight: .black, design: .rounded))
                            .tracking(-0.8)

                        Text("V11 RELEASE CANDIDATE")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(Color.black.opacity(0.80))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(GRUColors.accent, in: Capsule())
                    }

                    Text("Control Center")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(GRUColors.accent.opacity(0.12))
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(GRUColors.accent)
                }
                .frame(width: 42, height: 42)
                .overlay { Circle().stroke(GRUColors.accent.opacity(0.28), lineWidth: 1) }
                .shadow(color: GRUColors.accent.opacity(0.24), radius: 12)
            }

            HStack(spacing: 8) {
                controlChip(icon: currentTheme.icon, text: currentTheme.title)
                controlChip(icon: "sparkles", text: currentTheme.subtitle)
                controlChip(icon: "server.rack", text: GRUServerConfiguration.host)
            }

            Divider().opacity(0.10)

            Toggle(isOn: $notificationsEnabled) {
                Label("Уведомления", systemImage: "bell.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(GRUColors.accent)

            Toggle(isOn: $showOnlineStatus) {
                Label("Показывать онлайн", systemImage: "dot.radiowaves.left.and.right")
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
        GRUAppTheme(rawValue: themeRaw) ?? .obsidian
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

        NotificationCenter.default.post(
            name: .gruSessionInvalidated,
            object: nil
        )
    }
}

private struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(GRUColors.accent)
                .frame(width: 34, height: 34)
                .background(GRUColors.accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))

                Text(subtitle)
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
                Toggle("Показывать online-статус", isOn: $showStatus)
                Toggle("Отчёты о прочтении", isOn: $readReceipts)
                Toggle("Показывать «печатает…»", isOn: $typing)
            } header: {
                Text("Работает сразу")
            } footer: {
                Text("Эти параметры подключены к ChatView/ChatRow и realtime-логике GRU.")
            }

            Section {
                capability("Последняя активность", "Backend")
                capability("Кто видит фото профиля", "Backend")
                        capability("Добавление в группы", "Backend")
                capability("Заблокированные пользователи", "Backend")
            } header: {
                Text("Требует серверной политики")
            }
        }
        .navigationTitle("Конфиденциальность")
    }

    private func capability(_ title: String, _ state: String) -> some View {
        LabeledContent(title, value: state)
            .foregroundStyle(.secondary)
    }
}

private struct SecuritySettingsView: View {
    @AppStorage("gru.settings.security.hideSwitcherPreview") private var hidePreview = true

    var body: some View {
        Form {
            Section {
                Toggle("Скрывать превью приложения", isOn: $hidePreview)
            } header: {
                Text("Работает сразу")
            } footer: {
                Text("Когда GRU уходит в фон/app switcher, содержимое закрывается privacy-shield.")
            }

            Section {
                capability("Код-пароль GRU", "Secure lock")
                capability("Face ID / Touch ID", "Secure lock")
                capability("Активные устройства", "Backend")
                capability("Двухэтапная проверка", "Backend")
                capability("Подозрительные входы", "Backend")
            } header: {
                Text("Следующий security-слой")
            }
        }
        .navigationTitle("Безопасность")
    }

    private func capability(_ title: String, _ state: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(state).font(.caption.weight(.bold)).foregroundStyle(GRUColors.accent)
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
                Toggle("Уведомления", isOn: $notifications)
                Toggle("Звук", isOn: $sounds)
                Toggle("Показывать текст сообщения", isOn: $preview)
                Toggle("Счётчик на иконке", isOn: $badge)
                Toggle("Сбрасывать счётчик при открытии", isOn: $resetBadge)
            } header: {
                Text("Работает сразу")
            } footer: {
                Text("NotificationService читает эти параметры непосредственно перед созданием уведомления.")
            }

            Section {
                Button("Запросить разрешение iOS") {
                    Task { await NotificationService.shared.requestPermission() }
                }
            }

            Section {
                LabeledContent("Отдельные правила для групп", value: "Backend")
                LabeledContent("Упоминания", value: "Backend")
            } header: {
                Text("Каналы следующего уровня")
            }
        }
        .navigationTitle("Уведомления")
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
            Section("Сообщения") {
                Toggle("Отправка по Return", isOn: $sendByReturn)
                Toggle("Свайп для ответа", isOn: $swipeReply)
                Toggle("Быстрые реакции", isOn: $quickReactions)
            }

            Section("Медиа") {
                Toggle("Автовоспроизведение обычного видео", isOn: $autoplayVideo)
                Toggle("Автовоспроизведение видео-сообщений", isOn: $videoNoteAutoplay)
            }

            Section("Интерфейс") {
                Toggle("Компактный список чатов", isOn: $compactMode)
                Toggle("Размытие фонового рисунка", isOn: $wallpaperBlur)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Размер текста сообщений: \(Int(textScale * 100))%")
                    Slider(value: $textScale, in: 0.85...1.35)
                }
            }
        }
        .navigationTitle("Чаты")
    }
}

private struct DataStorageSettingsView: View {
    @State private var showClearCache = false

    var body: some View {
        Form {
            Section {
                Button("Очистить локальный кэш", role: .destructive) {
                    showClearCache = true
                }
            } header: {
                Text("Локальные данные")
            } footer: {
                Text("Удаляется только локальный кэш текущего аккаунта; сообщения на сервере не удаляются.")
            }

            Section {
                LabeledContent("Автозагрузка по Wi‑Fi", value: "следующий модуль")
                LabeledContent("Экономия мобильного трафика", value: "следующий модуль")
                LabeledContent("Качество загрузки", value: "следующий модуль")
                LabeledContent("Срок хранения медиа", value: "следующий модуль")
            } header: {
                Text("Media pipeline")
            }
        }
        .navigationTitle("Данные и память")
        .confirmationDialog("Очистить локальный кэш?", isPresented: $showClearCache, titleVisibility: .visible) {
            Button("Очистить", role: .destructive) { CacheStorage.shared.clearCurrentUser() }
            Button("Отмена", role: .cancel) {}
        }
    }
}

private struct AppearanceSettingsView: View {
    @AppStorage(GRUTheme.selectionKey) private var theme = GRUAppTheme.obsidian.rawValue
    @AppStorage("gru.settings.appearance.neonGlow") private var neon = true
    @AppStorage("gru.settings.appearance.gradientBubbles") private var gradientBubbles = true
    @AppStorage("gru.settings.appearance.dynamicBackground") private var dynamicBackground = true
    @AppStorage("gru.settings.appearance.largeAvatars") private var largeAvatars = false

    private var selectedTheme: GRUAppTheme {
        GRUAppTheme(rawValue: theme) ?? .obsidian
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(selectedTheme.title)
                        .font(.title3.weight(.black))

                    Text(selectedTheme.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    GRUSignatureWallpaper(theme: selectedTheme, intensity: 0.78)
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            Label("Theme Preview", systemImage: selectedTheme.icon)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.18), in: Capsule())
                                .padding(12)
                        }
                        .overlay(alignment: .bottomLeading) {
                            HStack(spacing: 8) {
                                Circle().fill(selectedTheme.accent).frame(width: 14, height: 14)
                                Circle().fill(selectedTheme.secondaryAccent).frame(width: 14, height: 14)
                                Capsule().fill(Color.white.opacity(0.15)).frame(width: 46, height: 14)
                            }
                            .padding(12)
                        }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Текущая тема")
            }

            Section("Коллекция тем") {
                ForEach(GRUAppTheme.allCases) { item in
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
                                Text(item.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text(item.subtitle)
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

            Section("Эффекты") {
                Toggle("Неоновое свечение", isOn: $neon)
                Toggle("Градиентные сообщения", isOn: $gradientBubbles)
                Toggle("Живой фон", isOn: $dynamicBackground)
                Toggle("Крупные аватары", isOn: $largeAvatars)
            }
        }
        .navigationTitle("Оформление")
    }
}


private struct AccessibilitySettingsView: View {
    @AppStorage("gru.settings.accessibility.reduceMotion") private var reduceMotion = false
    @AppStorage("gru.settings.accessibility.highContrast") private var highContrast = false
    @AppStorage("gru.settings.accessibility.haptics") private var haptics = true

    var body: some View {
        Form {
            Toggle("Уменьшить движение", isOn: $reduceMotion)
            Toggle("Повышенный контраст", isOn: $highContrast)
            Toggle("Тактильная отдача", isOn: $haptics)
        }
        .navigationTitle("Доступность")
    }
}

private struct LanguageSettingsView: View {
    var body: some View {
        Form {
            Section("Интерфейс") {
                LabeledContent("Русский", value: "текущий")
                LabeledContent("English", value: "localization")
                LabeledContent("Eesti", value: "localization")
            }

            Section("Перевод сообщений") {
                LabeledContent("Автоопределение языка", value: "translation engine")
                LabeledContent("Перевод сообщения", value: "translation engine")
            }
        }
        .navigationTitle("Язык и перевод")
    }
}

private struct SystemPermissionsSettingsView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section("Разрешения iOS") {
                permissionButton("Камера", icon: "camera.fill")
                permissionButton("Микрофон", icon: "mic.fill")
                permissionButton("Фото и видео", icon: "photo.fill")
                permissionButton("Контакты", icon: "person.crop.circle.fill")
                permissionButton("Уведомления", icon: "bell.fill")
            }
        }
        .navigationTitle("Система")
    }

    private func permissionButton(_ title: String, icon: String) -> some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        } label: {
            Label(title, systemImage: icon)
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
            Section("Сервер") {
                TextField("IP или hostname", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)

                TextField("Порт", text: $port)
                    .keyboardType(.numberPad)

                LabeledContent("HTTP", value: "http://\(host):\(port)")
                LabeledContent("WebSocket", value: "ws://\(host):\(port)/ws")
                LabeledContent("Среда", value: GRUServerConfiguration.environmentTitle)
            }

            Section {
                Button("Применить и переподключить") {
                    apply()
                }

                Button("Автоматический адрес") {
                    GRUServerConfiguration.resetToAutomaticHost()
                    host = GRUServerConfiguration.host
                    port = String(GRUServerConfiguration.port)
                    reconnect()
                    showApplied = true
                }
            }
        }
        .navigationTitle("Backend GRU")
        .alert("Неверный адрес", isPresented: $showInvalidHost) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Укажи IP или hostname без http://, порта и пути, а также порт 1–65535.")
        }
        .alert("Готово", isPresented: $showApplied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Backend сохранён. Realtime переподключён.")
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

        Task {
            await ChatService.shared.loadChats()
        }
    }
}

private struct AboutGRUSettingsView: View {
    var body: some View {
        Form {
            Section("GRU") {
                LabeledContent("Клиент", value: "V12 Release")
                LabeledContent("Network", value: GRUServerConfiguration.environmentTitle)
            }

            Section("Возможности") {
                Label("Realtime WebSocket", systemImage: "bolt.fill")
                Label("Фото, видео и документы", systemImage: "photo.on.rectangle.angled")
                Label("Голосовые сообщения", systemImage: "waveform")
                Label("Видео-сообщения: tap / hold / lock / cancel", systemImage: "video.circle.fill")
                Label("Ответы и реакции", systemImage: "arrowshape.turn.up.left.fill")
                Label("Локальный кэш", systemImage: "externaldrive.fill")
                Label("17 Signature themes + animated wallpapers", systemImage: "paintpalette.fill")
                Label("Report / Block / Account deletion", systemImage: "checkmark.shield.fill")
                Label("Privacy Manifest + release audit", systemImage: "checkmark.seal.fill")
            }
        }
        .navigationTitle("О GRU")
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
                releaseStatusRow(
                    icon: "exclamationmark.bubble.fill",
                    title: "Жалобы",
                    detail: "Доступны в профиле собеседника",
                    state: "READY"
                )
                releaseStatusRow(
                    icon: "line.3.horizontal.decrease.circle.fill",
                    title: "Фильтр контента",
                    detail: "Антиспам + backend moderation rules",
                    state: "ACTIVE"
                )
                releaseStatusRow(
                    icon: "person.crop.circle.badge.xmark",
                    title: "Блокировка",
                    detail: "Backend отклоняет новые сообщения",
                    state: "READY"
                )
                releaseStatusRow(
                    icon: "trash.slash.fill",
                    title: "Удаление у всех",
                    detail: "Без служебной заглушки",
                    state: "READY"
                )
            } header: {
                Text("Защита общения")
            } footer: {
                Text("Жалобы сохраняются на backend для модерации. Заблокированный пользователь не сможет обмениваться с вами новыми сообщениями.")
            }

            Section {
                releaseLinkRow(
                    title: "Политика конфиденциальности",
                    icon: "hand.raised.fill",
                    infoKey: "GRUPrivacyPolicyURL"
                )

                releaseLinkRow(
                    title: "Поддержка GRU",
                    icon: "questionmark.bubble.fill",
                    infoKey: "GRUSupportURL"
                )
            } header: {
                Text("Privacy & Support")
            } footer: {
                Text("Перед App Store Release укажи публичные HTTPS-ссылки в Release build settings. В Debug отсутствие ссылок отображается честно как NEED URL.")
            }

            Section {
                Button {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                } label: {
                    Label("Открыть разрешения GRU", systemImage: "gearshape.fill")
                }
            } header: {
                Text("Разрешения iOS")
            }

            Section {
                Text("Удаление аккаунта удаляет профиль, чаты и связанные медиа с backend GRU. Это действие нельзя отменить.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Введите DELETE", text: $deletePhrase)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView().controlSize(.small)
                        }
                        Text(isDeleting ? "Удаление…" : "Удалить аккаунт и данные")
                    }
                }
                .disabled(!canDelete || isDeleting)
            } header: {
                Text("Удаление аккаунта")
            } footer: {
                Text("Для защиты от случайного удаления сначала введите DELETE.")
            }
        }
        .navigationTitle("Центр безопасности")
        .confirmationDialog(
            "Удалить аккаунт навсегда?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить аккаунт", role: .destructive) {
                deleteAccount()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Профиль, переписки и медиа будут удалены с backend GRU.")
        }
        .alert(
            "GRU",
            isPresented: Binding(
                get: { infoMessage != nil || errorMessage != nil },
                set: { visible in
                    if !visible {
                        infoMessage = nil
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("Понятно", role: .cancel) {
                infoMessage = nil
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? infoMessage ?? "")
        }
    }

    @ViewBuilder
    private func releaseLinkRow(
        title: String,
        icon: String,
        infoKey: String
    ) -> some View {
        let rawValue = (Bundle.main.object(forInfoDictionaryKey: infoKey) as? String) ?? ""
        let cleanValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: cleanValue)
        let isHTTPS = url?.scheme?.lowercased() == "https"

        if let url, isHTTPS {
            Button {
                openURL(url)
            } label: {
                HStack(spacing: 12) {
                    Label(title, systemImage: icon)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GRUColors.accent)
                }
            }
        } else {
            HStack(spacing: 12) {
                Label(title, systemImage: icon)
                Spacer()
                Text("NEED URL")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func releaseStatusRow(
        icon: String,
        title: String,
        detail: String,
        state: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(GRUColors.accent)
                .frame(width: 34, height: 34)
                .background(GRUColors.accent.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Text(state)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(GRUColors.accent)
        }
    }

    private func deleteAccount() {
        guard canDelete,
              let token = TokenStorage.shared.token else { return }

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
