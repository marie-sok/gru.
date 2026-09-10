import SwiftUI

@MainActor
struct ContactRow: View {
    let chat: Chat

    private var currentUser: User { ChatService.shared.currentUser }

    private var otherUser: User? {
        if let currentServerID = currentUser.serverID,
           let user = chat.users.first(where: { $0.serverID != nil && $0.serverID != currentServerID }) {
            return user
        }
        return chat.users.first(where: { $0.id != currentUser.id })
    }

    private var lastMessage: Message? {
        chat.messages.max(by: { $0.sentAt < $1.sentAt })
    }

    private var chatName: String {
        if chat.isGroup {
            let title = chat.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return title.isEmpty ? GRUL10n.text("Группа") : title
        }

        if let otherUser {
            let displayName = otherUser.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !displayName.isEmpty { return displayName }

            let username = otherUser.username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !username.isEmpty { return username }
        }

        let title = chat.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? GRUL10n.text("Chat") : title
    }

    private var lastMessageText: String {
        guard let lastMessage else {
            if chat.isGroup { return GRUL10n.text("Нет сообщений") }
            if otherUser?.isOnline == true { return GRUL10n.text("online") }
            return GRUL10n.text("Начните общение")
        }

        let text = lastMessage.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return text }

        guard let attachment = lastMessage.attachment else {
            return GRUL10n.text("Сообщение")
        }

        switch attachment.type {
        case .photo: return GRUL10n.text("Фото")
        case .video, .videoNote: return GRUL10n.text("Видео")
        case .document: return GRUL10n.text("Документ")
        case .audio: return GRUL10n.text("Голосовое")
        }
    }

    private var isLastMessageMine: Bool {
        lastMessage?.senderID == currentUser.id
    }

    private var avatarLetter: String {
        let trimmed = chatName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "G"
    }

    private var messageDate: Date {
        lastMessage?.sentAt ?? chat.lastActivity
    }

    private var timeText: String {
        let calendar = Calendar.current
        let date = messageDate

        if calendar.isDateInToday(date) {
            return formatted(date, pattern: "HH:mm")
        }
        if calendar.isDateInYesterday(date) {
            return GRUL10n.text("вчера")
        }

        let start = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        if let days = calendar.dateComponents([.day], from: start, to: today).day,
           days >= 0, days < 7 {
            return formatted(date, pattern: "EEE")
        }

        return formatted(date, pattern: "dd.MM.yy")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            avatar

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(chatName)
                        .font(.system(size: 16, weight: chat.unreadCount > 0 ? .semibold : .medium))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(timeText)
                        .font(.system(size: 12, weight: chat.unreadCount > 0 ? .medium : .regular))
                        .foregroundStyle(chat.unreadCount > 0 ? Color.primary : Color.secondary)
                        .lineLimit(1)
                }

                HStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 3) {
                        if isLastMessageMine, lastMessage != nil {
                            Text(GRUL10n.text("Вы:"))
                                .fontWeight(.medium)
                        }
                        Text(lastMessageText)
                    }
                    .font(.system(size: 14, weight: chat.unreadCount > 0 ? .medium : .regular))
                    .foregroundStyle(chat.unreadCount > 0 ? Color.primary.opacity(0.82) : Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                    Spacer(minLength: 8)

                    if chat.unreadCount > 0 { unreadBadge }
                }
                .frame(minHeight: 22)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 56, height: 56)
                .overlay {
                    Text(avatarLetter)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                }

            if !chat.isGroup, otherUser?.isOnline == true {
                Circle()
                    .fill(Color.green)
                    .frame(width: 14, height: 14)
                    .overlay { Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 3) }
                    .offset(x: 1, y: 1)
            }
        }
    }

    private var unreadBadge: some View {
        Text(chat.unreadCount > 99 ? "99+" : String(chat.unreadCount))
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, chat.unreadCount > 9 ? 7 : 6)
            .frame(minWidth: 22, minHeight: 22)
            .background(Capsule().fill(Color.red))
            .accessibilityLabel(
                GRUL10n.format("%d непрочитанных сообщений", chat.unreadCount)
            )
    }

    private func formatted(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = GRUL10n.language.locale
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
