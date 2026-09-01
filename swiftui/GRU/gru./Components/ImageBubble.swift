import SwiftUI

struct ImageBubble: View {

    let attachment: Attachment

    @State private var remoteImage: UIImage?
    @State private var isLoadingRemote = false
    @State private var showFullScreen = false

    var body: some View {
        Group {
            if let image = displayedImage {
                imageView(image)
            } else {
                placeholder
            }
        }
        .task(id: attachment.remoteURL) {
            await loadRemoteImageIfNeeded()
        }
    }

    // MARK: - Displayed Image Resolution

    private var displayedImage: UIImage? {
        if let local = localImage {
            return local
        }
        if let remote = remoteImage {
            return remote
        }
        // Мгновенная проверка кэша при рендеринге ячейки
        if let remoteURL = attachment.remoteURL,
           let cached = MediaCacheService.shared.image(for: remoteURL) {
            return cached
        }
        if let cachedByName = MediaCacheService.shared.image(for: attachment.fileName) {
            return cachedByName
        }
        return nil
    }

    // MARK: - Local Image

    private var localImage: UIImage? {
        guard let path = attachment.localPath, !path.isEmpty else {
            return nil
        }
        return UIImage(contentsOfFile: path)
    }

    // MARK: - Image View

    private func imageView(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 220, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .onTapGesture {
                showFullScreen = true
            }
            .fullScreenCover(isPresented: $showFullScreen) {
                FullScreenImageView(image: image)
            }
    }

    // MARK: - Placeholder

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.gray.opacity(0.15))
            .frame(width: 220, height: 220)
            .overlay {
                if isLoadingRemote {
                    ProgressView()
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
    }

    // MARK: - Remote Image Loading with Cache

    @MainActor
    private func loadRemoteImageIfNeeded() async {
        guard localImage == nil else { return }

        // Проверяем кэш
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

            // Сохраняем в двухуровневый кэш (RAM + Диск)
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
