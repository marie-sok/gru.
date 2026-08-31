import AVFoundation
import Combine
import Combine
import SwiftUI

struct VoiceAudioRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = VoiceAudioRecorderModel()

    let onSend: (VoiceAudioRecording) -> Void

    var body: some View {
        ZStack {
            GRUAppBackdrop()

            VStack(spacing: 24) {
                HStack {
                    Button {
                        model.cancel()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 38, height: 38)
                            .background(Color.primary.opacity(0.07))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 2) {
                        Text("Голос")
                            .font(.system(size: 19, weight: .bold, design: .rounded))

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    Color.clear.frame(width: 38, height: 38)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(GRUColors.accent.opacity(model.isRecording ? 0.15 : 0.08))
                        .frame(
                            width: model.isRecording ? 198 : 178,
                            height: model.isRecording ? 198 : 178
                        )
                        .animation(.easeInOut(duration: 0.35), value: model.isRecording)

                    VStack(spacing: 18) {
                        Text(model.elapsedText)
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .monospacedDigit()

                        Image(systemName: centerIcon)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(GRUColors.accent)
                    }
                }

                VoiceWaveform(
                    samples: model.waveform,
                    progress: 1,
                    barWidth: 4,
                    spacing: 3
                )
                .frame(height: 68)
                .padding(.horizontal, 12)
                .animation(.easeOut(duration: 0.08), value: model.waveform)

                if let error = model.errorText {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                HStack(spacing: 18) {
                    if model.hasRecording {
                        Button {
                            model.reset()
                        } label: {
                            Label("Заново", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.primary.opacity(0.07))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        handlePrimaryAction()
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: primaryIcon)
                            Text(primaryTitle)
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(GRUColors.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isPreparing)
                }
            }
            .padding(20)
        }
        .task {
            await model.prepare()
        }
        .onDisappear {
            model.shutdown()
        }
    }

    private var subtitle: String {
        if model.isRecording { return "мурчим…" }
        if model.hasRecording { return "готово" }
        return "голосовое"
    }

    private var centerIcon: String {
        if model.isRecording { return "waveform" }
        if model.hasRecording { return "checkmark" }
        return "mic.fill"
    }

    private var primaryIcon: String {
        if model.isRecording { return "stop.fill" }
        if model.hasRecording { return "paperplane.fill" }
        return "mic.fill"
    }

    private var primaryTitle: String {
        if model.isRecording { return "Стоп" }
        if model.hasRecording { return "Отправить" }
        return "Записать"
    }

    private func handlePrimaryAction() {
        if model.isRecording {
            model.stopRecording()
            return
        }

        if let recording = model.recording {
            onSend(recording)
            dismiss()
            return
        }

        model.startRecording()
    }
}

@MainActor
final class VoiceAudioRecorderModel: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPreparing = false
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var waveform: [Double] = []
    @Published private(set) var recording: VoiceAudioRecording?
    @Published var errorText: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingURL: URL?
    private let maxDuration: Double = 60

    var hasRecording: Bool { recording != nil }

    var elapsedText: String {
        let value = max(0, Int(elapsed.rounded(.down)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    func prepare() async {
        guard !isPreparing else { return }
        isPreparing = true
        errorText = nil
        let allowed = await requestPermission()
        isPreparing = false

        if !allowed {
            errorText = "Разреши доступ к микрофону в Настройках"
        }
    }

    func startRecording() {
        guard !isRecording, !isPreparing else { return }

        recording = nil
        waveform = []
        elapsed = 0
        errorText = nil
        isPreparing = true

        Task { @MainActor in
            do {
                try await Self.activateRecordingAudioSession()
                try beginRecording()
            } catch {
                errorText = error.localizedDescription
                shutdownRecorder()
            }

            isPreparing = false
        }
    }

    func startRecordingForHold() async -> Bool {
        startRecording()
        return true
    }

    private func beginRecording() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gru-voice-" + UUID().uuidString + ".m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 96_000
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()

        guard recorder.record(forDuration: maxDuration) else {
            throw VoiceAudioRecorderError.couldNotStart
        }

        self.recorder = recorder
        recordingURL = url
        isRecording = true
        startMeterTimer()
    }

    func stopRecording() {
        guard isRecording else { return }
        recorder?.stop()
        finishRecording()
    }

    func reset() {
        if let url = recording?.url {
            try? FileManager.default.removeItem(at: url)
        }
        recording = nil
        waveform = []
        elapsed = 0
        errorText = nil
    }

    func cancel() {
        if isRecording { recorder?.stop() }
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        if let url = recording?.url { try? FileManager.default.removeItem(at: url) }
        recording = nil
        shutdown()
    }

    func shutdown() {
        timer?.invalidate()
        timer = nil

        if isRecording {
            recorder?.stop()
        }

        isRecording = false
        shutdownRecorder()

        Task {
            await Self.deactivateAudioSession()
        }
    }

    private func startMeterTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMeter()
            }
        }
    }

    private func updateMeter() {
        guard let recorder, recorder.isRecording else {
            if isRecording { finishRecording() }
            return
        }

        recorder.updateMeters()
        elapsed = recorder.currentTime

        let db = recorder.averagePower(forChannel: 0)
        let linear = pow(10, Double(db) / 20)
        let boosted = max(0.04, min(1, linear * 4.3))
        waveform.append(boosted)

        if waveform.count > 160 {
            waveform.removeFirst(waveform.count - 160)
        }

        if elapsed >= maxDuration {
            stopRecording()
        }
    }

    private func finishRecording() {
        timer?.invalidate()
        timer = nil
        isRecording = false

        guard
            let url = recordingURL,
            FileManager.default.fileExists(atPath: url.path)
        else {
            errorText = "Голосовое не сохранилось"
            shutdownRecorder()
            return
        }

        recording = VoiceAudioRecording(
            url: url,
            duration: max(0.1, elapsed),
            waveform: summarizedWaveform(waveform, targetCount: 36)
        )

        shutdownRecorder(keepURL: true)
    }

    private func shutdownRecorder(keepURL: Bool = false) {
        recorder = nil
        if !keepURL { recordingURL = nil }
    }

    private func summarizedWaveform(_ source: [Double], targetCount: Int) -> [Double] {
        guard !source.isEmpty else {
            return [0.16, 0.28, 0.42, 0.26, 0.51, 0.36, 0.22, 0.47, 0.31, 0.19, 0.38, 0.25]
        }

        if source.count <= targetCount { return source }
        let bucket = Double(source.count) / Double(targetCount)

        return (0..<targetCount).map { index in
            let start = Int(Double(index) * bucket)
            let end = min(
                source.count,
                max(start + 1, Int(Double(index + 1) * bucket))
            )
            return source[start..<end].max() ?? 0.04
        }
    }

    // MARK: - Async Audio Session

    nonisolated
    private static func activateRecordingAudioSession() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let session = AVAudioSession.sharedInstance()

                    try session.setCategory(
                        .playAndRecord,
                        mode: .spokenAudio,
                        options: [
                            .defaultToSpeaker,
                            .allowBluetoothHFP
                        ]
                    )

                    try session.setActive(true)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated
    private static func deactivateAudioSession() async {
        await withCheckedContinuation {
            (continuation: CheckedContinuation<Void, Never>) in

            DispatchQueue.global(qos: .utility).async {
                try? AVAudioSession.sharedInstance().setActive(
                    false,
                    options: .notifyOthersOnDeactivation
                )

                continuation.resume()
            }
        }
    }

    private func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await AVAudioApplication.requestRecordPermission()
            @unknown default:
                return false
            }
        } else {
            let session = AVAudioSession.sharedInstance()

            switch session.recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await withCheckedContinuation { continuation in
                    session.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default:
                return false
            }
        }
    }
}

private enum VoiceAudioRecorderError: LocalizedError {
    case couldNotStart

    var errorDescription: String? {
        "Не удалось начать запись"
    }
}
