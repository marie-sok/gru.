import AVKit
import SwiftUI

struct VideoBubble: View {
    let attachment: Attachment

    @State private var player: AVPlayer?
    @State private var cachedRemoteURL: URL?
    @State private var isLoading = false
    @State private var loadError: String?
    @AppStorage("gru.settings.chats.autoplayVideo") private var autoplay = true

    var body: some View {
        ZStack {
            if player != nil {
                VideoPlayer(player: player)
                    .frame(width: 240, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(GRUColors.card.opacity(0.82))
                    .frame(width: 240, height: 220)
                    .overlay {
                        VStack(spacing: 10) {
                            if isLoading {
                                ProgressView()
                                    .tint(GRUColors.accent)
                            } else {
                                Image(systemName: loadError == nil ? "video.fill" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundStyle(loadError == nil ? GRUColors.accent : Color.orange)

                                Text(loadError == nil ? "Видео" : "Не удалось загрузить")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
            }
        }
        .task(id: loadIdentity) {
            await preparePlayerIfNeeded()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private var loadIdentity: String {
        [attachment.localPath ?? "", attachment.remoteURL ?? "", attachment.fileName]
            .joined(separator: "|")
    }

    @MainActor
    private func preparePlayerIfNeeded() async {
        guard player == nil else { return }
        loadError = nil

        if let local = localVideoURL {
            installPlayer(url: local)
            return
        }

        guard
            let remotePath = attachment.remoteURL,
            !remotePath.isEmpty,
            let token = TokenStorage.shared.token,
            !token.isEmpty
        else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await APIClient.shared.download(path: remotePath, token: token)
            let url = try cacheVideo(data)
            cachedRemoteURL = url
            installPlayer(url: url)
        } catch {
            loadError = error.localizedDescription
            print("❌ Video load error:", error)
        }
    }

    @MainActor
    private func installPlayer(url: URL) {
        let created = AVPlayer(url: url)
        player = created
        if autoplay {
            created.play()
        }
    }

    private var localVideoURL: URL? {
        guard
            let path = attachment.localPath,
            !path.isEmpty,
            FileManager.default.fileExists(atPath: path)
        else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    private func cacheVideo(_ data: Data) throws -> URL {
        let ext = URL(fileURLWithPath: attachment.fileName).pathExtension
        let safeExt = ext.isEmpty ? "mp4" : ext
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GRUMedia", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("video-\(attachment.id.uuidString).\(safeExt)")
        try data.write(to: url, options: .atomic)
        return url
    }
}

#Preview {
    VideoBubble(
        attachment: Attachment(
            type: .video,
            fileName: "movie.mov"
        )
    )
}
