
import SwiftUI

@MainActor
struct ContactRow: View {

    // MARK: - Data

    let chat: Chat

    // MARK: - Body

    var body: some View {

        HStack(
            alignment: .center,
            spacing: 13
        ) {

            avatar

            VStack(
                alignment: .leading,
                spacing: 6
            ) {

                topLine

                bottomLine
            }

            Spacer(
                minLength: 0
            )
        }
        .padding(
            .horizontal,
            16
        )
        .padding(
            .vertical,
            10
        )
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .contentShape(
            Rectangle()
        )
    }
}

// MARK: ========================================
// MARK: AVATAR
// MARK: ========================================

private extension ContactRow {

    var avatar: some View {

        ZStack(
            alignment: .bottomTrailing
        ) {

            Circle()
                .fill(
                    avatarBackground
                )
                .frame(
                    width: 56,
                    height: 56
                )
                .overlay {

                    Text(
                        avatarLetter
                    )
                    .font(
                        .system(
                            size: 21,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        .primary
                    )
                }

            if !chat.isGroup,
               otherUser != nil {

                onlineIndicator
            }
        }
    }

    var avatarBackground: some ShapeStyle {

        Color.primary
            .opacity(
                0.08
            )
    }

    var avatarLetter: String {

        let trimmedName =
            chatName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard let first =
                trimmedName.first
        else {

            return "G"
        }

        return String(
            first
        )
        .uppercased()
    }
}

// MARK: ========================================
// MARK: ONLINE
// MARK: ========================================

private extension ContactRow {

    @ViewBuilder
    var onlineIndicator: some View {

        if otherUser?.isOnline == true {

            Circle()
                .fill(
                    Color.green
                )
                .frame(
                    width: 14,
                    height: 14
                )
                .overlay {

                    Circle()
                        .stroke(
                            backgroundColor,
                            lineWidth: 3
                        )
                }
                .offset(
                    x: 1,
                    y: 1
                )
        }
    }
}

// MARK: ========================================
// MARK: TOP LINE
// MARK: ========================================

private extension ContactRow {

    var topLine: some View {

        HStack(
            alignment: .firstTextBaseline,
            spacing: 8
        ) {

            Text(
                chatName
            )
            .font(
                .system(
                    size: 16,
                    weight:
                        chat.unreadCount > 0
                        ? .semibold
                        : .medium
                )
            )
            .foregroundStyle(
                .primary
            )
            .lineLimit(
                1
            )

            Spacer(
                minLength: 8
            )

            Text(
                timeText
            )
            .font(
                .system(
                    size: 12,
                    weight:
                        chat.unreadCount > 0
                        ? .medium
                        : .regular
                )
            )
            .foregroundStyle(
                chat.unreadCount > 0
                ? AnyShapeStyle(
                    Color.primary
                )
                : AnyShapeStyle(
                    Color.secondary
                )
            )
            .lineLimit(
                1
            )
        }
    }
}

// MARK: ========================================
// MARK: BOTTOM LINE
// MARK: ========================================

private extension ContactRow {

    var bottomLine: some View {

        HStack(
            alignment: .center,
            spacing: 8
        ) {

            lastMessageLabel

            Spacer(
                minLength: 8
            )

            if chat.unreadCount > 0 {

                unreadBadge
            }
        }
        .frame(
            minHeight: 22
        )
    }

    var lastMessageLabel: some View {

        HStack(
            spacing: 3
        ) {

            if isLastMessageMine,
               lastMessage != nil {

                Text(
                    "Вы:"
                )
                .fontWeight(
                    .medium
                )
            }

            Text(
                lastMessageText
            )
        }
        .font(
            .system(
                size: 14,
                weight:
                    chat.unreadCount > 0
                    ? .medium
                    : .regular
            )
        )
        .foregroundStyle(
            chat.unreadCount > 0
            ? AnyShapeStyle(
                Color.primary.opacity(
                    0.82
                )
            )
            : AnyShapeStyle(
                Color.secondary
            )
        )
        .lineLimit(
            1
        )
        .truncationMode(
            .tail
        )
    }
}

// MARK: ========================================
// MARK: UNREAD BADGE
// MARK: ========================================

private extension ContactRow {

    var unreadBadge: some View {

        Text(
            unreadText
        )
        .font(
            .system(
                size: 12,
                weight: .bold,
                design: .rounded
            )
        )
        .foregroundStyle(
            .white
        )
        .padding(
            .horizontal,
            unreadHorizontalPadding
        )
        .frame(
            minWidth: 22,
            minHeight: 22
        )
        .background {

            Capsule()
                .fill(
                    Color.red
                )
        }
        .accessibilityLabel(
            "\(chat.unreadCount) непрочитанных сообщений"
        )
    }

    var unreadText: String {

        if chat.unreadCount > 99 {

            return "99+"
        }

        return String(
            chat.unreadCount
        )
    }

