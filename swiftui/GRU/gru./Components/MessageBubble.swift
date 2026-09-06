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

    private var replyProgress: Double {
        min(max(Double(-dragOffset) / 45.0, 0), 1)
    }

    private var hasVisiblePayload: Bool {
        !message.text.isEmpty || message.attachment != nil
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if isCurrentUser {
                Spacer(minLength: 54)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 7) {
                if message.status == .failed || message.isQueuedForRetry {
                    deliveryBanner
                }

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
                    reactionChip(reaction)
                }

                if hasVisiblePayload {
                    metadataRow
                }
            }

            if !isCurrentUser {
                Spacer(minLength: 54)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
        .contextMenu {
            messageActions
        }
        .offset(x: dragOffset)
        .overlay(alignment: .trailing) {
            if dragOffset < -8 {
                replySwipeHUD
                    .padding(.trailing, 7)
                    .allowsHitTesting(false)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 18)
                .onChanged { value in
                    guard swipeReplyEnabled, !isSelectionMode else { return }
                    guard value.translation.width < 0,
                          abs(value.translation.width) > abs(value.translation.height)
                    else { return }

                    let translation = value.translation.width
                    if translation < -52 {
                        dragOffset = -52 + (translation + 52) * 0.18
                    } else {
                        dragOffset = translation
                    }

                    if translation < -45 && !hasTriggeredReplyHaptic {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        hasTriggeredReplyHaptic = true
                    }
                }
                .onEnded { _ in
                    if hasTriggeredReplyHaptic {
                        onReply(message)
                    }

                    withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                        dragOffset = 0
                        hasTriggeredReplyHaptic = false
                    }
                }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onSelect(message)
            }
        }
        .overlay(alignment: .leading) {
            if isSelectionMode {
                selectionIndicator
            }
        }
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(GRUColors.accent.opacity(0.075))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(GRUColors.accent.opacity(0.16), lineWidth: 1)
                    }
                    .padding(.horizontal, 4)
            }
        }
        .scaleEffect(isSelected ? 0.99 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.80), value: isSelected)
        .confirmationDialog(
            "Удалить сообщение?",
            isPresented: Binding(
                get: { pendingDeleteScope != nil },
                set: { visible in
                    if !visible { pendingDeleteScope = nil }
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

    private var deliveryBanner: some View {
        HStack(spacing: 6) {
            Image(
                systemName: message.status == .failed
                    ? "exclamationmark.triangle.fill"
                    : "clock.arrow.circlepath"
            )
            .font(.system(size: 9, weight: .black))

            Text(message.status == .failed ? "НЕ ОТПРАВЛЕНО" : "В ОЧЕРЕДИ")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(0.7)

            if message.status == .failed {
                Button("повторить") {
                    onRetry(message)
                }
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(message.status == .failed ? Color.orange : GRUColors.accent)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(
            (message.status == .failed ? Color.orange : GRUColors.accent).opacity(0.09),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    (message.status == .failed ? Color.orange : GRUColors.accent).opacity(0.18),
                    lineWidth: 1
                )
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 5) {
            Menu {
                messageActions
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Действия с сообщением")

            if message.isEdited {
                Text("изм.")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(timeString)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            if isCurrentUser {
                statusView
            }
        }
        .padding(.horizontal, 7)
        .frame(height: 23)
        .background(Color.primary.opacity(0.035), in: Capsule())
        .overlay {
            Capsule().stroke(Color.primary.opacity(0.045), lineWidth: 0.8)
        }
    }

    private var replySwipeHUD: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 38, height: 38)

            Circle()
                .trim(from: 0, to: replyProgress)
                .stroke(
                    GRUColors.neonGradient,
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 38, height: 38)

            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(replyProgress >= 1 ? GRUColors.accent : Color.secondary)
                .scaleEffect(0.78 + replyProgress * 0.22)
        }
        .shadow(color: GRUColors.accent.opacity(replyProgress * 0.34), radius: 9)
    }

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 29, height: 29)

            Circle()
                .stroke(
                    isSelected ? GRUColors.neonGradient : LinearGradient(
                        colors: [Color.secondary.opacity(0.45), Color.secondary.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 27, height: 27)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(GRUColors.accent)
            }
        }
        .padding(.leading, 2)
        .allowsHitTesting(false)
    }

    private func reactionChip(_ reaction: ReactionType) -> some View {
        HStack(spacing: 5) {
            Text(reaction.emoji)
                .font(.system(size: 17))

            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(GRUColors.accent)
        }
        .padding(.horizontal, 9)
        .frame(height: 29)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(GRUColors.accent.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: GRUColors.accent.opacity(0.12), radius: 7)
    }

    @ViewBuilder
    private var messageActions: some View {
        if isCurrentUser && !message.text.isEmpty {
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

        if !message.text.isEmpty {
            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Label("Копировать", systemImage: "doc.on.doc")
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

        Button {
            onSelect(message)
        } label: {
            Label(
                isSelected ? "Снять выбор" : "Выбрать",
                systemImage: isSelected ? "checkmark.circle.fill" : "checkmark.circle"
            )
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
                Label("Удалить у всех", systemImage: "trash.slash")
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch message.status {
        case .sending:
            if message.isQueuedForRetry {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Сообщение в очереди на отправку")
            } else {
                Image(systemName: "clock")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Сообщение отправляется")
            }
        case .sent:
            Text("✓")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        case .delivered:
            Text("✓✓")
                .font(.system(size: 10, weight: .semibold))
                .tracking(-2)
                .foregroundStyle(.secondary)
        case .read:
            Text("✓✓")
                .font(.system(size: 10, weight: .black))
                .tracking(-2)
                .foregroundStyle(GRUColors.accent)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: message.sentAt)
    }
}

private struct BubbleText: View {
    let text: String
    let currentUser: Bool

    @AppStorage("gru.settings.chats.textScale") private var textScale = 1.0
    @AppStorage("gru.settings.appearance.gradientBubbles") private var gradientBubbles = true

    var body: some View {
        Text(text)
            .font(.system(size: 16.5 * textScale, weight: .regular, design: .rounded))
            .lineSpacing(1.5)
            .padding(.horizontal, 15)
            .padding(.vertical, 10.5)
            .background(
                currentUser
                    ? (gradientBubbles ? GRUColors.outgoingBubble : GRUColors.card)
                    : GRUColors.incomingBubble
            )
            .foregroundStyle(GRUColors.text)
            .clipShape(GRUChatBubbleShape(currentUser: currentUser))
            .overlay {
                GRUChatBubbleShape(currentUser: currentUser)
                    .stroke(
                        currentUser && gradientBubbles
                            ? GRUColors.neonGradient
                            : LinearGradient(
                                colors: [
                                    GRUColors.accent.opacity(0.15),
                                    Color.white.opacity(0.035)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: currentUser ? 1.05 : 0.75
                    )
            }
            .shadow(
                color: currentUser ? GRUColors.accent.opacity(0.16) : Color.black.opacity(0.08),
                radius: currentUser ? 10 : 5,
                y: 3
            )
    }
}

private struct GRUChatBubbleShape: Shape {
    let currentUser: Bool

    func path(in rect: CGRect) -> Path {
        let large: CGFloat = 19
        let small: CGFloat = 7

        let corners = UIRectCorner(
            rawValue:
                (currentUser ? UIRectCorner.topLeft.rawValue : UIRectCorner.topRight.rawValue) |
                UIRectCorner.topLeft.rawValue |
                UIRectCorner.topRight.rawValue |
                (currentUser ? UIRectCorner.bottomLeft.rawValue : UIRectCorner.bottomRight.rawValue)
        )

        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: large, height: large)
        )

        var result = Path(path.cgPath)

        if currentUser {
            let tail = Path { tail in
                tail.move(to: CGPoint(x: rect.maxX - small - 3, y: rect.maxY - 13))
                tail.addQuadCurve(
                    to: CGPoint(x: rect.maxX + 5, y: rect.maxY - 2),
                    control: CGPoint(x: rect.maxX + 1, y: rect.maxY - 8)
                )
                tail.addQuadCurve(
                    to: CGPoint(x: rect.maxX - 8, y: rect.maxY - 4),
                    control: CGPoint(x: rect.maxX - 1, y: rect.maxY)
                )
                tail.closeSubpath()
            }
            result.addPath(tail)
        } else {
            let tail = Path { tail in
                tail.move(to: CGPoint(x: rect.minX + small + 3, y: rect.maxY - 13))
                tail.addQuadCurve(
                    to: CGPoint(x: rect.minX - 5, y: rect.maxY - 2),
                    control: CGPoint(x: rect.minX - 1, y: rect.maxY - 8)
                )
                tail.addQuadCurve(
                    to: CGPoint(x: rect.minX + 8, y: rect.maxY - 4),
                    control: CGPoint(x: rect.minX + 1, y: rect.maxY)
                )
                tail.closeSubpath()
            }
            result.addPath(tail)
        }

        return result
    }
}

private struct ReplyPreview: View {
    let message: Message

    var body: some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(GRUColors.neonGradient)
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 9, weight: .black))
                    Text("ОТВЕТ")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundStyle(GRUColors.accent)

                if let attachment = message.attachment {
                    Text(attachment.fileName.isEmpty ? "Вложение" : attachment.fileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(message.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GRUColors.accent.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct AttachmentContent: View {
    let attachment: Attachment

    @ViewBuilder
    var body: some View {
        switch attachment.type {
        case .photo:
            ImageBubble(attachment: attachment)
        case .video:
            VideoBubble(attachment: attachment)
        case .videoNote:
            VideoNoteBubble(attachment: attachment)
        case .document:
            DocumentBubble(attachment: attachment)
        case .audio:
            AudioBubble(attachment: attachment)
        }
    }
}
