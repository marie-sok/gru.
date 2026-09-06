import AVFoundation
import SwiftUI

struct AudioBubble: View {
    let attachment: Attachment

    @State private var player: AVAudioPlayer?
    @State private var preparedAudioURL: URL?
    @State private var isPlaying = false
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var progress: Double = 0
    @State private var progressTask: Task<Void, Never>?
    @State private var audioSessionTask: Task<Void, Never>?

    @State private var showTranscript = false
    @State private var transcript: String?
    @State private var transcriptionError: String?
    @State private var isTranscribing = false
    @State private var transcriptionTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(GRUColors.accent)
                            .frame(width: 42, height: 42)

                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(
                                systemName:
                                    isPlaying
                                    ? "pause.fill"
                                    : "play.fill"
                            )
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: isPlaying ? 0 : 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isPlaying
                    ? "Пауза"
                    : "Воспроизвести голосовое"
                )

                VStack(alignment: .leading, spacing: 5) {
                    VoiceWaveform(
                        samples: attachment.waveform ?? [],
                        progress: progress,
                        barWidth: 3,
                        spacing: 2
                    )
                    .frame(height: 34)

                    HStack(spacing: 7) {
                        Text(timeText)
                            .font(
                                .system(
                                    size: 11,
                                    weight: .medium,
                                    design: .rounded
                                )
                            )
                            .monospacedDigit()
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            handleTranscriptButton()
                        } label: {
                            HStack(spacing: 4) {
                                if isTranscribing {
                                    ProgressView()
                                        .controlSize(.mini)
                                        .tint(GRUColors.accent)
                                } else {
                                    Image(systemName: "text.bubble")
                                        .font(
                                            .system(
                                                size: 10,
                                                weight: .bold
                                            )
                                        )
                                }

                                Text(
                                    showTranscript
                                    ? "Скрыть"
                                    : "Текст"
                                )
                                .font(
                                    .system(
                                        size: 10,
                                        weight: .bold,
                                        design: .rounded
                                    )
                                )
                            }
                            .foregroundStyle(GRUColors.accent)
                            .padding(.horizontal, 7)
                            .frame(height: 24)
                            .background(
                                GRUColors.accent.opacity(0.10),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                        .accessibilityLabel(
                            showTranscript
                            ? "Скрыть расшифровку"
                            : "Расшифровать голосовое в текст"
                        )
                    }
                }
            }

            if showTranscript {
                transcriptContent
                    .transition(
                        .opacity
                            .combined(with: .move(edge: .top))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: 274)
        .background(Color.primary.opacity(0.055))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                GRUColors.accent.opacity(0.13),
                lineWidth: 1
            )
        }
        .animation(
            .easeInOut(duration: 0.18),
            value: showTranscript
        )
        .task(id: loadIdentity) {
            await preparePlayerIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: AVAudioSession.interruptionNotification
            )
        ) { notification in
            guard
                let userInfo = notification.userInfo,
                let typeValue =
                    userInfo[
                        AVAudioSessionInterruptionTypeKey
                    ] as? UInt,
                let type =
                    AVAudioSession.InterruptionType(
                        rawValue: typeValue
                    )
            else {
                return
            }

            if type == .began, isPlaying {
                player?.pause()
                isPlaying = false
                progressTask?.cancel()
            }
        }
        .onDisappear {
            progressTask?.cancel()
            audioSessionTask?.cancel()
            transcriptionTask?.cancel()

            player?.stop()
            isPlaying = false

            Task {
                await Self.deactivatePlaybackAudioSession()
            }
        }
    }

    @ViewBuilder
    private var transcriptContent: some View {
        Divider()
            .opacity(0.12)

        if isTranscribing {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .tint(GRUColors.accent)

                Text("Расшифровываю голосовое…")
                    .font(
                        .system(
                            size: 12,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

        } else if let transcript {
            VStack(alignment: .leading, spacing: 5) {
                Label(
                    "Расшифровка",
                    systemImage: "quote.bubble.fill"
                )
                .font(
                    .system(
                        size: 10,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(GRUColors.accent)

                Text(transcript)
                    .font(
                        .system(
                            size: 13,
                            weight: .medium,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(GRUColors.text)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .textSelection(.enabled)
            }

        } else if let transcriptionError {
            VStack(alignment: .leading, spacing: 6) {
                Text(transcriptionError)
                    .font(
                        .system(
                            size: 11,
                            weight: .medium,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                Button("Повторить") {
                    startTranscription(force: true)
                }
                .font(
                    .system(
                        size: 11,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(GRUColors.accent)
                .buttonStyle(.plain)
            }
        }
    }

    private var loadIdentity: String {
        [
            attachment.localPath ?? "",
            attachment.remoteURL ?? "",
            attachment.fileName
        ]
        .joined(separator: "|")
    }

    private var timeText: String {
        let duration =
            max(
                0,
                player?.duration
                    ?? attachment.duration
                    ?? 0
            )

        let current =
            max(
                0,
                player?.currentTime
                    ?? 0
            )

        let shown =
            isPlaying
            ? current
            : (progress > 0 ? current : duration)

        let seconds =
            Int(
                shown.rounded(.down)
            )

        return String(
            format: "%d:%02d",
            seconds / 60,
            seconds % 60
        )
    }

    @MainActor
    private func preparePlayerIfNeeded() async {
        if player != nil,
           preparedAudioURL != nil {
            return
        }

        loadError = nil

        if let localURL = localAudioURL {
            preparePlayer(url: localURL)
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

            let url =
                try cacheAudio(data)

            preparePlayer(url: url)

            print("")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🎧 VOICE AUDIO LOADED")
            print("📎", attachment.fileName)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        } catch {
            loadError =
                error.localizedDescription

            print(
                "❌ Voice audio load error:",
                error
            )
        }
    }

    private var localAudioURL: URL? {
        guard
            let path = attachment.localPath,
            !path.isEmpty,
            FileManager.default.fileExists(
                atPath: path
            )
        else {
            return nil
        }

        return URL(
            fileURLWithPath: path
        )
    }

    private func preparePlayer(url: URL) {
        preparedAudioURL = url

        do {
            let audioPlayer =
                try AVAudioPlayer(
                    contentsOf: url
                )

            audioPlayer.prepareToPlay()
            player = audioPlayer

        } catch {
            loadError =
                error.localizedDescription
        }
    }

    private func cacheAudio(
        _ data: Data
    ) throws -> URL {
        let directory =
            FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first!

        let ext =
            URL(
                fileURLWithPath:
                    attachment.fileName
            )
            .pathExtension

        let fileURL =
            directory.appendingPathComponent(
                "remote-voice-"
                    + attachment.id.uuidString
                    + (
                        ext.isEmpty
                        ? ".m4a"
                        : ".\(ext)"
                    )
            )

        try data.write(
            to: fileURL,
            options: .atomic
        )

        return fileURL
    }

    private func handleTranscriptButton() {
        if showTranscript {
            showTranscript = false
            return
        }

        showTranscript = true

        if transcript == nil,
           !isTranscribing {
            startTranscription(
                force: false
            )
        }
    }

    private func startTranscription(
        force: Bool
    ) {
        guard !isTranscribing else {
            return
        }

        if transcript != nil,
           !force {
            return
        }

        transcriptionTask?.cancel()

        transcriptionTask =
            Task { @MainActor in
                isTranscribing = true
                transcriptionError = nil

                await preparePlayerIfNeeded()

                guard
                    let audioURL =
                        preparedAudioURL
                        ?? localAudioURL
                else {
                    isTranscribing = false
                    transcriptionError =
                        loadError
                        ?? "Не удалось подготовить голосовое для расшифровки."
                    return
                }

                do {
                    let value =
                        try await
                            GRUVoiceTranscriptionService.shared
                            .transcribe(
                                audioURL: audioURL
                            )

                    guard !Task.isCancelled else {
                        isTranscribing = false
                        return
                    }

                    transcript = value
                    transcriptionError = nil

                } catch {
                    guard !Task.isCancelled else {
                        isTranscribing = false
                        return
                    }

                    transcriptionError =
                        error.localizedDescription
                }

                isTranscribing = false
            }
    }

    private func togglePlayback() {
        guard let player else {
            return
        }

        if isPlaying {
            player.pause()
            isPlaying = false
            progressTask?.cancel()
            return
        }

        guard !isLoading else {
            return
        }

        isLoading = true
        audioSessionTask?.cancel()

        audioSessionTask =
            Task { @MainActor in
                do {
                    try await
                        Self.activatePlaybackAudioSession()
                } catch {
                    print(
                        "⚠️ Audio session:",
                        error
                    )
                }

                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }

                isLoading = false

                if player.currentTime
                    >= player.duration - 0.05
                {
                    player.currentTime = 0
                }

                guard player.play() else {
                    return
                }

                isPlaying = true
                startProgressLoop()
            }
    }

    nonisolated
    private static func activatePlaybackAudioSession()
        async throws
    {
        try await withCheckedThrowingContinuation {
            (
                continuation:
                    CheckedContinuation<
                        Void,
                        Error
                    >
            ) in

            DispatchQueue.global(
                qos: .userInitiated
            )
            .async {
                do {
                    let session =
                        AVAudioSession.sharedInstance()

                    try session.setCategory(
                        .playback,
                        mode: .spokenAudio
                    )

                    try session.setActive(true)

                    continuation.resume()

                } catch {
                    continuation.resume(
                        throwing: error
                    )
                }
            }
        }
    }

    nonisolated
    private static func deactivatePlaybackAudioSession()
        async
    {
        await withCheckedContinuation {
            (
                continuation:
                    CheckedContinuation<
                        Void,
                        Never
                    >
            ) in

            DispatchQueue.global(
                qos: .utility
            )
            .async {
                try?
                    AVAudioSession.sharedInstance()
                    .setActive(
                        false,
                        options:
                            .notifyOthersOnDeactivation
                    )

                continuation.resume()
            }
        }
    }

    private func startProgressLoop() {
        progressTask?.cancel()

        progressTask =
            Task { @MainActor in
                while
                    !Task.isCancelled,
                    let player,
                    isPlaying
                {
                    if player.duration > 0 {
                        progress =
                            min(
                                1,
                                max(
                                    0,
                                    player.currentTime
                                        / player.duration
                                )
                            )
                    }

                    if !player.isPlaying {
                        isPlaying = false

                        if player.currentTime
                            >= player.duration - 0.05
                        {
                            player.currentTime = 0
                            progress = 0
                        }

                        break
                    }

                    try?
                        await Task.sleep(
                            for:
                                .milliseconds(60)
                        )
                }
            }
    }
}
