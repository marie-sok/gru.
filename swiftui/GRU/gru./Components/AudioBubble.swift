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
    @State private var transcript: GRUVoiceTranscript?
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
                            ProgressView().tint(.white)
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
                    GRUL10n.text(
                        isPlaying
                        ? "Пауза"
                        : "Воспроизвести голосовое"
                    )
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
                                    Image(
                                        systemName:
                                            "captions.bubble.fill"
                                    )
                                    .font(
                                        .system(
                                            size: 10,
                                            weight: .bold
                                        )
                                    )
                                }

                                Text(
                                    GRUL10n.text(
                                        showTranscript
                                        ? "Скрыть"
                                        : "Текст"
                                    )
                                )
                                .font(
                                    .system(
                                        size: 10,
                                        weight: .bold,
                                        design: .rounded
                                    )
                                )

                                if let transcript,
                                   !showTranscript
                                {
                                    Text(transcript.language.badge)
                                        .font(
                                            .system(
                                                size: 8,
                                                weight: .black,
                                                design: .rounded
                                            )
                                        )
                                }
                            }
                            .foregroundStyle(GRUColors.accent)
                            .padding(.horizontal, 7)
                            .frame(height: 25)
                            .background(
                                GRUColors.accent.opacity(0.10),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                        .accessibilityLabel(
                            GRUL10n.text(
                                showTranscript
                                ? "Скрыть расшифровку"
                                : "Расшифровать голосовое в текст"
                            )
                        )
                    }
                }
            }

            if showTranscript {
                transcriptContent
                    .transition(
                        .opacity.combined(
                            with: .move(edge: .top)
                        )
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: 286)
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
            loadCachedTranscriptIfNeeded()
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

                VStack(alignment: .leading, spacing: 2) {
                    Text("Распознаю RU + EN…")
                        .font(
                            .system(
                                size: 12,
                                weight: .semibold,
                                design: .rounded
                            )
                        )

                    Text(
                        "автоматически выбираю лучший язык"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)

        } else if let transcript {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
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

                    Spacer()

                    Menu {
                        Button {
                            startTranscription(
                                forcedLanguage: .russian
                            )
                        } label: {
                            Label(
                                "Русский",
                                systemImage:
                                    transcript.language == .russian
                                    ? "checkmark"
                                    : "character.bubble"
                            )
                        }

                        Button {
                            startTranscription(
                                forcedLanguage: .english
                            )
                        } label: {
                            Label(
                                "English",
                                systemImage:
                                    transcript.language == .english
                                    ? "checkmark"
                                    : "character.bubble"
                            )
                        }

                        Divider()

                        Button {
                            startTranscription(
                                forcedLanguage: nil
                            )
                        } label: {
                            Label(
                                "Авто RU + EN",
                                systemImage: "wand.and.stars"
                            )
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(transcript.language.badge)
                                .font(
                                    .system(
                                        size: 9,
                                        weight: .black,
                                        design: .rounded
                                    )
                                )

                            Image(systemName: "chevron.down")
                                .font(
                                    .system(
                                        size: 8,
                                        weight: .bold
                                    )
                                )
                        }
                        .foregroundStyle(GRUColors.accent)
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(
                            GRUColors.accent.opacity(0.10),
                            in: Capsule()
                        )
                    }
                }

                Text(transcript.text)
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

                HStack(spacing: 5) {
                    Text(transcript.language.title)
                    Text("•")
                    Text(
                        confidenceText(
                            transcript.confidence
                        )
                    )
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

        } else if let transcriptionError {
            VStack(alignment: .leading, spacing: 7) {
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

                HStack(spacing: 12) {
                    Button("Авто RU + EN") {
                        startTranscription(
                            forcedLanguage: nil
                        )
                    }

                    Menu("Язык") {
                        Button("Русский") {
                            startTranscription(
                                forcedLanguage: .russian
                            )
                        }

                        Button("English") {
                            startTranscription(
                                forcedLanguage: .english
                            )
                        }
                    }
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

    private var transcriptFingerprint: String {
        GRUVoiceTranscriptCache.fingerprint(
            remoteURL: attachment.remoteURL,
            fileName: attachment.fileName,
            size: attachment.size,
            duration: attachment.duration
        )
    }

    private func confidenceText(
        _ confidence: Double
    ) -> String {
        let percent = Int(
            (
                min(
                    1,
                    max(0, confidence)
                )
                * 100
            )
            .rounded()
        )

        return "\(percent)%"
    }

    private func loadCachedTranscriptIfNeeded() {
        guard transcript == nil else {
            return
        }

        transcript = GRUVoiceTranscriptCache.shared.load(
            fingerprint: transcriptFingerprint
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

    private var timeText: String {
        let duration = max(
            0,
            player?.duration
                ?? attachment.duration
                ?? 0
        )

        let current = max(
            0,
            player?.currentTime ?? 0
        )

        let shown =
            isPlaying
            ? current
            : (progress > 0 ? current : duration)

        let seconds = Int(
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
           preparedAudioURL != nil
        {
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
        defer { isLoading = false }

        do {
            let data = try await APIClient.shared.download(
                path: remotePath,
                token: token
            )

            let url = try cacheAudio(data)
            preparePlayer(url: url)

        } catch {
            loadError = error.localizedDescription
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

        return URL(fileURLWithPath: path)
    }

    private func preparePlayer(url: URL) {
        preparedAudioURL = url

        do {
            let audioPlayer = try AVAudioPlayer(
                contentsOf: url
            )

            audioPlayer.prepareToPlay()
            player = audioPlayer

        } catch {
            loadError = error.localizedDescription
        }
    }

    private func cacheAudio(
        _ data: Data
    ) throws -> URL {
        let directory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first!

        let ext = URL(
            fileURLWithPath: attachment.fileName
        ).pathExtension

        let fileURL = directory.appendingPathComponent(
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
        loadCachedTranscriptIfNeeded()

        if transcript == nil,
           !isTranscribing
        {
            startTranscription(
                forcedLanguage: nil
            )
        }
    }

    private func startTranscription(
        forcedLanguage: GRUVoiceLanguage?
    ) {
        guard !isTranscribing else {
            return
        }

        transcriptionTask?.cancel()

        transcriptionTask = Task { @MainActor in
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
                    ?? GRUL10n.text(
                        "Не удалось подготовить голосовое для расшифровки."
                    )
                return
            }

            do {
                let value: GRUVoiceTranscript

                if let forcedLanguage {
                    value = try await
                        GRUVoiceTranscriptionService.shared
                        .transcribe(
                            audioURL: audioURL,
                            language: forcedLanguage
                        )
                } else {
                    value = try await
                        GRUVoiceTranscriptionService.shared
                        .transcribeAuto(
                            audioURL: audioURL
                        )
                }

                guard !Task.isCancelled else {
                    isTranscribing = false
                    return
                }

                transcript = value
                transcriptionError = nil

                GRUVoiceTranscriptCache.shared.save(
                    value,
                    fingerprint: transcriptFingerprint
                )

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

        audioSessionTask = Task { @MainActor in
            do {
                try await Self.activatePlaybackAudioSession()
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
                    CheckedContinuation<Void, Error>
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
                    CheckedContinuation<Void, Never>
            ) in

            DispatchQueue.global(
                qos: .utility
            )
            .async {
                try? AVAudioSession.sharedInstance().setActive(
                    false,
                    options: .notifyOthersOnDeactivation
                )

                continuation.resume()
            }
        }
    }

    private func startProgressLoop() {
        progressTask?.cancel()

        progressTask = Task { @MainActor in
            while
                !Task.isCancelled,
                let player,
                isPlaying
            {
                if player.duration > 0 {
                    progress = min(
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

                try? await Task.sleep(
                    for: .milliseconds(60)
                )
            }
        }
    }
}
