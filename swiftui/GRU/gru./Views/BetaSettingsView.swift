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
                            subtitle: "аватар • nickname • bio"
                        )
                    }
                }

                Section("Оформление") {
                    NavigationLink {
                        GRUSignatureThemesView()
                    } label: {
                        BetaSettingsRow(
                            icon: currentTheme.icon,
                            title: "Фирменные темы GRU",
                            subtitle: "\(GRUAppTheme.customThemes.count) авторских сетов • \(currentTheme.title)"
                        )
                    }
                }

                Section("Общение") {
                    NavigationLink {
                        GRUBetaChatSettingsView()
                    } label: {
                        BetaSettingsRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            title: "Чаты",
                            subtitle: "жесты • реакции • компактность"
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

                Section("Приватность") {
                    NavigationLink {
                        GRUBetaPrivacyView()
                    } label: {
                        BetaSettingsRow(
                            icon: "hand.raised.fill",
                            title: "Конфиденциальность",
                            subtitle: "online • прочтение • typing"
                        )
                    }
                }

                Section("Система") {
                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    } label: {
                        BetaSettingsRow(
                            icon: "iphone",
                            title: "Разрешения iPhone",
                            subtitle: "камера • микрофон • фото • контакты"
                        )
                    }
                    .buttonStyle(.plain)

                    #if DEBUG
                    LabeledContent {
                        Text(GRUServerConfiguration.host)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Backend", systemImage: "server.rack")
                    }
                    #endif
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

    private var currentTheme: GRUAppTheme {
        GRUAppTheme(rawValue: themeRaw) ?? .blackMoonCat
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

private struct GRUSignatureThemesView: View {
    @AppStorage(GRUTheme.selectionKey) private var themeRaw = GRUAppTheme.blackMoonCat.rawValue

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(GRUAppTheme.customThemes) { theme in
                    Button {
                        themeRaw = theme.rawValue
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(theme.previewGradient)
                                Image(systemName: theme.icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(theme.accent)
                            }
                            .frame(width: 56, height: 48)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(theme.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(GRUColors.text)
                                Text(theme.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 4)

                            if theme.rawValue == themeRaw {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(theme.accent)
                            }
                        }
                        .padding(10)
                        .background(GRUColors.card.opacity(0.76), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(theme.rawValue == themeRaw ? theme.accent.opacity(0.42) : Color.white.opacity(0.05), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(GRUColors.background.ignoresSafeArea())
        .navigationTitle("Темы GRU")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GRUBetaChatSettingsView: View {
    @AppStorage("gru.settings.chats.sendByReturn") private var sendByReturn = false
    @AppStorage("gru.settings.chats.swipeReply") private var swipeReply = true
    @AppStorage("gru.settings.chats.quickReactions") private var quickReactions = true
    @AppStorage("gru.settings.chats.compactMode") private var compactMode = true
    @AppStorage("gru.settings.chats.videoNoteAutoplay") private var videoNoteAutoplay = true

    var body: some View {
        Form {
            Section("Сообщения") {
                Toggle("Отправка по Return", isOn: $sendByReturn)
                Toggle("Свайп для ответа", isOn: $swipeReply)
                Toggle("Быстрые реакции", isOn: $quickReactions)
            }

            Section("Интерфейс") {
                Toggle("Компактные чаты", isOn: $compactMode)
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
            Section {
                Toggle("Уведомления", isOn: $notifications)
                Toggle("Звук", isOn: $sounds)
                Toggle("Текст сообщения", isOn: $preview)
                Toggle("Badge на иконке", isOn: $badge)
            }

            Section {
                Button("Запросить разрешение iOS") {
                    Task {
                        await NotificationService.shared.requestPermission()
                    }
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

    var body: some View {
        Form {
            Section {
                Toggle("Показывать online", isOn: $showStatus)
                Toggle("Отчёты о прочтении", isOn: $readReceipts)
                Toggle("Показывать «печатает…»", isOn: $typing)
            }
        }
        .navigationTitle("Конфиденциальность")
    }
}
