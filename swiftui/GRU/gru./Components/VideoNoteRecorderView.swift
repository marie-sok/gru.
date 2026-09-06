import AVFoundation
import SwiftUI
import Combine

struct VideoNoteRecorderView: View {
    @StateObject private var recorder = VideoNoteRecorderModel()
    @State private var glowPulse = false
    @State private var pendingRelease = false
    @State private var handledCancelSerial = 0

    let isHolding: Bool
    let isLocked: Bool
    let cancelSerial: Int
    let onFinished: (URL) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 11) {
            header
            preview

            if isLocked {
                lockedControls
            } else {
                gestureHint
            }
        }
        .padding(12)
        .frame(width: 232)
        .background(.ultraThinMaterial)
        .background(GRUColors.card.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(GRUColors.neonGradient, lineWidth: 1.3)
        }
        .shadow(color: GRUColors.accent.opacity(0.34), radius: 24, y: 10)
        .shadow(color: GRUColors.accentSecondary.opacity(0.16), radius: 34, y: 14)
        .onAppear {
            handledCancelSerial = cancelSerial
            pendingRelease = !isHolding && !isLocked

            recorder.onRecordingFinished = { url in
                onFinished(url)
            }

            recorder.prepare()

            withAnimation(
                .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
            ) {
                glowPulse = true
            }
        }
        .onDisappear {
            recorder.shutdown()
        }
        .onChange(of: recorder.isRecording) { _, recording in
            guard recording, pendingRelease, !isLocked else { return }

            pendingRelease = false

            // If camera preparation finished just after the user's release,
            // keep a tiny valid recording instead of creating a zero-byte file.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                guard recorder.isRecording, !isLocked else { return }
                recorder.finishRecording()
            }
        }
        .onChange(of: isHolding) { _, holding in
            guard !holding, !isLocked else { return }
            finishAfterFingerRelease()
        }
        .onChange(of: isLocked) { _, locked in
            if locked {
                pendingRelease = false
            }
        }
        .onChange(of: cancelSerial) { _, serial in
            guard serial != handledCancelSerial else { return }
            handledCancelSerial = serial
            pendingRelease = false
            recorder.cancelRecordingIfNeeded()
            onCancel()
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Button {
                pendingRelease = false
                recorder.cancelRecordingIfNeeded()
                onCancel()
            } label: {
                VideoNoteRecorderNeonIcon(systemName: "xmark", size: 30, iconSize: 11)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Image(systemName: "video.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GRUColors.accent)
                    .font(.caption.weight(.bold))

                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(recorder.isRecording ? Color.red : GRUColors.accent)
                    .frame(width: 6, height: 6)

                Text(recorder.elapsedText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
            }
        }
    }

    private var statusText: String {
        if isLocked { return "запись зафиксирована" }
        if recorder.isRecording { return "удерживай • ← отмена • ↑ замок" }
        if recorder.isPreparing { return "готовим камеру" }
        return "камера"
    }

    private var preview: some View {
        ZStack {
            if recorder.isReady {
                VideoNoteCameraPreview(
                    session: recorder.session,
                    isMirrored: recorder.isFrontCamera
                )
                .frame(width: 180, height: 194)
                .clipShape(CatVideoNoteShape())
            } else {
                CatVideoNoteShape()
                    .fill(.white.opacity(0.08))
                    .frame(width: 180, height: 194)
                    .overlay {
                        if recorder.isPreparing {
                            ProgressView()
                                .tint(GRUColors.accent)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "video.slash.fill")
                                    .font(.system(size: 26))

                                Text(recorder.errorText ?? "Камера недоступна")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(18)
                        }
                    }
            }

            CatVideoNoteShape()
                .stroke(
                    GRUColors.accent.opacity(glowPulse ? 0.50 : 0.24),
                    lineWidth: 9
                )
                .blur(radius: 8)
                .frame(width: 182, height: 196)

            CatVideoNoteShape()
                .stroke(
                    GRUColors.neonGradient,
                    lineWidth: recorder.isRecording ? 3.2 : 2.0
                )
                .frame(width: 182, height: 196)
                .shadow(
                    color: GRUColors.accent.opacity(glowPulse ? 0.72 : 0.36),
                    radius: glowPulse ? 18 : 10
                )

            if recorder.isRecording {
                CatVideoNoteShape()
                    .trim(from: 0, to: min(max(recorder.elapsed / 60.0, 0.015), 1.0))
                    .stroke(
                        Color.red.opacity(0.92),
                        style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 184, height: 198)
                    .shadow(color: Color.red.opacity(0.42), radius: 7)
                    .animation(.linear(duration: 0.20), value: recorder.elapsed)

                VStack {
                    Spacer()
                    Text(recorder.elapsedText)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(.black.opacity(0.54), in: Capsule())
                        .padding(.bottom, 10)
                }
                .frame(width: 180, height: 194)
            }

            if isLocked {
                VStack {
                    HStack {
                        Spacer()

                        Label("LOCK", systemImage: "lock.fill")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.46), in: Capsule())
                    }

                    Spacer()
                }
                .padding(10)
                .frame(width: 180, height: 194)
            }
        }
        .frame(width: 186, height: 200)
    }

    private var gestureHint: some View {
        HStack(spacing: 10) {
            Label("← отменить", systemImage: "chevron.left")
            Spacer(minLength: 4)
            Label("↑ закрепить", systemImage: "lock.fill")
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 5)
        .frame(height: 38)
    }

    private var lockedControls: some View {
        HStack(spacing: 20) {
            Button {
                pendingRelease = false
                recorder.cancelRecordingIfNeeded()
                onCancel()
            } label: {
                VideoNoteRecorderNeonIcon(systemName: "trash.fill", size: 38, iconSize: 13)
            }
            .buttonStyle(.plain)

            Button {
                pendingRelease = false
                recorder.finishRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(GRUColors.card.opacity(0.92))
                        .frame(width: 52, height: 52)

                    Circle()
                        .stroke(
                            GRUColors.neonGradient,
                            lineWidth: 1.6
                        )
                        .frame(width: 52, height: 52)

                    VideoNoteRecorderEnvelopeShape()
                        .stroke(
                            GRUColors.accent,
                            style: StrokeStyle(
                                lineWidth: 2.0,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .frame(width: 23, height: 18)
                }
            }
            .buttonStyle(.plain)
            .disabled(!recorder.isRecording)
            .opacity(recorder.isRecording ? 1 : 0.45)

            Button {
                recorder.flipCamera()
            } label: {
                VideoNoteRecorderNeonIcon(
                    systemName: "camera.rotate.fill",
                    size: 38,
                    iconSize: 13
                )
            }
            .buttonStyle(.plain)
            .disabled(!recorder.isReady || recorder.isRecording)
            .opacity(recorder.isReady && !recorder.isRecording ? 1 : 0.35)
        }
    }

    private func finishAfterFingerRelease() {
        if recorder.isRecording {
            recorder.finishRecording()
        } else {
            pendingRelease = true
        }
    }
}

