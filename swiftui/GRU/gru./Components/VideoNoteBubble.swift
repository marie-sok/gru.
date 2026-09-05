import AVFoundation
import SwiftUI

struct VideoNoteBubble: View {
    let attachment: Attachment

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var glowPulse = false
    @AppStorage("gru.settings.chats.videoNoteAutoplay") private var autoplay = true

    private let width: CGFloat = 150
    private let height: CGFloat = 160

    private var catShape: CatVideoNoteShape {
        CatVideoNoteShape()
    }

    var body: some View {
        ZStack {
            videoLayer

            catShape
                .stroke(
                    GRUColors.accent.opacity(glowPulse ? 0.22 : 0.10),
                    lineWidth: 5
                )
                .blur(radius: 6)
                .frame(width: width, height: height)
                .allowsHitTesting(false)

            catShape
                .stroke(GRUColors.neonGradient, lineWidth: 1.8)
                .frame(width: width, height: height)
                .shadow(
                    color: GRUColors.accent.opacity(glowPulse ? 0.34 : 0.16),
                    radius: glowPulse ? 11 : 6
                )
                .allowsHitTesting(false)

            if player != nil, !isPlaying {
                playButton
            }

            durationOverlay
        }
        .frame(width: width, height: height)
        .contentShape(catShape)
        .onTapGesture {
            togglePlayback()
        }
        .task(id: loadIdentity) {
            await preparePlayerIfNeeded()
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.7)
                    .repeatForever(autoreverses: true)
            ) {
                glowPulse = true
            }
        }
        .onDisappear {
            player?.pause()
            isPlaying = false
        }
    }

    @ViewBuilder
    private var videoLayer: some View {
        if let player {
            VideoNotePlayerView(player: player)
                .frame(width: width, height: height)
                .clipShape(catShape)
        } else {
            placeholder
        }
    }

    private var playButton: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.42))
                .frame(width: 40, height: 40)

            Image(systemName: "play.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 1)
        }
        .offset(y: 4)
    }

    private var placeholder: some View {
        catShape
            .fill(
                LinearGradient(
                    colors: [
                        GRUColors.card,
                        GRUColors.accent.opacity(0.13)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .overlay {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(
                            systemName: loadError == nil
                                ? "play.fill"
                                : "exclamationmark.circle.fill"
                        )
                        .font(.system(size: 24, weight: .semibold))
                    }
                }
                .foregroundStyle(.white.opacity(0.84))
                .offset(y: 4)
            }
    }

    private var durationOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if let durationText {
                    Text(durationText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(.black.opacity(0.44), in: Capsule())
                        .padding(.trailing, 13)
                        .padding(.bottom, 10)
                }
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    private var durationText: String? {
        guard
            let duration = attachment.duration,
            duration.isFinite,
            duration > 0
        else {
            return nil
        }

        let total = Int(duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var loadIdentity: String {
        [
            attachment.localPath ?? "",
            attachment.remoteURL ?? "",
            attachment.fileName
        ]
        .joined(separator: "|")
    }

    @MainActor
    private func preparePlayerIfNeeded() async {
        guard player == nil else { return }
        loadError = nil

        if let localURL = localVideoURL {
            installPlayer(url: localURL)
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
            let data = try await APIClient.shared.download(
                path: remotePath,
                token: token
            )
            let cachedURL = try saveRemoteVideo(data)
            installPlayer(url: cachedURL)
        } catch {
            loadError = error.localizedDescription
            print("❌ Video note load error:", error)
        }
    }

    @MainActor
    private func installPlayer(url: URL) {
        let created = AVPlayer(url: url)
        player = created

        if autoplay {
            created.play()
            isPlaying = true
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

    private func saveRemoteVideo(_ data: Data) throws -> URL {
        let directory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first!

        let ext = URL(fileURLWithPath: attachment.fileName).pathExtension
        let fileName = "remote-cat-note-" + attachment.id.uuidString + (ext.isEmpty ? ".mov" : ".\(ext)")
        let fileURL = directory.appendingPathComponent(fileName)

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func togglePlayback() {
        guard let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
            return
        }

        if player.currentTime() >= player.currentItem?.duration ?? .positiveInfinity {
            player.seek(to: .zero)
        }

        player.play()
        isPlaying = true
    }
}

private struct VideoNotePlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> VideoNotePlayerContainerView {
        let view = VideoNotePlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(
        _ uiView: VideoNotePlayerContainerView,
        context: Context
    ) {
        uiView.playerLayer.player = player
    }
}

private final class VideoNotePlayerContainerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

#Preview {
    VideoNoteBubble(
        attachment: Attachment(
            type: .videoNote,
            fileName: "cat-note.mov",
            duration: 12
        )
    )
}
