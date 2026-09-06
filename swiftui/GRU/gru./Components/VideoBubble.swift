import AVKit
import SwiftUI

struct VideoBubble: View {
    let attachment: Attachment

    @State private var player: AVPlayer?
    @State private var cachedRemoteURL: URL?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var loadingPulse = false
    @AppStorage("gru.settings.chats.autoplayVideo") private var autoplay = true

    private let width: CGFloat = 240
    private let height: CGFloat = 220

    var body: some View {
        ZStack {
            videoSurface

            LinearGradient(
                colors: [Color.black.opacity(0.28), Color.clear, Color.black.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            chrome
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(GRUColors.neonGradient, lineWidth: 1.15)
        }
        .shadow(color: GRUColors.accent.opacity(0.15), radius: 14, y: 5)
        .task(id: loadIdentity) {
            await preparePlayerIfNeeded()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                loadingPulse = true
            }
        }
        .onDisappear {
            player?.pause()
        }
    }

    @ViewBuilder
    private var videoSurface: some View {
        if let player {
            VideoPlayer(player: player)
                .frame(width: width, height: height)
        } else {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            GRUColors.card,
                            GRUColors.accent.opacity(isLoading && loadingPulse ? 0.18 : 0.06),
                            GRUColors.card
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: width, height: height)
                .overlay {
                    placeholderContent
                }
        }
    }

    @ViewBuilder
    private var placeholderContent: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .tint(GRUColors.accent)
            } else {
                ZStack {
                    Circle()
                        .fill(GRUColors.accent.opacity(0.10))
                        .frame(width: 56, height: 56)
                    Circle()
                        .stroke(GRUColors.neonGradient, lineWidth: 1.2)
                        .frame(width: 56, height: 56)
                    Image(systemName: loadError == nil ? "play.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(loadError == nil ? GRUColors.accent : Color.orange)
                        .offset(x: loadError == nil ? 1 : 0)
                }

                Text(loadError == nil ? "Видео" : "Не удалось загрузить")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if loadError != nil {
                    Button("Повторить") {
                        Task { await preparePlayerIfNeeded(force: true) }
                    }
                    .font(.caption2.bold())
                    .buttonStyle(.borderless)
                    .foregroundStyle(GRUColors.accent)
                }
            }
        }
    }

    private var chrome: some View {
        VStack {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 9, weight: .black))
                    Text("VIDEO")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: 23)
                .background(.black.opacity(0.38), in: Capsule())

                Spacer()

                if attachment.size > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: attachment.size, countStyle: .file))
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.horizontal, 8)
                        .frame(height: 23)
                        .background(.black.opacity(0.34), in: Capsule())
                }
            }

            Spacer()

            if !attachment.fileName.isEmpty {
                HStack {
                    Text(attachment.fileName)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .frame(height: 23)
                        .background(.black.opacity(0.34), in: Capsule())
                    Spacer()
                }
            }
        }
        .padding(11)
        .allowsHitTesting(false)
    }

    private var loadIdentity: String {
        [attachment.localPath ?? "", attachment.remoteURL ?? "", attachment.fileName]
            .joined(separator: "|")
    }

    @MainActor
    private func preparePlayerIfNeeded(force: Bool = false) async {
        if force {
            player?.pause()
            player = nil
            cachedRemoteURL = nil
        } else if player != nil {
            return
        }

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
