import SwiftUI

@MainActor
struct ChatRow: View {
    @AppStorage("gru.settings.chats.compactMode") private var compactMode = false
    @AppStorage("gru.settings.appearance.largeAvatars") private var largeAvatars = false
    @AppStorage("showStatus") private var showOnlineStatus = true

    let chat: Chat

    private var currentUser: User { ChatService.shared.currentUser }

    private var otherUser: User? {
        if let myServerID = currentUser.serverID,
           let user = chat.users.first(where: { $0.serverID != nil && $0.serverID != myServerID }) {
            return user
        }
        return chat.users.first(where: { $0.id != currentUser.id })
    }

    private var chatTitle: String {
        if chat.isGroup {
            let title = chat.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return title.isEmpty ? "Группа" : title
        }
        if let otherUser {
            let name = otherUser.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty && name.lowercased() != "you" { return name }
            let username = otherUser.username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !username.isEmpty && username.lowercased() != "you" { return username }
        }
        return "User"
    }

    private var isOnline: Bool { showOnlineStatus && otherUser?.isOnline == true }
    private var avatarSize: CGFloat { largeAvatars ? 62 : (compactMode ? 46 : 54) }

    var body: some View {
        HStack(spacing: 13) {
            avatar

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(chatTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    if chat.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(GRUColors.accent)
                    }

                    if chat.isMuted {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    if !chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Черновик")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(GRUColors.accent)
                        Text(chat.draft)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: lastMessageIcon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(GRUColors.accent.opacity(0.82))
                        Text(lastMessage)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                if !lastTime.isEmpty {
                    Text(lastTime)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(chat.unreadCount > 0 ? GRUColors.accent : .secondary)
                }

                if chat.unreadCount > 0 {
                    Text(chat.unreadCount > 99 ? "99+" : "\(chat.unreadCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .padding(.horizontal, 7)
                        .frame(minWidth: 23, minHeight: 23)
                        .background(GRUColors.accent)
                        .clipShape(Capsule())
                        .shadow(color: GRUColors.accent.opacity(0.35), radius: 8)
                } else if isOnline {
                    Text("LIVE")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(GRUColors.accent)
                        .padding(.horizontal, 7)
                        .frame(height: 21)
                        .background(GRUColors.accent.opacity(0.10), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, compactMode ? 7 : 11)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(GRUColors.card.opacity(chat.unreadCount > 0 ? 0.96 : 0.78))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    chat.unreadCount > 0 ? GRUColors.accent.opacity(0.24) : Color.white.opacity(0.055),
                    lineWidth: 1
                )
        }
        .shadow(
            color: chat.unreadCount > 0 ? GRUColors.accent.opacity(0.10) : .clear,
            radius: 14,
            y: 6
        )
    }

    @ViewBuilder
    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            if let otherUser {
                AvatarView(user: otherUser, size: avatarSize)

                if isOnline {
                    GRUCatSignalHalo()
                        .stroke(GRUColors.neonGradient, lineWidth: 1.5)
                        .frame(width: avatarSize + 7, height: avatarSize + 7)
                        .shadow(color: GRUColors.accent.opacity(0.34), radius: 8)
                        .allowsHitTesting(false)
                }
            } else {
                ZStack {
                    Circle().fill(Color.secondary.opacity(0.12))
                    Image(systemName: chat.isGroup ? "person.3.fill" : "person.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(width: avatarSize, height: avatarSize)
            }

            Circle()
                .fill(isOnline ? GRUColors.accent : GRUColors.card)
                .frame(width: 14, height: 14)
                .overlay {
                    Circle().stroke(GRUColors.background, lineWidth: 3)
                }
                .shadow(color: isOnline ? GRUColors.accent.opacity(0.65) : .clear, radius: 5)
        }
    }

    private var lastMessage: String {
        guard let message = chat.messages.last else { return "Нет сообщений" }
        let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return text }
        guard let attachment = message.attachment else { return "Сообщение" }
        switch attachment.type {
        case .photo: return "Фото"
        case .video: return "Видео"
        case .videoNote: return "Видео"
        case .document: return "Документ"
        case .audio: return "Голосовое"
        }
    }

    private var lastMessageIcon: String {
        guard let type = chat.messages.last?.attachment?.type else { return "text.bubble.fill" }
        switch type {
        case .photo: return "photo.fill"
        case .video: return "video.fill"
        case .videoNote: return "video.circle.fill"
        case .document: return "doc.fill"
        case .audio: return "waveform"
        }
    }

    private var lastTime: String {
        guard let date = chat.messages.last?.sentAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "dd.MM"
        return formatter.string(from: date)
    }
}


private struct GRUCatSignalHalo: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.08
        let circleRect = rect.insetBy(dx: inset, dy: inset)
        path.addEllipse(in: circleRect)

        let topY = circleRect.minY + rect.height * 0.035
        let earWidth = rect.width * 0.16
        let earHeight = rect.height * 0.16

        path.move(to: CGPoint(x: circleRect.minX + rect.width * 0.18, y: topY + earHeight))
        path.addLine(to: CGPoint(x: circleRect.minX + rect.width * 0.22, y: topY))
        path.addLine(to: CGPoint(x: circleRect.minX + rect.width * 0.22 + earWidth, y: topY + earHeight * 0.72))

        path.move(to: CGPoint(x: circleRect.maxX - rect.width * 0.18, y: topY + earHeight))
        path.addLine(to: CGPoint(x: circleRect.maxX - rect.width * 0.22, y: topY))
        path.addLine(to: CGPoint(x: circleRect.maxX - rect.width * 0.22 - earWidth, y: topY + earHeight * 0.72))

        return path
    }
}
