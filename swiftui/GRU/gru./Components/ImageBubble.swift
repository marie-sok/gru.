import SwiftUI

struct ImageBubble: View {

    let attachment: Attachment

    @State private var remoteImage: UIImage?
    @State private var isLoadingRemote = false
    @State private var showFullScreen = false
    @State private var loadingPulse = false

    private let size: CGFloat = 220

    var body: some View {
        Group {
            if let image = displayedImage {
                imageView(image)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(GRUColors.neonGradient, lineWidth: 1.15)
        }
        .shadow(color: GRUColors.accent.opacity(0.16), radius: 13, y: 5)
        .task(id: attachment.remoteURL) {
            await loadRemoteImageIfNeeded()
        }
    }

    private var displayedImage: UIImage? {
        if let local = localImage {
            return local
        }
        if let remote = remoteImage {
            return remote
        }
        if let remoteURL = attachment.remoteURL,
           let cached = MediaCacheService.shared.image(for: remoteURL) {
            return cached
        }
        if let cachedByName = MediaCacheService.shared.image(for: attachment.fileName) {
            return cachedByName
        }
        return nil
    }

    private var localImage: UIImage? {
        guard let path = attachment.localPath, !path.isEmpty else {
            return nil
        }
        return UIImage(contentsOfFile: path)
    }

    private func imageView(_ image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    Color.clear,
                    Color.black.opacity(0.38)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack {
                HStack {
                    mediaBadge
                    Spacer()
                }

                Spacer()

                HStack(alignment: .bottom) {
                    if !attachment.fileName.isEmpty {
                        Text(attachment.fileName)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .frame(height: 23)
                            .background(.black.opacity(0.36), in: Capsule())
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.42))
                            .frame(width: 32, height: 32)

                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(11)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            showFullScreen = true
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenImageView(image: image)
        }
        .accessibilityLabel("Фото. Нажми, чтобы открыть на весь экран")
    }

    private var mediaBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "photo.fill")
                .font(.system(size: 9, weight: .black))

            Text("PHOTO")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(height: 23)
        .background(.black.opacity(0.38), in: Capsule())
        .overlay {
            Capsule().stroke(Color.white.opacity(0.13), lineWidth: 0.7)
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            GRUColors.card,
                            GRUColors.accent.opacity(loadingPulse ? 0.18 : 0.07),
                            GRUColors.card
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 11) {
                if isLoadingRemote {
                    ProgressView()
                        .tint(GRUColors.accent)
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(GRUColors.accent)
                }

                Text(isLoadingRemote ? "Загружаем фото…" : "Фото")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                loadingPulse = true
            }
        }
    }

    @MainActor
    private func loadRemoteImageIfNeeded() async {
        guard localImage == nil else { return }

        if let remoteURL = attachment.remoteURL,
           let cached = MediaCacheService.shared.image(for: remoteURL) {
            remoteImage = cached
            return
        }

        if let cachedByName = MediaCacheService.shared.image(for: attachment.fileName) {
            remoteImage = cachedByName
            return
        }

        guard let remoteURL = attachment.remoteURL, !remoteURL.isEmpty,
              let token = TokenStorage.shared.token, !token.isEmpty
        else {
            return
        }

        isLoadingRemote = true
        defer { isLoadingRemote = false }

        do {
            let data = try await APIClient.shared.download(path: remoteURL, token: token)
            guard let image = UIImage(data: data) else { return }

            MediaCacheService.shared.store(image, for: remoteURL)
            MediaCacheService.shared.store(image, for: attachment.fileName)

            remoteImage = image
        } catch {
            print("❌ Remote image load error for \(attachment.fileName):", error.localizedDescription)
        }
    }
}

#Preview {
    ImageBubble(
        attachment: Attachment(
            type: .photo,
            fileName: "example.jpg"
        )
    )
}
