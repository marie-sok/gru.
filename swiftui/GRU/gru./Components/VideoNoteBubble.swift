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

    private let width: CGFloat = 154
    private let height: CGFloat = 168

    private var catShape: CatVideoNoteShape {
        CatVideoNoteShape()
    }

    var body: some View {
        ZStack {
            videoLayer

            CatVideoNoteEarDetails(width: width)

            catShape
                .stroke(GRUColors.accent.opacity(glowPulse ? 0.48 : 0.24), lineWidth: 8)
                .blur(radius: 9)
                .frame(width: width, height: height)
                .allowsHitTesting(false)

            catShape
                .stroke(
                    LinearGradient(
                        colors: [
                            GRUColors.accent.opacity(1.0),
                            .white.opacity(0.82),
                            GRUColors.accentSecondary.opacity(0.72),
                            GRUColors.accent.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.4
                )
                .shadow(
                    color: GRUColors.accent.opacity(glowPulse ? 0.72 : 0.38),
                    radius: glowPulse ? 22 : 11
                )
                .shadow(
                    color: GRUColors.accentSecondary.opacity(glowPulse ? 0.28 : 0.12),
                    radius: glowPulse ? 32 : 16
                )
                .frame(width: width, height: height)
                .allowsHitTesting(false)

            if player != nil,
               !isPlaying {
                playButton
            }

            durationOverlay
        }
        .frame(
            width: width,
            height: height
        )
        .contentShape(catShape)
        .onTapGesture {
            togglePlayback()
        }
        .task(id: loadIdentity) {
            await preparePlayerIfNeeded()
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                    .repeatForever(
                        autoreverses: true
                    )
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
            VideoNotePlayerView(
                player: player
            )
            .frame(
                width: width,
                height: height
            )
            .clipShape(catShape)
        } else {
            placeholder
        }
    }

    private var playButton: some View {
        GRUNeonIcon(
            systemName: "play.fill",
            size: 42,
            iconSize: 15
        )
        .background(.black.opacity(0.26), in: Circle())
        .shadow(color: GRUColors.accent.opacity(0.48), radius: 14)
        .offset(y: 7)
    }

    private var placeholder: some View {
        catShape
            .fill(
                LinearGradient(
                    colors: [
                        GRUColors.card,
                        GRUColors.accent.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(
                width: width,
                height: height
            )
            .overlay {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(
                            systemName:
                                loadError == nil
                                    ? "play.circle.fill"
                                    : "exclamationmark.triangle.fill"
                        )
                        .font(
                            .system(
                                size: 42,
                                weight: .medium
                            )
                        )
                    }
                }
                .foregroundStyle(
                    .white.opacity(0.86)
                )
                .offset(y: 8)
            }
    }

    private var durationOverlay: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                if let durationText {
                    Text(durationText)
                        .font(
                            .system(
                                size: 11,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            .black.opacity(0.46)
                        )
                        .clipShape(Capsule())
                        .padding(.trailing, 16)
                        .padding(.bottom, 13)
                }
            }
        }
        .frame(
            width: width,
            height: height
        )
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

        return String(
            format: "%d:%02d",
            total / 60,
            total % 60
        )
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
        guard player == nil else {
            return
        }

        loadError = nil

        if let localURL = localVideoURL {
            player = AVPlayer(url: localURL)
            if autoplay {
                player?.play()
                isPlaying = true
            }
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

        defer {
            isLoading = false
        }

        do {
            let data =
                try await APIClient.shared.download(
                    path: remotePath,
                    token: token
                )

            let cachedURL =
                try saveRemoteVideo(data)

            player =
                AVPlayer(url: cachedURL)

            if autoplay {
                player?.play()
                isPlaying = true
            }

            print("")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🐱 VIDEO MESSAGE LOADED")
            print("📎", attachment.fileName)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        } catch {
            loadError = error.localizedDescription

            print(
                "❌ Video message load error:",
                error
            )
        }
    }

    private var localVideoURL: URL? {
        guard
            let path = attachment.localPath,
            !path.isEmpty,
            FileManager.default
                .fileExists(
                    atPath: path
                )
        else {
            return nil
        }

        return URL(
            fileURLWithPath: path
        )
    }

    private func saveRemoteVideo(
        _ data: Data
    ) throws -> URL {
        let directory =
            FileManager.default
                .urls(
                    for: .cachesDirectory,
                    in: .userDomainMask
                )
                .first!

        let ext =
            URL(
                fileURLWithPath:
                    attachment.fileName
            )
            .pathExtension

        let fileName =
            "remote-cat-note-" +
            attachment.id.uuidString +
            (
                ext.isEmpty
                    ? ".mov"
                    : ".\(ext)"
            )

        let fileURL =
            directory
                .appendingPathComponent(
                    fileName
                )

        try data.write(
            to: fileURL,
            options: .atomic
        )

        return fileURL
    }

    private func togglePlayback() {
        guard let player else {
            return
        }

        if isPlaying {
            player.pause()
            isPlaying = false
            return
        }

        if
            player.currentTime() >=
            player.currentItem?.duration
                ?? .positiveInfinity
        {
            player.seek(to: .zero)
        }

        player.play()
        isPlaying = true
    }
}

private struct VideoNotePlayerView:
    UIViewRepresentable {

    let player: AVPlayer

    func makeUIView(
        context: Context
    ) -> VideoNotePlayerContainerView {
        let view =
            VideoNotePlayerContainerView()

        view.playerLayer.player =
            player

        view.playerLayer.videoGravity =
            .resizeAspectFill

        return view
    }

    func updateUIView(
        _ uiView:
            VideoNotePlayerContainerView,
        context: Context
    ) {
        uiView.playerLayer.player =
            player
    }
}

private final class VideoNotePlayerContainerView:
    UIView {

    override class var layerClass:
        AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer:
        AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

#Preview {
    VideoNoteBubble(
        attachment:
            Attachment(
                type: .videoNote,
                fileName: "cat-note.mov",
                duration: 12
            )
    )
}
