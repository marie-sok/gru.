import SwiftUI

struct AvatarView: View {

    @AppStorage("showStatus")
    private var showStatus = true

    let user: User
    var size: CGFloat = 52

    @State private var avatarImage: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image = avatarImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    initialsView
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

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(.white)
        }
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
