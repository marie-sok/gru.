import SwiftUI
import UIKit

private enum MessageDeleteScope: Equatable {
    case local
    case everyone
}

struct MessageBubble: View {
    @State private var pendingDeleteScope: MessageDeleteScope?
    @State private var dragOffset: CGFloat = 0
    @State private var hasTriggeredReplyHaptic = false

    @AppStorage("gru.settings.chats.swipeReply") private var swipeReplyEnabled = true
    @AppStorage("gru.settings.chats.quickReactions") private var quickReactions = true

    let message: Message
    let isCurrentUser: Bool
    let onReply: (Message) -> Void
    let onEdit: (Message) -> Void
    let onDeleteLocal: (Message) -> Void
    let onDeleteForEveryone: (Message) -> Void
    let onRetry: (Message) -> Void
    let onReaction: (ReactionType, Message) -> Void
    let isSelectionMode: Bool
    let isSelected: Bool
    let onSelect: (Message) -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            if isCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: .leading, spacing: 8) {
                if let reply = message.replyTo {
                    ReplyPreview(message: reply)
                }

                if let attachment = message.attachment {
                    AttachmentContent(attachment: attachment)
                }

                if !message.text.isEmpty {
                    BubbleText(text: message.text, currentUser: isCurrentUser)
                }

                if let reaction = message.reaction {
                    Text(reaction.emoji)
                        .font(.title3)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(GRUColors.card)
                        .clipShape(Capsule())
                }

                HStack(spacing: 5) {
                    Spacer()

                    Menu { messageActions } label: {
                        GRUNeonIcon(systemName: "ellipsis", size: 26, iconSize: 11)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(GRUL10n.text("Действия с сообщением"))

                    HStack(spacing: 3) {
                        if message.isEdited {
                            Text(GRUL10n.text("изм."))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(timeString)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    if isCurrentUser { statusView }
                }
            }

            if !isCurrentUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
        .contextMenu { messageActions }
        .offset(x: dragOffset)
        .overlay(alignment: .trailing) {
            if dragOffset < -10 {
                Image(systemName: "arrowshape.turn.up.left.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(GRUColors.accent)
                    .opacity(min(1.0, Double(-dragOffset) / 45.0))
                    .scaleEffect(min(1.1, max(0.5, Double(-dragOffset) / 45.0)))
                    .padding(.trailing, 6)
                    .allowsHitTesting(false)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard swipeReplyEnabled, !isSelectionMode else { return }
                    guard value.translation.width < 0,
                          abs(value.translation.width) > abs(value.translation.height) else { return }

                    let translation = value.translation.width
                    dragOffset = translation < -50
                        ? -50 + (translation + 50) * 0.2
                        : translation

                    if translation < -45 && !hasTriggeredReplyHaptic {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        hasTriggeredReplyHaptic = true
                    }
                }
                .onEnded { value in
                    let shouldReply = swipeReplyEnabled &&
                        !isSelectionMode &&
                        value.translation.width < -45 &&
                        abs(value.translation.width) > abs(value.translation.height)

                    if shouldReply { onReply(message) }

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        dragOffset = 0
                        hasTriggeredReplyHaptic = false
                    }
                }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode { onSelect(message) }
        }
        .overlay(alignment: .leading) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(isSelected ? GRUColors.accent : Color.secondary)
                    .padding(.leading, 2)
                    .allowsHitTesting(false)
            }
        }
        .background(isSelected ? GRUColors.accent.opacity(0.08) : Color.clear)
        .confirmationDialog(
            GRUL10n.text("Удалить сообщение?"),
            isPresented: Binding(
                get: { pendingDeleteScope != nil },
                set: { visible in if !visible { pendingDeleteScope = nil } }
            ),
            titleVisibility: .visible
        ) {
            if pendingDeleteScope == .local {
                Button(GRUL10n.text("Удалить только у себя"), role: .destructive) {
                    onDeleteLocal(message)
                    pendingDeleteScope = nil
                }
            }

            if pendingDeleteScope == .everyone {
                Button(GRUL10n.text("Удалить у себя и собеседника"), role: .destructive) {
                    onDeleteForEveryone(message)
                    pendingDeleteScope = nil
                }
            }

            Button(GRUL10n.text("Отмена"), role: .cancel) {
                pendingDeleteScope = nil
            }
        } message: {
            Text(GRUL10n.text(
                pendingDeleteScope == .everyone
                    ? "Сообщение исчезнет у обоих участников чата."
                    : "Сообщение исчезнет только на этом устройстве."
            ))
        }
    }

    @ViewBuilder
    private var messageActions: some View {
        if isCurrentUser && !message.text.isEmpty {
            Button { onEdit(message) } label: {
                Label(GRUL10n.text("Редактировать"), systemImage: "pencil")
            }
        }

        if !isSelectionMode {
            Button { onReply(message) } label: {
                Label(GRUL10n.text("Ответить"), systemImage: "arrowshape.turn.up.left")
            }
        }

        if !message.text.isEmpty {
            Button { UIPasteboard.general.string = message.text } label: {
                Label(GRUL10n.text("Копировать"), systemImage: "doc.on.doc")
            }
        }

        if quickReactions {
            Menu(GRUL10n.text("Реакция")) {
                ForEach(ReactionType.allCases) { reaction in
                    Button(reaction.emoji) { onReaction(reaction, message) }
                }
            }
        }

        Button { onSelect(message) } label: {
            Label(
                GRUL10n.text(isSelected ? "Снять выбор" : "Выбрать"),
                systemImage: isSelected ? "checkmark.circle.fill" : "checkmark.circle"
            )
        }

        if message.status == .failed {
            Button { onRetry(message) } label: {
                Label(GRUL10n.text("Повторить отправку"), systemImage: "arrow.clockwise")
            }
        }

        Divider()

        Button(role: .destructive) {
            pendingDeleteScope = .local
        } label: {
            Label(GRUL10n.text("Удалить только у себя"), systemImage: "trash")
        }

        if isCurrentUser {
            Button(role: .destructive) {
                pendingDeleteScope = .everyone
            } label: {
                Label(GRUL10n.text("Удалить у всех"), systemImage: "trash.slash")
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch message.status {
        case .sending:
            if message.isQueuedForRetry {
                HStack(spacing: 3) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(GRUL10n.text("очередь"))
                }
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityLabel(GRUL10n.text("Сообщение в очереди на отправку"))
            } else {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(GRUL10n.text("Сообщение отправляется"))
            }
        case .sent:
            Text("✓")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        case .delivered:
            Text("✓✓")
                .font(.system(size: 11, weight: .semibold))
                .tracking(-2)
                .foregroundStyle(.secondary)
        case .read:
            Text("✓✓")
                .font(.system(size: 11, weight: .bold))
                .tracking(-2)
                .foregroundStyle(GRUColors.accent)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .accessibilityLabel(GRUL10n.text("Не удалось отправить сообщение"))
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.locale = GRUL10n.language.locale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: message.sentAt)
    }
}

