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
                            title: "Профиль",
                            subtitle: "имя • nickname • bio • аватар"
                        )
                    }
                }

                Section("Оформление") {
                    NavigationLink {
                        GRUThemeStudioView()
                    } label: {
                        BetaSettingsRow(
                            icon: currentTheme.icon,
                            title: "Theme Studio",
                            subtitle: "live preview • движение • accent"
                        )
                    }
                }

                Section("Сообщения") {
                    NavigationLink {
                        GRUBetaChatSettingsView()
                    } label: {
                        BetaSettingsRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            title: "Чаты",
                            subtitle: "отправка • жесты • реакции • медиа"
                        )
                    }

                    NavigationLink {
                        GRUBetaNotificationsView()
                    } label: {
                        BetaSettingsRow(
                            icon: "bell.fill",
                            title: "Уведомления",
                            subtitle: "звук • превью • badge"
                        )
                    }
                }

                Section("Конфиденциальность и безопасность") {
                    NavigationLink {
                        GRUBetaPrivacyView()
                    } label: {
                        BetaSettingsRow(
                            icon: "lock.shield.fill",
                            title: "Конфиденциальность",
                            subtitle: "online • прочтение • biometrics • защита экрана"
                        )
                    }
                }

                Section("Данные") {
                    NavigationLink {
                        GRUBetaDataStorageView()
                    } label: {
                        BetaSettingsRow(
                            icon: "externaldrive.fill",
                            title: "Данные и хранилище",
                            subtitle: "автозагрузка • трафик • кэш"
                        )
                    }
                }

                Section("Устройство") {
                    Button {
                        openSystemSettings()
                    } label: {
                        BetaSettingsRow(
                            icon: "iphone",
                            title: "Разрешения iPhone",
                            subtitle: "камера • микрофон • фото • контакты"
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section("Помощь") {
                    NavigationLink {
                        GRUBetaAboutView()
                    } label: {
                        BetaSettingsRow(
                            icon: "info.circle.fill",
                            title: "О приложении",
                            subtitle: "gru. • версия • безопасность"
                        )
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        Label("Выйти из аккаунта", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GRUAppBackdrop())
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
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
            Text("Локальный кэш этого аккаунта будет очищен.")
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
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
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
            Section("Отправка") {
                Toggle("Отправка по Return", isOn: $sendByReturn)
                Toggle("Свайп для ответа", isOn: $swipeReply)
                Toggle("Быстрые реакции", isOn: $quickReactions)
            }

            Section("Интерфейс") {
                Toggle("Компактные чаты", isOn: $compactMode)
            }

            Section("Медиа") {
                Toggle("Автовоспроизведение видео", isOn: $autoplayVideo)
                Toggle("Автовоспроизведение кото-кружков", isOn: $videoNoteAutoplay)
            }
        }
        .navigationTitle("Чаты")
    }
}

private struct GRUBetaNotificationsView: View {
    @AppStorage("notifications") private var notifications = true
    @AppStorage("sounds") private var sounds = true
    @AppStorage("gru.settings.notifications.messagePreview") private var preview = true
    @AppStorage("gru.settings.notifications.badge") private var badge = true

    var body: some View {
        Form {
            Section("Сообщения") {
                Toggle("Уведомления", isOn: $notifications)
                Toggle("Звук", isOn: $sounds)
                Toggle("Текст сообщения в превью", isOn: $preview)
                Toggle("Счётчик на иконке", isOn: $badge)
            }

            Section {
                Button("Открыть настройки уведомлений iOS") {
                    guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
        }
        .navigationTitle("Уведомления")
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
            Section("Приватность") {
                Toggle("Показывать online", isOn: $showStatus)
                Toggle("Отчёты о прочтении", isOn: $readReceipts)
                Toggle("Показывать «печатает…»", isOn: $typing)
            }

            Section {
                Toggle("Face ID / код устройства", isOn: $biometrics)
                Toggle("Скрывать приложение в переключателе", isOn: $hideSwitcherPreview)

                LabeledContent {
                    Text("Включена")
                        .foregroundStyle(GRUColors.accent)
                } label: {
                    Label("Защита экрана", systemImage: "eye.slash.fill")
                }
            } header: {
                Text("Защита приложения")
            } footer: {
                Text("gru. скрывает защищённый контент при захвате экрана и блокирует запись/трансляцию интерфейса.")
            }
        }
        .navigationTitle("Конфиденциальность")
    }
}

private struct GRUBetaDataStorageView: View {
    @State private var showClearCache = false
    @AppStorage("gru.settings.data.autoPhoto") private var autoPhoto = true
    @AppStorage("gru.settings.data.autoVideo") private var autoVideo = false
    @AppStorage("gru.settings.data.dataSaver") private var dataSaver = false

    var body: some View {
        Form {
            Section("Автозагрузка") {
                Toggle("Фото", isOn: $autoPhoto)
                Toggle("Видео", isOn: $autoVideo)
                Toggle("Экономия трафика", isOn: $dataSaver)
            }

            Section {
                Button(role: .destructive) {
                    showClearCache = true
                } label: {
                    Label("Очистить кэш", systemImage: "trash")
                }
            } header: {
                Text("Хранилище")
            } footer: {
                Text("История с сервера не удаляется; локальные данные будут загружены заново при необходимости.")
            }
        }
        .navigationTitle("Данные и хранилище")
        .confirmationDialog(
            "Очистить локальный кэш?",
            isPresented: $showClearCache,
            titleVisibility: .visible
        ) {
            Button("Очистить", role: .destructive) {
                CacheStorage.shared.clearCurrentUser()
            }
            Button("Отмена", role: .cancel) {}
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
                LabeledContent("Приложение", value: "gru.")
                LabeledContent("Версия", value: version)
            }

            Section("Безопасность") {
                Label("Защита экрана включена", systemImage: "lock.shield.fill")
                Label("Сессия защищена авторизацией", systemImage: "key.fill")
            }
        }
        .navigationTitle("О приложении")
    }
}
