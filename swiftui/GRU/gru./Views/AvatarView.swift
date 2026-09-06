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
            avatarCore
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(
                            GRUColors.neonGradient,
                            lineWidth: max(1, size * 0.027)
                        )
                }
                .overlay {
                    Circle()
                        .stroke(
                            GRUColors.accent.opacity(
                                user.isOnline ? 0.20 : 0.07
                            ),
                            lineWidth: max(3, size * 0.075)
                        )
                        .blur(radius: max(2, size * 0.05))
                }
                .shadow(
                    color: GRUColors.accent.opacity(
                        user.isOnline ? 0.24 : 0.08
                    ),
                    radius: user.isOnline ? 12 : 6
                )
                .task(id: user.avatarURL) {
                    await loadAvatar()
                }

            if showStatus && user.isOnline {
                onlineBadge
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(user.displayName), \(user.isOnline ? "online" : "offline")"
        )
    }

    @ViewBuilder
    private var avatarCore: some View {
        if let data = user.avatarData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()

        } else if let image = avatarImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()

        } else {
            fallbackAvatar
        }
    }

    private var onlineBadge: some View {
        ZStack {
            Circle()
                .fill(GRUColors.card)

            Circle()
                .stroke(
                    GRUColors.accent.opacity(0.36),
                    lineWidth: 1
                )
                .padding(1)

            Circle()
                .fill(GRUColors.accent)
                .padding(size * 0.045)
                .shadow(
                    color: GRUColors.accent.opacity(0.78),
                    radius: 5
                )
        }
        .frame(
            width: max(11, size * 0.25),
            height: max(11, size * 0.25)
        )
        .offset(
            x: size * 0.015,
            y: size * 0.015
        )
        .accessibilityHidden(true)
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
                .fill(.black.opacity(0.07))
                .padding(size * 0.07)

            if user.isBot {
                Image(systemName: "cat.fill")
                    .font(.system(size: size * 0.40, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: GRUColors.accent, radius: 5)
            } else {
                Text(initials)
                    .font(
                        .system(
                            size: size * 0.36,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
            }
        }
    }

    private var fallbackPalette: [Color] {
        let seed = (user.serverID ?? user.id.uuidString)
            .utf8
            .reduce(UInt64(1469598103934665603)) { partial, byte in
                (partial ^ UInt64(byte)) &* 1099511628211
            }

        let palettes: [[Color]] = [
            [GRUColors.accent, GRUColors.accentSecondary],
            [
                Color(red: 0.95, green: 0.18, blue: 0.78),
                Color(red: 0.25, green: 0.33, blue: 1.0)
            ],
            [
                Color(red: 0.40, green: 1.0, blue: 0.70),
                Color(red: 0.08, green: 0.48, blue: 0.92)
            ],
            [
                Color(red: 1.0, green: 0.34, blue: 0.24),
                Color(red: 0.50, green: 0.08, blue: 0.60)
            ]
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

        guard let urlString = user.avatarURL,
              !urlString.isEmpty else {
            avatarImage = nil
            return
        }

        if let cached = MediaCacheService.shared.image(for: urlString) {
            avatarImage = cached
            return
        }

        if let token = TokenStorage.shared.token {
            if let data = try? await APIClient.shared.download(
                path: urlString,
                token: token
            ),
               let image = UIImage(data: data) {
                MediaCacheService.shared.store(
                    image,
                    for: urlString
                )
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