    var unreadHorizontalPadding: CGFloat {

        chat.unreadCount > 9
        ? 7
        : 6
    }
}

// MARK: ========================================
// MARK: CHAT NAME
// MARK: ========================================

private extension ContactRow {

    var chatName: String {

        // MARK: Group

        if chat.isGroup {

            let groupTitle =
                chat.title?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                ?? ""

            if !groupTitle.isEmpty {

                return groupTitle
            }

            return "Группа"
        }

        // MARK: Direct Chat

        if let otherUser {

            let displayName =
                otherUser
                    .displayName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            if !displayName.isEmpty {

                return displayName
            }

            let username =
                otherUser
                    .username
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            if !username.isEmpty {

                return username
            }
        }

        // MARK: Fallback Title

        let title =
            chat.title?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        if !title.isEmpty {

            return title
        }

        return "Chat"
    }
}

// MARK: ========================================
// MARK: USERS
// MARK: ========================================

private extension ContactRow {

    var otherUser: User? {

        let currentUser =
            ChatService.shared
                .currentUser

        /*
         Сначала сравниваем serverID,
         потому что серверные чаты могут
         пересоздать локальный UUID User.
         */

        if let currentServerID =
            currentUser.serverID {

            if let user =
                chat.users.first(
                    where: {
                        user in

                        user.serverID !=
                            currentServerID
                    }
                ) {

                return user
            }
        }

        /*
         Fallback для локальных
         или старых чатов.
         */

        return chat.users.first(
            where: {
                user in

                user.id !=
                    currentUser.id
            }
        )
    }
}

// MARK: ========================================
// MARK: LAST MESSAGE
// MARK: ========================================

private extension ContactRow {

    var lastMessage: Message? {

        /*
         Не полагаемся на порядок массива
         на 100%.

         Берём реально самое новое сообщение.
         */

        chat.messages.max(
            by: {
                first,
                second in

                first.sentAt <
                    second.sentAt
            }
        )
    }

    var lastMessageText: String {

        guard let lastMessage
        else {

            if chat.isGroup {

                return "Нет сообщений"
            }

            if otherUser?.isOnline == true {

                return "Online"
            }

            return "Начните общение"
        }

        let text =
            lastMessage.text
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !text.isEmpty {

            return text
        }

        if lastMessage.attachment != nil {

            return "Вложение"
        }

        return "Сообщение"
    }

    var isLastMessageMine: Bool {

        guard let lastMessage
        else {

            return false
        }

        return lastMessage.senderID ==
            ChatService.shared
                .currentUser
                .id
    }
}

// MARK: ========================================
// MARK: TIME
// MARK: ========================================

private extension ContactRow {

    var messageDate: Date {

        lastMessage?.sentAt
        ?? chat.lastActivity
    }

    var timeText: String {

        let date =
            messageDate

        let calendar =
            Calendar.current

        let now =
            Date()

        // MARK: Today

        if calendar.isDateInToday(
            date
        ) {

            return Self.timeFormatter
                .string(
                    from:
                        date
                )
        }

        // MARK: Yesterday

        if calendar.isDateInYesterday(
            date
        ) {

            return "вчера"
        }

        // MARK: Last Week

        if let days =
                calendar.dateComponents(
                    [
                        .day
                    ],
                    from:
                        calendar.startOfDay(
                            for:
                                date
                        ),
                    to:
                        calendar.startOfDay(
                            for:
                                now
                        )
                )
                .day,
           days >= 0,
           days < 7 {

            return Self.weekdayFormatter
                .string(
                    from:
                        date
                )
        }

        // MARK: Older

        return Self.dateFormatter
            .string(
                from:
                    date
            )
    }
}

// MARK: ========================================
// MARK: FORMATTERS
// MARK: ========================================

private extension ContactRow {

    static let timeFormatter:
        DateFormatter = {

            let formatter =
                DateFormatter()

            formatter.locale =
                Locale(
                    identifier:
                        "ru_RU"
                )

            formatter.dateFormat =
                "HH:mm"

            return formatter
        }()

    static let weekdayFormatter:
        DateFormatter = {

            let formatter =
                DateFormatter()

            formatter.locale =
                Locale(
                    identifier:
                        "ru_RU"
                )

            formatter.dateFormat =
                "EEE"

            return formatter
        }()

    static let dateFormatter:
        DateFormatter = {

            let formatter =
                DateFormatter()

            formatter.locale =
                Locale(
                    identifier:
                        "ru_RU"
                )

            formatter.dateFormat =
                "dd.MM.yy"

            return formatter
        }()
}

// MARK: ========================================
// MARK: COLORS
// MARK: ========================================

private extension ContactRow {

    var backgroundColor: Color {

        Color(
            uiColor:
                .systemBackground
        )
    }
}