private struct BubbleText: View {
    let text: String
    let currentUser: Bool

    @AppStorage("gru.settings.chats.textScale") private var textScale = 1.0
    @AppStorage("gru.settings.appearance.gradientBubbles") private var gradientBubbles = true
    @AppStorage("gru.settings.language.transliterateMessages") private var transliterateMessages = false

    var body: some View {
        Text(GRUTransliterator.display(text, enabled: transliterateMessages))
            .font(.system(size: 16.5 * textScale))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                currentUser
                    ? (gradientBubbles ? GRUColors.outgoingBubble : GRUColors.card)
                    : GRUColors.incomingBubble
            )
            .foregroundStyle(GRUColors.text)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        currentUser && gradientBubbles
                            ? GRUColors.neonGradient
                            : LinearGradient(
                                colors: [GRUColors.accent.opacity(0.18), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: currentUser ? 1.15 : 0.75
                    )
            }
            .shadow(
                color: currentUser ? GRUColors.accent.opacity(0.18) : .clear,
                radius: 8
            )
    }
}

private struct ReplyPreview: View {
    let message: Message

    @AppStorage("gru.settings.language.transliterateMessages") private var transliterateMessages = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(GRUL10n.text("Ответ"))
                .font(.caption2.bold())
                .foregroundStyle(GRUColors.accent)

            if let attachment = message.attachment {
                AttachmentContent(attachment: attachment)
            } else {
                Text(GRUTransliterator.display(message.text, enabled: transliterateMessages))
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct AttachmentContent: View {
    let attachment: Attachment

    @ViewBuilder
    var body: some View {
        switch attachment.type {
        case .photo: ImageBubble(attachment: attachment)
        case .video: VideoBubble(attachment: attachment)
        case .videoNote: VideoNoteBubble(attachment: attachment)
        case .document: DocumentBubble(attachment: attachment)
        case .audio: AudioBubble(attachment: attachment)
        }
    }
}