final class VideoNoteRecorderModel:
    NSObject,
    ObservableObject,
    AVCaptureFileOutputRecordingDelegate
{
    let session = AVCaptureSession()

    @Published private(set) var isPreparing = false
    @Published private(set) var isReady = false
    @Published private(set) var isRecording = false
    @Published private(set) var isFrontCamera = true
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var errorText: String?

    var onRecordingFinished: ((URL) -> Void)?

    private let movieOutput = AVCaptureMovieFileOutput()

    /// All AVCaptureSession mutations live on one serial queue.
    /// This prevents startRunning/stopRunning from racing with
    /// beginConfiguration/commitConfiguration.
    private let sessionQueue = DispatchQueue(
        label: "gru.video-note.capture-session",
        qos: .userInitiated
    )

    private var currentVideoInput: AVCaptureDeviceInput?
    private var timer: Timer?
    private var recordingURL: URL?
    private var didCancelRecording = false
    private var isSessionConfigured = false

    var elapsedText: String {
        let value = min(Int(elapsed), 60)
        return String(
            format: "0:%02d / 1:00",
            value
        )
    }

    // MARK: - Prepare

    func prepare() {
        guard !isPreparing, !isReady else {
            return
        }

        isPreparing = true
        errorText = nil

        Task {
            let videoAllowed =
                await Self.requestAccess(
                    for: .video
                )

            _ =
                await Self.requestAccess(
                    for: .audio
                )

            await MainActor.run {
                guard videoAllowed else {
                    self.isPreparing = false
                    self.errorText =
                        "Разреши доступ к камере в Настройках"
                    return
                }

                self.configureAndStartSession()
            }
        }
    }

    private static func requestAccess(
        for mediaType: AVMediaType
    ) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(
            for: mediaType
        ) {
        case .authorized:
            return true

        case .notDetermined:
            return await AVCaptureDevice.requestAccess(
                for: mediaType
            )

        default:
            return false
        }
    }

    // MARK: - Session

    private func configureAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                if !self.isSessionConfigured {
                    try self.configureSessionGraph()
                    self.isSessionConfigured = true
                }

                print(
                    "🐱 VIDEO NOTE: configured inputs=",
                    self.session.inputs.count,
                    "outputs=",
                    self.session.outputs.count
                )

                self.startSessionWithRetry(attempt: 0)
            } catch {
                print(
                    "❌ VIDEO NOTE: configure session error:",
                    error
                )

                DispatchQueue.main.async {
                    self.isPreparing = false
                    self.isReady = false
                    self.errorText =
                        "Не удалось настроить камеру: \(error.localizedDescription)"
                }
            }
        }
    }

    private func startSessionWithRetry(
        attempt: Int
    ) {
        dispatchPrecondition(
            condition: .onQueue(sessionQueue)
        )

        if !session.isRunning {
            print(
                "🐱 VIDEO NOTE: startRunning attempt",
                attempt + 1
            )
            session.startRunning()
        }

        if session.isRunning {
            let isFront =
                currentVideoInput?.device.position == .front

            print(
                "✅ VIDEO NOTE: CAPTURE SESSION RUNNING"
            )

            DispatchQueue.main.async {
                self.isPreparing = false
                self.isReady = true
                self.isFrontCamera = isFront
                self.errorText = nil
            }

            sessionQueue.asyncAfter(
                deadline: .now() + 0.18
            ) { [weak self] in
                self?.startRecordingOnSessionQueue()
            }

            return
        }

        guard attempt < 5 else {
            print(
                "❌ VIDEO NOTE: session failed to start after retries"
            )

            DispatchQueue.main.async {
                self.isPreparing = false
                self.isReady = false
                self.errorText =
                    "Камера не запустилась"
            }
            return
        }

        sessionQueue.asyncAfter(
            deadline: .now() + 0.30
        ) { [weak self] in
            self?.startSessionWithRetry(
                attempt: attempt + 1
            )
        }
    }

    /// Configures inputs/output only.
    /// This method ALWAYS commits before it returns.
    private func configureSessionGraph() throws {
        session.beginConfiguration()

        do {
            session.sessionPreset = .hd1280x720

            // Clean up partially configured state if prepare() is retried.
            for input in session.inputs {
                session.removeInput(input)
            }

            if session.outputs.contains(
                where: { $0 === movieOutput }
            ) {
                session.removeOutput(movieOutput)
            }

            let videoDevice =
                try preferredCamera(
                    position: .front
                )

            let videoInput =
                try AVCaptureDeviceInput(
                    device: videoDevice
                )

            guard session.canAddInput(videoInput) else {
                throw RecorderError.cannotAddVideoInput
            }

            session.addInput(videoInput)
            currentVideoInput = videoInput

            if
                AVCaptureDevice.authorizationStatus(
                    for: .audio
                ) == .authorized,
                let audioDevice =
                    AVCaptureDevice.default(
                        for: .audio
                    )
            {
                do {
                    let audioInput =
                        try AVCaptureDeviceInput(
                            device: audioDevice
                        )

                    if session.canAddInput(audioInput) {
                        session.addInput(audioInput)
                    }
                } catch {
                    print(
                        "⚠️ VIDEO NOTE: mic unavailable; video continues:",
                        error
                    )
                }
            }

            guard session.canAddOutput(movieOutput) else {
                throw RecorderError.cannotAddMovieOutput
            }

            session.addOutput(movieOutput)

            movieOutput.maxRecordedDuration =
                CMTime(
                    seconds: 60,
                    preferredTimescale: 600
                )

            if let connection =
                movieOutput.connection(
                    with: .video
                )
            {
                configurePortraitRotation(
                    on: connection
                )
                configureMirroring(
                    on: connection,
                    mirrored: videoDevice.position == .front
                )
            }

            // Configuration is fully finished here.
            session.commitConfiguration()

        } catch {
            // AVCaptureSession MUST always leave configuration mode,
            // even when an input/output fails to configure.
            session.commitConfiguration()
            throw error
        }
    }

    // MARK: - Rotation

    private func configurePortraitRotation(
        on connection: AVCaptureConnection
    ) {
        if #available(iOS 17.0, *) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    private func configureMirroring(
        on connection: AVCaptureConnection,
        mirrored: Bool
    ) {
        guard connection.isVideoMirroringSupported else {
            return
        }

        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirrored
    }

    // MARK: - Recording

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecordingIfNeeded() {
        guard !isRecording else { return }
        startRecording()
    }

    private func startRecordingOnSessionQueue() {
        dispatchPrecondition(
            condition: .onQueue(sessionQueue)
        )

        guard session.isRunning else { return }

        guard !movieOutput.isRecording else {
            return
        }

        guard
            let connection =
                movieOutput.connection(with: .video),
            connection.isEnabled
        else {
            print(
                "❌ VIDEO NOTE: no active video connection"
            )
            DispatchQueue.main.async {
                self.errorText =
                    "Нет активного видеоканала"
            }
            return
        }

        configurePortraitRotation(on: connection)
        configureMirroring(
            on: connection,
            mirrored:
                currentVideoInput?.device.position == .front
        )

        if
            AVCaptureDevice.authorizationStatus(
                for: .audio
            ) == .authorized
        {
            do {
                let audioSession =
                    AVAudioSession.sharedInstance()

                try audioSession.setCategory(
                    .playAndRecord,
                    mode: .videoRecording,
                    options: [
                        .defaultToSpeaker,
                        .allowBluetoothHFP
                    ]
                )
                try audioSession.setActive(true)
            } catch {
                print(
                    "⚠️ VIDEO NOTE: audio session error; video continues:",
                    error
                )
            }
        }

        let url =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "gru-cat-note-\(UUID().uuidString)"
                )
                .appendingPathExtension("mov")

        try? FileManager.default.removeItem(at: url)

        recordingURL = url
        didCancelRecording = false

        DispatchQueue.main.async {
            self.elapsed = 0
            self.errorText = nil
        }

        print(
            "🐱 VIDEO NOTE: movieOutput.startRecording ->",
            url.lastPathComponent
        )

        movieOutput.startRecording(
            to: url,
            recordingDelegate: self
        )
    }

    private func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.session.isRunning {
                self.startSessionWithRetry(
                    attempt: 0
                )
                return
            }

            self.startRecordingOnSessionQueue()
        }
    }

    func finishRecording() {
        stopRecording()
    }

    private func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard self.movieOutput.isRecording else {
                return
            }

            self.movieOutput.stopRecording()
        }
    }

    func cancelRecordingIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            if self.movieOutput.isRecording {
                self.didCancelRecording = true
                self.movieOutput.stopRecording()
            }
        }
    }

    // MARK: - Flip Camera

    func flipCamera() {
        guard isReady, !isRecording else {
            return
        }

        sessionQueue.async { [weak self] in
            guard
                let self,
                !self.movieOutput.isRecording,
                let oldInput = self.currentVideoInput
            else {
                return
            }

            let newPosition: AVCaptureDevice.Position =
                oldInput.device.position == .front
                    ? .back
                    : .front

            do {
                let device =
                    try self.preferredCamera(
                        position: newPosition
                    )

                let newInput =
                    try AVCaptureDeviceInput(
                        device: device
                    )

                self.session.beginConfiguration()
                self.session.removeInput(oldInput)

                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.currentVideoInput = newInput
                } else {
                    self.session.addInput(oldInput)
                }

                self.session.commitConfiguration()

                let isFront =
                    self.currentVideoInput?.device.position == .front

                if let connection =
                    self.movieOutput.connection(
                        with: .video
                    )
                {
                    self.configurePortraitRotation(
                        on: connection
                    )
                    self.configureMirroring(
                        on: connection,
                        mirrored: isFront
                    )
                }

                DispatchQueue.main.async {
                    self.isFrontCamera = isFront
                }

            } catch {
                DispatchQueue.main.async {
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    private func preferredCamera(
        position: AVCaptureDevice.Position
    ) throws -> AVCaptureDevice {
        let discovery =
            AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .builtInWideAngleCamera,
                    .builtInTrueDepthCamera
                ],
                mediaType: .video,
                position: position
            )

        if let device = discovery.devices.first {
            return device
        }

        throw RecorderError.cameraUnavailable
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()

        timer =
            Timer.scheduledTimer(
                withTimeInterval: 0.2,
                repeats: true
            ) { [weak self] _ in
                guard let self else {
                    return
                }

                let seconds =
                    CMTimeGetSeconds(
                        self.movieOutput.recordedDuration
                    )

                if seconds.isFinite {
                    self.elapsed = seconds
                }
            }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Shutdown

    func shutdown() {
        stopTimer()

        // Serializing shutdown with configuration is important.
        // If configureSessionGraph() is still running, this block waits
        // until commitConfiguration() has completed.
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            if self.movieOutput.isRecording {
                self.didCancelRecording = true
                self.movieOutput.stopRecording()
            }

            if self.session.isRunning {
                self.session.stopRunning()
            }

            DispatchQueue.main.async {
                self.isReady = false
                self.isPreparing = false
            }
        }
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        Task { @MainActor in
            self.isRecording = true
            self.errorText = nil
            self.startTimer()

            print(
                "✅ VIDEO NOTE: REAL RECORDING STARTED ->",
                fileURL.lastPathComponent
            )
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            self.stopTimer()
            self.isRecording = false

            if self.didCancelRecording {
                try? FileManager.default.removeItem(
                    at: outputFileURL
                )
                self.didCancelRecording = false
                return
            }

            if let error {
                print(
                    "❌ VIDEO NOTE: recording finished with error:",
                    error
                )

                let nsError = error as NSError
                let finishedSuccessfully =
                    nsError.userInfo[
                        AVErrorRecordingSuccessfullyFinishedKey
                    ] as? Bool ?? false

                if !finishedSuccessfully {
                    self.errorText =
                        error.localizedDescription
                    return
                }
            }

            guard FileManager.default.fileExists(
                atPath: outputFileURL.path
            ) else {
                self.errorText =
                    "Видео не сохранилось"
                return
            }

            self.onRecordingFinished?(
                outputFileURL
            )
        }
    }
}

