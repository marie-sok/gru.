import SwiftUI

struct AttachmentMenu: View {
    let onSelect: (AttachmentAction) -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            item(.photo, "photo.fill", "Фото")
            item(.video, "video.fill", "Видео")
            item(.document, "doc.fill", "Файл")
            item(.contact, "person.crop.circle.fill", "Контакт")
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(GRUColors.card.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(GRUColors.accent.opacity(0.10), lineWidth: 1)
                }
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func item(_ action: AttachmentAction, _ image: String, _ title: String) -> some View {
        Button {
            onSelect(action)
        } label: {
            VStack(spacing: 8) {
                GRUNeonIcon(systemName: image, size: 54, iconSize: 21)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(GRUColors.text.opacity(0.82))
            }
        }
        .buttonStyle(.plain)
    }
}
