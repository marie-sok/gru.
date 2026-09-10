import SwiftUI

struct ReplyBar: View {
    let message: Message
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(GRUColors.accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(GRUL10n.text("Ответ"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(GRUColors.accent)

                if let attachment = message.attachment {
                    switch attachment.type {
                    case .photo:
                        Text("📷 \(GRUL10n.text("Фото"))")
                    case .video:
                        Text("🎥 \(GRUL10n.text("Видео"))")
                    case .videoNote:
                        Text("🎞️ \(GRUL10n.text("Видеосообщение"))")
                    case .document:
                        Text("📄 \(GRUL10n.text("Документ"))")
                    case .audio:
                        Text("🎵 \(GRUL10n.text("Аудио"))")
                    }
                } else {
                    Text(message.text)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(GRUL10n.text("Отмена"))
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(GRUColors.card)
    }
}

#Preview {
    ReplyBar(
        message: Message(
            senderID: UUID(),
            text: "Привет!"
        ),
        onCancel: {}
    )
}

struct EditBar: View {
    let message: Message
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(GRUColors.accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(GRUL10n.text("Редактирование"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(GRUColors.accent)

                Text(message.text)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(GRUL10n.text("Отмена"))
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(GRUColors.card)
    }
}
