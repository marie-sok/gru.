import SwiftUI
import UIKit

struct AvatarView: View {

    @AppStorage("showStatus")
    private var showStatus = true

    let user: User
    var size: CGFloat = 52

    @State private var avatarImage: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let data = user.avatarData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else if let image = avatarImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    fallbackAvatar
                }
            }
            .task(id: user.avatarURL) {
                await loadAvatar()
            }

            if showStatus && user.isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: size * 0.22, height: size * 0.22)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
            }
        }
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: fallbackPalette,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(GRUColors.neonGradient, lineWidth: max(1, size * 0.025))

            if user.isBot {
                Image(systemName: "cat.fill")
                    .font(.system(size: size * 0.40, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: GRUColors.accent, radius: 5)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: fallbackPalette.first?.opacity(0.42) ?? .clear, radius: 10)
    }

    private var fallbackPalette: [Color] {
        let seed = (user.serverID ?? user.id.uuidString).utf8.reduce(UInt64(1469598103934665603)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1099511628211
        }
        let palettes: [[Color]] = [
            [GRUColors.accent, GRUColors.accentSecondary],
            [Color(red: 0.95, green: 0.18, blue: 0.78), Color(red: 0.25, green: 0.33, blue: 1.0)],
            [Color(red: 0.40, green: 1.0, blue: 0.70), Color(red: 0.08, green: 0.48, blue: 0.92)],
            [Color(red: 1.0, green: 0.34, blue: 0.24), Color(red: 0.50, green: 0.08, blue: 0.60)]
        ]
        return palettes[Int(seed % UInt64(palettes.count))]
    }

    private var initials: String {
        let words = user.displayName.split(separator: " ")
        if words.count >= 2,
           let first = words[0].first,
           let second = words[1].first {
            return "\(first)\(second)"
        }
        if let first = user.displayName.first {
            return String(first)
        }
        return "?"
    }

    private func loadAvatar() async {
        guard user.avatarData == nil else {
            avatarImage = nil
            return
        }

        guard let urlString = user.avatarURL, !urlString.isEmpty else {
            avatarImage = nil
            return
        }

        // 1. Проверяем MediaCacheService
        if let cached = MediaCacheService.shared.image(for: urlString) {
            avatarImage = cached
            return
        }

        // 2. Скачиваем если нужно
        if let token = TokenStorage.shared.token {
            if let data = try? await APIClient.shared.download(path: urlString, token: token),
               let image = UIImage(data: data) {
                MediaCacheService.shared.store(image, for: urlString)
                avatarImage = image
            }
        }
    }
}

#Preview {
    AvatarView(
        user: User(
            username: "alex",
            displayName: "Alex Brown",
            isOnline: true
        )
    )
}
