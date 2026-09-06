import SwiftUI

struct AttachmentMenu: View {
    let onSelect: (AttachmentAction) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            LazyVGrid(columns: columns, spacing: 10) {
                item(
                    .photo,
                    "photo.fill",
                    "Фото",
                    "медиатека"
                )

                item(
                    .video,
                    "video.fill",
                    "Видео",
                    "снять или выбрать"
                )

                item(
                    .document,
                    "doc.fill",
                    "Файл",
                    "документ"
                )

                item(
                    .contact,
                    "person.crop.circle.fill",
                    "Контакт",
                    "карточка человека"
                )
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .background(
            GRUColors.card.opacity(0.88),
            in: RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
            .stroke(
                GRUColors.neonGradient,
                lineWidth: 1
            )
            .opacity(0.34)
        }
        .shadow(
            color: GRUColors.accent.opacity(0.16),
            radius: 24,
            y: 10
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(GRUColors.accent.opacity(0.12))

                Image(systemName: "paperclip")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(GRUColors.accent)
            }
            .frame(width: 34, height: 34)
            .overlay {
                Circle()
                    .stroke(
                        GRUColors.accent.opacity(0.26),
                        lineWidth: 1
                    )
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("ATTACH")
                    .font(
                        .system(
                            size: 11,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .tracking(1.1)
                    .foregroundStyle(GRUColors.accent)

                Text(GRUL10n.text("Добавить в сообщение"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("GRU")
                .font(
                    .system(
                        size: 9,
                        weight: .black,
                        design: .rounded
                    )
                )
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(
                    Color.primary.opacity(0.045),
                    in: Capsule()
                )
        }
    }

    private func item(
        _ action: AttachmentAction,
        _ image: String,
        _ title: String,
        _ subtitle: String
    ) -> some View {
        Button {
            onSelect(action)
        } label: {
            HStack(spacing: 10) {
                GRUNeonIcon(
                    systemName: image,
                    size: 42,
                    iconSize: 16
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(GRUL10n.text(title))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(GRUColors.text)

                    Text(GRUL10n.text(subtitle))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 62)
            .background(
                Color.primary.opacity(0.035),
                in: RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .stroke(
                    GRUColors.accent.opacity(0.10),
                    lineWidth: 1
                )
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
    }
}
