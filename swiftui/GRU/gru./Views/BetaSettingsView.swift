import SwiftUI
import UIKit

@MainActor
struct BetaSettingsView: View {
    @State private var showLogoutConfirmation = false
    @AppStorage(GRUTheme.selectionKey) private var themeRaw = GRUAppTheme.blackMoonCat.rawValue

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        BetaSettingsRow(
                            icon: "person.crop.circle.fill",
                            title: GRUL10n.text("Профиль"),
                            subtitle: GRUL10n.text("Имя, nickname, bio и аватар")
                        )
                    }
                }

                Section(GRUL10n.text("Оформление")) {
                    NavigationLink {
                        GRUBetaThemesView()
                    } label: {
                        BetaSettingsRow(
                            icon: currentTheme.icon,
                            title: GRUL10n.text("Темы"),
                            subtitle: BetaThemeName.title(for: currentTheme)
                        )
                    }
                }

                Section(GRUL10n.text("Сообщения")) {
                    NavigationLink {
                        GRUBetaChatSettingsView()
                    } label: {
                        BetaSettingsRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            title: GRUL10n.text("Чаты"),
                            subtitle: GRUL10n.text("Отправка, жесты, реакции и медиа")
                        )
                    }

                    NavigationLink {
                        GRUBetaNotificationsView()
                    } label: {
                        BetaSettingsRow(
                            icon: "bell.fill",
                            title: GRUL10n.text("Уведомления и звуки"),
                            subtitle: GRUL10n.text("Звук, превью и счётчик")
                        )
                    }
                }

                Section(GRUL10n.text("Конфиденциальность и безопасность")) {
                    NavigationLink {
                        GRUBetaPrivacyView()
                    } label: {
                        BetaSettingsRow(
                            icon: "lock.shield.fill",
                            title: GRUL10n.text("Конфиденциальность"),
                            subtitle: GRUL10n.text("Online, прочтение, Face ID и защита экрана")
                        )
                    }
                }

                Section(GRUL10n.text("Данные")) {
                    NavigationLink {
                        GRUBetaDataStorageView()
                    } label: {
                        BetaSettingsRow(
                            icon: "externaldrive.fill",
                            title: GRUL10n.text("Данные и хранилище"),
                            subtitle: GRUL10n.text("Автозагрузка, трафик и кэш")
                        )
                    }
                }

                Section(GRUL10n.text("Устройство")) {
                    Button {
                        openSystemSettings()
                    } label: {
                        BetaSettingsRow(
                            icon: "iphone",
                            title: GRUL10n.text("Разрешения iPhone"),
                            subtitle: GRUL10n.text("Камера, микрофон, фото и контакты")
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section(GRUL10n.text("Помощь")) {
                    NavigationLink {
                        GRUBetaAboutView()
                    } label: {
                        BetaSettingsRow(
                            icon: "info.circle.fill",
                            title: GRUL10n.text("О GRU"),
                            subtitle: GRUL10n.text("Версия, среда и безопасность")
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

    private var currentTheme: GRUAppTheme {
        let selected = GRUAppTheme(rawValue: themeRaw) ?? .blackMoonCat
        return GRUThemePolicy.allowed.contains(selected) ? selected : .blackMoonCat
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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

private enum BetaThemeName {
    static func title(for theme: GRUAppTheme) -> String {
        switch theme {
        case .blackMoonCat: return "Black Moon Cat"
        case .neonCatDemon: return "Neon Demon Cat"
        case .bloodDragon: return "Fold-Eared Cat Dragon"
        case .forestWitch: return "Forest Witch"
        case .cyberMidnight: return "Cyber Midnight"
        case .ultravioletUnicorn: return "Ultraviolet Caticorn"
        case .powderPrincess: return "Powder Princess"
        case .greenAcidMonster: return "Green Acid Monster"
        case .ironKnight: return "Iron Knight"
        default: return "Black Moon Cat"
        }
    }
}

private struct BetaSettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(GRUColors.accent)
                .frame(width: 32, height: 32)
                .background(GRUColors.accent.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct GRUBetaThemesView: View {
    @AppStorage(GRUTheme.selectionKey) private var themeRaw = GRUAppTheme.blackMoonCat.rawValue

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(GRUThemePolicy.allowed) { theme in
                    Button {
                        themeRaw = theme.rawValue
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 12) {
                            GRUSignatureWallpaper(theme: theme, intensity: 1.0, animated: false)
                                .frame(width: 74, height: 124)
                                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .stroke(theme.accent.opacity(0.36), lineWidth: 1)
                                }

                            Text(BetaThemeName.title(for: theme))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(GRUColors.text)

                            Spacer(minLength: 4)

                            if theme.rawValue == themeRaw {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(theme.accent)
                            }
                        }
                        .padding(10)
                        .background(
                            GRUColors.card.opacity(0.76),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color.clear)
        .navigationTitle(GRUL10n.text("Темы"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let selected = GRUAppTheme(rawValue: themeRaw)
            if let selected {
                if !GRUThemePolicy.allowed.contains(selected) {
                    themeRaw = GRUAppTheme.blackMoonCat.rawValue
                }
            } else {
                themeRaw = GRUAppTheme.blackMoonCat.rawValue
            }
        }
    }
}

private struct GRUBetaChatSettingsView: View {
    @AppStorage("gru.settings.chats.sendByReturn") private var sendByReturn = false
    @AppStorage("gru.settings.chats.swipeReply") private var swipeReply = true
    @AppStorage("gru.settings.chats.quickReactions") private var quickReactions = true
    @AppStorage("gru.settings.chats.compactMode") private var compactMode = true
    @AppStorage("gru.settings.chats.videoNoteAutoplay") private var videoNoteAutoplay = true
    @AppStorage("gru.settings.chats.autoplayVideo") private var autoplayVideo = true

    var body: some View {
        Form {
            Section(GRUL10n.text("Отправка")) {
                Toggle(GRUL10n.text("Отправка по Return"), isOn: $sendByReturn)
                Toggle(GRUL10n.text("Свайп для ответа"), isOn: $swipeReply)
                Toggle(GRUL10n.text("Быстрые реакции"), isOn: $quickReactions)
            }

            Section(GRUL10n.text("Интерфейс")) {
                Toggle(GRUL10n.text("Компактные чаты"), isOn: $compactMode)
            }

            Section(GRUL10n.text("Медиа")) {
                Toggle(GRUL10n.text("Автовоспроизведение видео"), isOn: $autoplayVideo)
                Toggle(GRUL10n.text("Автовоспроизведение видео-сообщений"), isOn: $videoNoteAutoplay)
            }
        }
        .navigationTitle(GRUL10n.text("Чаты"))
    }
}

private struct GRUBetaNotificationsView: View {
    @AppStorage("notifications") private var notifications = true
    @AppStorage("sounds") private var sounds = true
    @AppStorage("gru.settings.notifications.messagePreview") private var preview = true
    @AppStorage("gru.settings.notifications.badge") private var badge = true

    var body: some View {
        Form {
            Section(GRUL10n.text("Сообщения")) {
                Toggle(GRUL10n.text("Уведомления"), isOn: $notifications)
                Toggle(GRUL10n.text("Звук"), isOn: $sounds)
                Toggle(GRUL10n.text("Показывать текст сообщения"), isOn: $preview)
                Toggle(GRUL10n.text("Счётчик на иконке"), isOn: $badge)
            }

            Section {
                Button(GRUL10n.text("Открыть настройки уведомлений iOS")) {
                    guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
        }
        .navigationTitle(GRUL10n.text("Уведомления"))
    }
}

private struct GRUBetaPrivacyView: View {
    @AppStorage("showStatus") private var showStatus = true
    @AppStorage("readReceipts") private var readReceipts = true
    @AppStorage("gru.settings.privacy.typing") private var typing = true
    @AppStorage("gru.settings.security.biometricsEnabled") private var biometrics = false
    @AppStorage("gru.settings.security.hideSwitcherPreview") private var hideSwitcherPreview = true

    var body: some View {
        Form {
            Section(GRUL10n.text("Приватность")) {
                Toggle(GRUL10n.text("Показывать online-статус"), isOn: $showStatus)
                Toggle(GRUL10n.text("Отчёты о прочтении"), isOn: $readReceipts)
                Toggle(GRUL10n.text("Показывать «печатает…»"), isOn: $typing)
            }

            Section {
                Toggle(GRUL10n.text("Face ID / код устройства"), isOn: $biometrics)
                Toggle(GRUL10n.text("Скрывать приложение в переключателе"), isOn: $hideSwitcherPreview)

                LabeledContent {
                    Text(GRUL10n.text("Включена"))
                        .foregroundStyle(GRUColors.accent)
                } label: {
                    Label(GRUL10n.text("Защита экрана"), systemImage: "eye.slash.fill")
                }
            } header: {
                Text(GRUL10n.text("Защита приложения"))
            } footer: {
                Text(GRUL10n.text("GRU скрывает защищённый контент при захвате экрана и блокирует запись защищённого интерфейса."))
            }
        }
        .navigationTitle(GRUL10n.text("Конфиденциальность"))
    }
}

private struct GRUBetaDataStorageView: View {
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
                Button(role: .destructive) {
                    showClearCache = true
                } label: {
                    Label(GRUL10n.text("Очистить кэш"), systemImage: "trash")
                }
            } header: {
                Text(GRUL10n.text("Хранилище"))
            } footer: {
                Text(GRUL10n.text("История с сервера не удаляется; локальные данные будут загружены заново при необходимости."))
            }
        }
        .navigationTitle(GRUL10n.text("Данные и хранилище"))
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

private struct GRUBetaAboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9.0"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(GRUL10n.text("Приложение"), value: "GRU")
                LabeledContent(GRUL10n.text("Версия"), value: version)
                LabeledContent(GRUL10n.text("Среда"), value: GRUServerConfiguration.environmentTitle)
            }

            Section(GRUL10n.text("Безопасность")) {
                Label(GRUL10n.text("Защита экрана включена"), systemImage: "lock.shield.fill")
                Label(GRUL10n.text("Сессия защищена авторизацией"), systemImage: "key.fill")
                Label(GRUL10n.text("Защищённое хранилище Keychain"), systemImage: "key.horizontal.fill")
            }
        }
        .navigationTitle(GRUL10n.text("О GRU"))
    }
}
