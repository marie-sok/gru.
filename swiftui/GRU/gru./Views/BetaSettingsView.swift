import SwiftUI
import UIKit

@MainActor
struct BetaSettingsView: View {
    @State private var showLogoutConfirmation = false

    @AppStorage(GRUTheme.selectionKey)
    private var themeRaw = GRUAppTheme.blackMoonCat.rawValue

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
                            subtitle: "имя • username • bio • аватар"
                        )
                    }
                }

                Section {
                    NavigationLink {
                        GRUThemeStudioView()
                    } label: {
                        BetaSettingsRow(
                            icon: currentTheme.icon,
                            title: "Theme Studio",
                            subtitle: "live preview • движение • accent"
                        )
                    }
                } header: {
                    Text(GRUL10n.text("Оформление"))
                }

                Section {
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
                } header: {
                    Text(GRUL10n.text("Сообщения"))
                }

                Section {
                    NavigationLink {
                        GRUBetaPrivacyView()
                    } label: {
                        BetaSettingsRow(
                            icon: "lock.shield.fill",
                            title: "Конфиденциальность",
                            subtitle: "online • прочтение • biometrics • защита экрана"
                        )
                    }
                } header: {
                    Text(GRUL10n.text("Конфиденциальность и безопасность"))
                }

                Section {
                    NavigationLink {
                        GRUBetaDataStorageView()
                    } label: {
                        BetaSettingsRow(
                            icon: "externaldrive.fill",
                            title: "Данные и хранилище",
                            subtitle: "автозагрузка • трафик • кэш"
                        )
                    }
                } header: {
                    Text(GRUL10n.text("Данные"))
                }

                Section {
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
                } header: {
                    Text(GRUL10n.text("Устройство"))
                }

                Section {
                    NavigationLink {
                        GRUBetaAboutView()
                    } label: {
                        BetaSettingsRow(
                            icon: "info.circle.fill",
                            title: "О приложении",
                            subtitle: "gru. • версия • безопасность"
                        )
                    }
                } header: {
                    Text(GRUL10n.text("Помощь"))
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
            .background(GRUAppBackdrop())
            .navigationTitle(GRUL10n.text("Настройки"))
            .navigationBarTitleDisplayMode(.large)
        }
        .confirmationDialog(
            GRUL10n.text("Выйти из gru.?"),
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
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
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
                Text(GRUL10n.text(title))
                    .font(.body.weight(.semibold))

                Text(GRUL10n.text(subtitle))
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
            Section {
                Toggle(GRUL10n.text("Отправка по Return"), isOn: $sendByReturn)
                Toggle(GRUL10n.text("Свайп для ответа"), isOn: $swipeReply)
                Toggle(GRUL10n.text("Быстрые реакции"), isOn: $quickReactions)
            } header: {
                Text(GRUL10n.text("Отправка"))
            }

            Section {
                Toggle(GRUL10n.text("Компактные чаты"), isOn: $compactMode)
            } header: {
                Text(GRUL10n.text("Интерфейс"))
            }

            Section {
                Toggle(GRUL10n.text("Автовоспроизведение видео"), isOn: $autoplayVideo)
                Toggle(
                    GRUL10n.text("Автовоспроизведение кото-кружков"),
                    isOn: $videoNoteAutoplay
                )
            } header: {
                Text(GRUL10n.text("Медиа"))
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
            Section {
                Toggle(GRUL10n.text("Уведомления"), isOn: $notifications)
                Toggle(GRUL10n.text("Звук"), isOn: $sounds)
                Toggle(GRUL10n.text("Текст сообщения в превью"), isOn: $preview)
                Toggle(GRUL10n.text("Счётчик на иконке"), isOn: $badge)
            } header: {
                Text(GRUL10n.text("Сообщения"))
            }

            Section {
                Button(GRUL10n.text("Открыть настройки уведомлений iOS")) {
                    guard let url = URL(
                        string: UIApplication.openNotificationSettingsURLString
                    ) else {
                        return
                    }
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
            Section {
                Toggle(GRUL10n.text("Показывать online"), isOn: $showStatus)
                Toggle(GRUL10n.text("Отчёты о прочтении"), isOn: $readReceipts)
                Toggle(GRUL10n.text("Показывать «печатает…»"), isOn: $typing)
            } header: {
                Text(GRUL10n.text("Приватность"))
            }

            Section {
                Toggle(GRUL10n.text("Face ID / код устройства"), isOn: $biometrics)
                Toggle(
                    GRUL10n.text("Скрывать приложение в переключателе"),
                    isOn: $hideSwitcherPreview
                )

                LabeledContent {
                    Text(GRUL10n.text("Включена"))
                        .foregroundStyle(GRUColors.accent)
                } label: {
                    Label(
                        GRUL10n.text("Защита экрана"),
                        systemImage: "eye.slash.fill"
                    )
                }
            } header: {
                Text(GRUL10n.text("Защита приложения"))
            } footer: {
                Text(
                    GRUL10n.text(
                        "gru. скрывает защищённый контент при захвате экрана и блокирует запись/трансляцию интерфейса."
                    )
                )
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
            Section {
                Toggle(GRUL10n.text("Фото"), isOn: $autoPhoto)
                Toggle(GRUL10n.text("Видео"), isOn: $autoVideo)
                Toggle(GRUL10n.text("Экономия трафика"), isOn: $dataSaver)
            } header: {
                Text(GRUL10n.text("Автозагрузка"))
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
                Text(
                    GRUL10n.text(
                        "История с сервера не удаляется; локальные данные будут загружены заново при необходимости."
                    )
                )
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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.9.0"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(GRUL10n.text("Приложение"), value: "gru.")
                LabeledContent(GRUL10n.text("Версия"), value: version)
            }

            Section {
                Label(
                    GRUL10n.text("Защита экрана включена"),
                    systemImage: "lock.shield.fill"
                )
                Label(
                    GRUL10n.text("Сессия защищена авторизацией"),
                    systemImage: "key.fill"
                )
            } header: {
                Text(GRUL10n.text("Безопасность"))
            }
        }
        .navigationTitle(GRUL10n.text("О приложении"))
    }
}
