
import SwiftUI
import UIKit

private enum MessageDeleteScope: Equatable {
    case local
    case everyone
}

struct MessageBubble: View {

    @State private var pendingDeleteScope: MessageDeleteScope?

    @AppStorage("gru.settings.chats.swipeReply") private var swipeReplyEnabled = true
    @AppStorage("gru.settings.chats.quickReactions") private var quickReactions = true

    let message: Message

    let isCurrentUser: Bool

    let onReply: (Message) -> Void

    let onDeleteLocal: (Message) -> Void

    let onDeleteForEveryone: (Message) -> Void

    let onRetry: (Message) -> Void

    let onReaction: (
        ReactionType,
        Message
    ) -> Void

    let isSelectionMode: Bool
    let isSelected: Bool
    let onSelect: (Message) -> Void

    var body: some View {

        HStack(
            alignment: .bottom
        ) {

            if isCurrentUser {

                Spacer(
                    minLength: 60
                )
            }

            VStack(
                alignment: .leading,
                spacing: 8
            ) {

                if let reply =
                    message.replyTo {

                    ReplyPreview(
                        message: reply
                    )
                }

                if let attachment =
                    message.attachment {

                    AttachmentContent(
                        attachment:
                            attachment
                    )
                }

                if !message.text.isEmpty {

                    BubbleText(
                        text:
                            message.text,
                        currentUser:
                            isCurrentUser
                    )
                }

                if let reaction =
                    message.reaction {

                    Text(
                        reaction.emoji
                    )
                    .font(.title3)
                    .padding(
                        .horizontal,
                        8
                    )
                    .padding(
                        .vertical,
                        4
                    )
                    .background(
                        GRUColors.card
                    )
                    .clipShape(
                        Capsule()
                    )
                }

                // MARK: Time + Status

                HStack(
                    spacing: 5
                ) {

                    Spacer()

                    Menu {
                        messageActions
                    } label: {
                        GRUNeonIcon(
                            systemName: "ellipsis",
                            size: 26,
                            iconSize: 11
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Действия с сообщением")

                    HStack(spacing: 3) {
                        if message.isEdited {
                            Text("изм.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(timeString)
                    }
                    .font(.caption2)
                    .foregroundStyle(
                        .secondary
                    )

                    if isCurrentUser {

                        statusView
                    }
                }
            }

            if !isCurrentUser {

                Spacer(
                    minLength: 60
                )
            }
        }
        .padding(
            .horizontal
        )
        .contextMenu {
            messageActions
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onSelect(message)
            }
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
        .background(
            isSelected ? GRUColors.accent.opacity(0.08) : Color.clear
        )
        .gesture(

            DragGesture(
                minimumDistance: 30
            )
            .onEnded { value in
                guard swipeReplyEnabled, !isSelectionMode else { return }

                if value.translation.width > 60 {
                    onReply(message)
                }
            }
        )
        .confirmationDialog(
            "Удалить сообщение?",
            isPresented: Binding(
                get: { pendingDeleteScope != nil },
                set: { visible in
                    if !visible {
                        pendingDeleteScope = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if pendingDeleteScope == .local {
                Button("Удалить только у себя", role: .destructive) {
                    onDeleteLocal(message)
                    pendingDeleteScope = nil
                }
            }

            if pendingDeleteScope == .everyone {
                Button("Удалить у себя и собеседника", role: .destructive) {
                    onDeleteForEveryone(message)
                    pendingDeleteScope = nil
                }
            }

            Button("Отмена", role: .cancel) {
                pendingDeleteScope = nil
            }
        } message: {
            Text(
                pendingDeleteScope == .everyone
                    ? "Сообщение исчезнет у обоих участников чата."
                    : "Сообщение исчезнет только на этом устройстве."
            )
        }
    }

    @ViewBuilder
    private var messageActions: some View {
        Button {
            onSelect(message)
        } label: {
            Label(
                isSelected ? "Снять выбор" : "Выбрать",
                systemImage: isSelected ? "checkmark.circle.fill" : "checkmark.circle"
            )
        }

                if isCurrentUser && !message.text.isEmpty && message.status != .sending && message.status != .failed {
            Button {
                onEdit(message)
            } label: {
                Label("Редактировать", systemImage: "pencil")
            }
        }

        if !isSelectionMode {
            Button {
                onReply(message)
            } label: {
                Label("Ответить", systemImage: "arrowshape.turn.up.left")
            }
        }

        if quickReactions {
            Menu("Реакция") {
                ForEach(ReactionType.allCases) { reaction in
                    Button(reaction.emoji) {
                        onReaction(reaction, message)
                    }
                }
            }
        }

        if !message.text.isEmpty {
            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Label("Копировать", systemImage: "doc.on.doc")
            }
        }

        if message.status == .failed {
            Button { onRetry(message) } label: {
                Label("Повторить отправку", systemImage: "arrow.clockwise")
            }
        }

        Divider()

        Button(role: .destructive) {
            pendingDeleteScope = .local
        } label: {
            Label("Удалить только у себя", systemImage: "trash")
        }

        if isCurrentUser {
            Button(role: .destructive) {
                pendingDeleteScope = .everyone
            } label: {
                Label("Удалить у себя и собеседника", systemImage: "trash.slash")
            }
        }
    }

    // MARK: - Delivery Status

    @ViewBuilder
    private var statusView: some View {

        switch message.status {

        case .sending:

            Image(
                systemName: "clock"
            )
            .font(
                .system(
                    size: 10,
                    weight: .medium
                )
            )
            .foregroundStyle(
                .secondary
            )

        case .sent:

            Text("✓")
                .font(
                    .system(
                        size: 11,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .secondary
                )

        case .delivered:

            Text("✓✓")
                .font(
                    .system(
                        size: 11,
                        weight: .semibold
                    )
                )
                .tracking(-2)
                .foregroundStyle(
                    .secondary
                )

        case .read:

            Text("✓✓")
                .font(
                    .system(
                        size: 11,
                        weight: .bold
                    )
                )
                .tracking(-2)
                .foregroundStyle(
                    GRUColors.accent
                )

        case .failed:

            Image(
                systemName:
                    "exclamationmark.circle.fill"
            )
            .font(
                .system(
                    size: 11
                )
            )
            .foregroundStyle(
                .red
            )
        }
    }

    private var timeString: String {

        let formatter =
            DateFormatter()

        formatter.dateFormat =
            "HH:mm"

        return formatter.string(
            from: message.sentAt
        )
    }
}

// MARK: - Bubble Text

private struct BubbleText: View {

    let text: String
    let currentUser: Bool

    @AppStorage("gru.settings.chats.textScale") private var textScale = 1.0
    @AppStorage("gru.settings.appearance.gradientBubbles") private var gradientBubbles = true

    var body: some View {

        Text(text)
            .font(.system(size: 16.5 * textScale))
            .padding(
                .horizontal,
                14
            )
            .padding(
                .vertical,
                10
            )
            .background(

                currentUser
                    ? (gradientBubbles ? GRUColors.outgoingBubble : GRUColors.card)
                    : GRUColors.incomingBubble
            )
            .foregroundStyle(
                GRUColors.text
            )
            .clipShape(

                RoundedRectangle(
                    cornerRadius: 18
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        currentUser && gradientBubbles
                            ? GRUColors.neonGradient
                            : LinearGradient(
                                colors: [
                                    GRUColors.accent.opacity(0.18),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: currentUser ? 1.15 : 0.75
                    )
            }
            .shadow(
                color: currentUser
                    ? GRUColors.accent.opacity(0.18)
                    : .clear,
                radius: 8
            )
    }
}

// MARK: - Reply

private struct ReplyPreview: View {

    let message: Message

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 4
        ) {

            Text("Ответ")
                .font(
                    .caption2.bold()
                )
                .foregroundStyle(
                    GRUColors.accent
                )

            if let attachment = message.attachment {
                AttachmentContent(attachment: attachment)
            } else {

                Text(
                    message.text
                )
                .font(.caption)
                .lineLimit(1)
            }
        }
        .padding(8)
        .background(
            Color.gray.opacity(
                0.12
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12
            )
        )
    }
}

// MARK: - Attachment

private struct AttachmentContent: View {

    let attachment: Attachment

    @ViewBuilder
    var body: some View {

        switch attachment.type {

        case .photo:

            ImageBubble(
                attachment:
                    attachment
            )

        case .video:

            VideoBubble(
                attachment:
                    attachment
            )

        case .videoNote:

            VideoNoteBubble(
                attachment:
                    attachment
            )

        case .document:

            DocumentBubble(
                attachment:
                    attachment
            )

        case .audio:

            AudioBubble(
                attachment:
                    attachment
            )
        }
    }
}