private enum RecorderError: LocalizedError {
    case cameraUnavailable
    case cannotAddVideoInput
    case cannotAddMovieOutput

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Камера недоступна"
        case .cannotAddVideoInput:
            return "Не удалось подключить камеру"
        case .cannotAddMovieOutput:
            return "Не удалось запустить запись видео"
        }
    }
}

private struct VideoNoteRecorderNeonIcon: View {
    @AppStorage("gru.settings.appearance.neonGlow") private var neonGlow = true
    @AppStorage("gru.settings.accessibility.highContrast") private var highContrast = false

    let systemName: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 17
    var isActive: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .fill(GRUColors.card.opacity(0.94))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            GRUColors.accent.opacity(isActive && neonGlow ? 0.20 : 0.04),
                            GRUColors.card.opacity(0.18)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.54
                    )
                )

            Circle()
                .fill(GRUColors.accent.opacity(isActive ? 0.055 : 0.018))
                .padding(2)

            Circle()
                .stroke(
                    GRUColors.neonGradient,
                    lineWidth: highContrast ? 2.2 : (isActive && neonGlow ? 1.55 : 0.72)
                )
                .opacity(isActive ? 1 : (highContrast ? 0.55 : 0.24))

            Circle()
                .stroke(GRUColors.accent.opacity(isActive && neonGlow ? 0.20 : 0.04), lineWidth: 5)
                .blur(radius: 5)

            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(isActive ? GRUColors.accent : .secondary)
                .shadow(
                    color: GRUColors.accent.opacity(isActive && neonGlow ? 0.36 : 0),
                    radius: isActive && neonGlow ? 4 : 0
                )
        }
        .frame(width: size, height: size)
        .shadow(
            color: GRUColors.accent.opacity(isActive && neonGlow ? 0.20 : 0.02),
            radius: isActive && neonGlow ? 9 : 1
        )
        .shadow(
            color: GRUColors.accentSecondary.opacity(isActive && neonGlow ? 0.12 : 0),
            radius: isActive && neonGlow ? 15 : 0
        )
    }
}

private struct VideoNoteRecorderEnvelopeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: 0, y: h * 0.18))
        path.addLine(to: CGPoint(x: w, y: h * 0.18))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()

        path.move(to: CGPoint(x: 0, y: h * 0.18))
        path.addLine(to: CGPoint(x: w / 2, y: h * 0.60))
        path.addLine(to: CGPoint(x: w, y: h * 0.18))

        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w / 2, y: h * 0.55))
        path.addLine(to: CGPoint(x: w, y: h))

        return path
    }
}


private struct VideoNoteCameraPreview: UIViewRepresentable {

    let session: AVCaptureSession
    let isMirrored: Bool

    func makeUIView(
        context: Context
    ) -> VideoNoteCameraPreviewView {
        let view = VideoNoteCameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        applyMirroring(
            to: view.previewLayer
        )
        return view
    }

    func updateUIView(
        _ uiView: VideoNoteCameraPreviewView,
        context: Context
    ) {
        uiView.previewLayer.session = session
        applyMirroring(
            to: uiView.previewLayer
        )
    }

    private func applyMirroring(
        to previewLayer: AVCaptureVideoPreviewLayer
    ) {
        guard let connection =
            previewLayer.connection
        else {
            return
        }

        guard connection.isVideoMirroringSupported else {
            return
        }

        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = isMirrored
    }
}

private final class VideoNoteCameraPreviewView: UIView {

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
