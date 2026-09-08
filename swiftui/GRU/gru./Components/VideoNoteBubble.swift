import AVFoundation
import SwiftUI

struct VideoNoteBubble: View {
    let attachment: Attachment

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var glowPulse = false

    @AppStorage("gru.settings.chats.videoNoteAutoplay")
    private var autoplay = true

    @AppStorage("gru.settings.accessibility.reduceMotion")
    private var reduceMotion = false

    private let width: CGFloat = 150
    private let height: CGFloat = 160

    private var catShape: CatVideoNoteShape {
        CatVideoNoteShape()
    }

    var body: some View {
        ZStack {
            videoLayer

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.clear,
                    Color.black.opacity(0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(catShape)
            .allowsHitTesting(false)

            catShape
                .stroke(
                    GRUColors.accent.opacity(glowPulse ? 0.28 : 0.11),
                    lineWidth: 7
                )
                .blur(radius: 8)
                .frame(width: width, height: height)
                .allowsHitTesting(false)

            catShape
                .stroke(
                    GRUColors.neonGradient,
                    lineWidth: isPlaying ? 2.4 : 1.8
                )
                .frame(width: width, height: height)
                .shadow(
                    color: GRUColors.accent.opacity(glowPulse ? 0.42 : 0.18),
                    radius: glowPulse ? 14 : 7
                )
                .allowsHitTesting(false)

            if player != nil, !isPlaying {
                playButton
            }

            chromeOverlay
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
            guard !reduceMotion else { return }

            withAnimation(
                .easeInOut(duration: 1.55)
                    .repeatForever(autoreverses: true)
            ) {
                glowPulse = true
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .AVPlayerItemDidPlayToEndTime
            )
        ) { notification in
            guard let currentItem = player?.currentItem,
                  let finishedItem = notification.object as? AVPlayerItem,
                  currentItem === finishedItem
            else {
                return
            }

            isPlaying = false
        }
        .onDisappear {
            player?.pause()
            isPlaying = false
        }
        .accessibilityLabel(
            GRUL10n.text(
                "Кото-кружок. Нажми, чтобы воспроизвести или поставить на паузу"
            )
        )
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
                .fill(.black.opacity(0.48))
                .frame(width: 46, height: 46)

            Circle()
                .stroke(GRUColors.neonGradient, lineWidth: 1.2)
                .frame(width: 46, height: 46)

            Image(systemName: "play.fill")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
                .offset(x: 1.5)
        }
        .offset(y: 4)
        .shadow(color: GRUColors.accent.opacity(0.24), radius: 10)
    }

    private var placeholder: some View {
        catShape
            .fill(
                LinearGradient(
                    colors: [
                        GRUColors.card,
                        GRUColors.accent.opacity(glowPulse ? 0.17 : 0.08)
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
                        VStack(spacing: 7) {
                            Image(
                                systemName: loadError == nil
                                    ? "pawprint.fill"
                                    : "exclamationmark.circle.fill"
                            )
                            .font(.system(size: 24, weight: .semibold))

                            Text(
                                loadError == nil
                                    ? "cat note"
                                    : GRUL10n.text("ошибка")
                            )
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(0.6)
                        }
                    }
                }
                .foregroundStyle(.white.opacity(0.84))
                .offset(y: 4)
            }
    }

    private var chromeOverlay: some View {
        VStack {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 8, weight: .black))

                    Text("CAT NOTE")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .tracking(0.7)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .frame(height: 21)
                .background(.black.opacity(0.42), in: Capsule())

                Spacer()

                if isPlaying {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(GRUColors.accent)
                            .frame(width: 5, height: 5)

                        Text("LIVE")
                            .font(.system(size: 7, weight: .black, design: .rounded))
                            .tracking(0.6)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(height: 21)
                    .background(.black.opacity(0.42), in: Capsule())
                }
            }

            Spacer()

            HStack {
                Spacer()

                if let durationText {
                    Text(durationText)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(.black.opacity(0.48), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.top, 18)
        .padding(.bottom, 10)
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
        let fileName =
            "remote-cat-note-"
            + attachment.id.uuidString
            + (ext.isEmpty ? ".mov" : ".\(ext)")

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

        if player.currentTime()
            >= player.currentItem?.duration ?? .positiveInfinity {
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
