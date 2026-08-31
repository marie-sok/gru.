//
//  ReplyBar.swift
//  gru.
//
//  Created by Maria Morozova on 25.07.2026.
//


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

                Text("Ответ")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(GRUColors.accent)

                if let attachment = message.attachment {

                    switch attachment.type {

                    case .photo:
                        Text("📷 Фото")

                    case .video:
                        Text("🎥 Видео")

                    case .videoNote:
                        Text("🎞️ Видеосообщение")

                    case .document:
                        Text("📄 Документ")

                    case .audio:
                        Text("🎵 Аудио")
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
        }
        .padding(.horizontal)
        .padding(.vertical,10)
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
