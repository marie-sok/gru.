import SwiftUI
import UIKit

private enum GRURecordMode: Equatable {
    case voice
    case videoNote

    var badgeIcon: String {
        switch self {
        case .voice: return "mic.fill"
        case .videoNote: return "video.fill"
        }
    }

    var title: String {
        switch self {
        case .voice: return "голосовое"
        case .videoNote: return "видео"
        }
    }
}

@MainActor
struct ChatInputBar: View {
    @Binding var text: String
    @Binding var sendTrigger: Bool

    var onSend: () -> Void
    var onAttachment: (AttachmentAction) -> Void
    var onAudioRecorded: (VoiceAudioRecording) -> Void = { _ in }

    // Telegram-style video-note lifecycle.
    var onVideoNoteStarted: () -> Void = {}
    var onVideoNoteReleased: () -> Void = {}
    var onVideoNoteCancelled: () -> Void = {}
    var onVideoNoteLocked: () -> Void = {}

    @State private var showMenu = false
    @State private var isSending = false
    @StateObject private var audioRecorder = VoiceAudioRecorderModel()

    @AppStorage("gru.settings.chats.sendByReturn") private var sendByReturn = false
    @AppStorage("gru.settings.accessibility.haptics") private var hapticsEnabled = true

    @State private var recordMode: GRURecordMode = .voice
    @State private var touchActive = false
    @State private var didStartRecordingGesture = false
    @State private var isInlineVoiceRecording = false
    @State private var cancelRecording = false
    @State private var recordingLocked = false
    @State private var holdTask: Task<Void, Never>?

    private let holdDelayNanoseconds: UInt64 = 180_000_000
    private let cancelThreshold: CGFloat = -72
    private let lockThreshold: CGFloat = -72

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var recordingUIVisible: Bool {
        touchActive ||
        didStartRecordingGesture ||
        isInlineVoiceRecording ||
        audioRecorder.isRecording ||
        audioRecorder.isPreparing ||
        recordingLocked
    }

    var body: some View {
        VStack(spacing: 0) {
            if !canSend, !recordingUIVisible, !showMenu {
                recordModeHint
                    .padding(.horizontal, 14)
                    .padding(.bottom, 5)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if showMenu, !recordingUIVisible {
                AttachmentMenu { action in
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                        showMenu = false
                    }
                    onAttachment(action)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                attachmentButton

                if recordingUIVisible {
                    recordingStrip
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    textField
                        .transition(.opacity)
                }

                if canSend, !recordingUIVisible {
                    sendButton
                        .transition(.scale.combined(with: .opacity))
                } else if recordingLocked, recordMode == .voice {
                    lockedVoiceSendButton
                        .transition(.scale.combined(with: .opacity))
                } else {
                    recordingButton
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial)
            .animation(.spring(response: 0.25, dampingFraction: 0.82), value: recordingUIVisible)
            .animation(.easeInOut(duration: 0.16), value: canSend)
        }
        .onDisappear {
            holdTask?.cancel()
            holdTask = nil
            touchActive = false

            if audioRecorder.isRecording || audioRecorder.isPreparing {
                audioRecorder.cancel()
            }
        }
    }

    // MARK: - Attachments

    private var attachmentButton: some View {
        Button {
            guard !recordingUIVisible else { return }

            withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                showMenu.toggle()
            }
        } label: {
            GRUNeonIcon(
                systemName: showMenu ? "xmark" : "plus",
                size: 40,
                iconSize: 18,
                isActive: !recordingUIVisible
            )
        }
        .buttonStyle(.plain)
        .disabled(recordingUIVisible)
    }

    // MARK: - Text

    private var textField: some View {
        TextField("Сообщение", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .submitLabel(sendByReturn ? .send : .return)
            .onSubmit {
                if sendByReturn && canSend {
                    sendMessage()
                }
            }
            .lineLimit(1...6)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(GRUColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    // MARK: - Recording UI

    private var recordingStrip: some View {
        HStack(spacing: 9) {
            Image(systemName: recordingStripIcon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(cancelRecording ? Color.red : GRUColors.accent)
                .frame(width: 20)

            if cancelRecording {
                Text("Отпусти — отменим")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
                    .lineLimit(1)

                Spacer(minLength: 0)
            } else if recordingLocked {
                Text("Запись зафиксирована")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(GRUColors.accent)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if recordMode == .voice {
                    Text(audioRecorder.elapsedText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } else if recordMode == .voice {
                VoiceWaveform(
                    samples: audioRecorder.waveform,
                    progress: 1,
                    barWidth: 2.5,
                    spacing: 1.8
                )
                .frame(minWidth: 62, maxWidth: .infinity)
                .frame(height: 28)

                Text(audioRecorder.elapsedText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text("Отпусти для отправки")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 42)
        .background(GRUColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(
                    cancelRecording ? Color.red.opacity(0.42) : GRUColors.accent.opacity(0.20),
                    lineWidth: 1
                )
        }
    }

    private var recordingStripIcon: String {
        if cancelRecording { return "xmark" }
        if recordingLocked { return "lock.fill" }
        return recordMode == .voice ? "waveform" : "video.fill"
    }

    // MARK: - Send

    private var sendButton: some View {
        Button {
            sendMessage()
        } label: {
            GRUNeonIcon(systemName: "envelope.fill", size: 42, iconSize: 20)
                .scaleEffect(isSending ? 0.82 : 1)
                .rotationEffect(.degrees(isSending ? -7 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Отправить")
    }

    private var lockedVoiceSendButton: some View {
        Button {
            finishLockedVoiceRecording()
        } label: {
            GRUNeonIcon(systemName: "paperplane.fill", size: 42, iconSize: 18)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Отправить голосовое")
    }

    private var recordModeHint: some View {
        HStack(spacing: 8) {
            Image(systemName: recordMode.badgeIcon)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(GRUColors.accent)

            Text("двойной тап — режим")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Circle()
                .fill(Color.secondary.opacity(0.38))
                .frame(width: 3, height: 3)

            Text("удержание — запись")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 27)
        .background(GRUColors.card.opacity(0.72), in: Capsule())
        .overlay {
            Capsule().stroke(GRUColors.accent.opacity(0.13), lineWidth: 1)
        }
    }

    // MARK: - Telegram-style record button

    private var recordingButton: some View {
        GRUNeonIcon(
            systemName: "pawprint.fill",
            size: 42,
            iconSize: didStartRecordingGesture ? 20 : 18,
            isActive: !cancelRecording
        )
        .overlay {
            recordingButtonOutline
        }
        .overlay(alignment: .bottomTrailing) {
            ZStack {
                Circle().fill(GRUColors.card)
                Circle().stroke(GRUColors.accent, lineWidth: 1)

                Image(systemName: recordMode.badgeIcon)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(GRUColors.accent)
            }
            .frame(width: 17, height: 17)
            .shadow(color: GRUColors.accent.opacity(0.62), radius: 5)
        }
        .overlay {
            if cancelRecording {
                Circle()
                    .stroke(Color.red.opacity(0.72), lineWidth: 1.5)
                    .shadow(color: Color.red.opacity(0.32), radius: 7)
            }
        }
        .foregroundStyle(cancelRecording ? Color.red : GRUColors.accent)
        .scaleEffect(touchActive ? 1.10 : 1)
        .contentShape(Circle())
        .gesture(recordGesture)
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    guard !canSend,
                          !audioRecorder.isRecording,
                          !audioRecorder.isPreparing,
                          !recordingLocked else { return }
                    toggleRecordMode()
                }
        )
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: touchActive)
        .animation(.easeInOut(duration: 0.12), value: cancelRecording)
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: recordMode)
        .accessibilityLabel(
            "Двойной тап переключает режим записи. Удерживай для записи. Свайп влево отменяет, вверх фиксирует."
        )
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var recordingButtonOutline: some View {
        if cancelRecording {
            CatVideoNoteShape()
                .stroke(Color.red.opacity(0.72), lineWidth: 1.45)
                .shadow(color: Color.red.opacity(0.36), radius: 6)
        } else {
            CatVideoNoteShape()
                .stroke(GRUColors.neonGradient, lineWidth: 1.45)
                .shadow(color: GRUColors.accent.opacity(0.34), radius: 6)
        }
    }

    private var recordGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if !touchActive {
                    beginRecordTouch()
                }

                guard didStartRecordingGesture else { return }
                updateRecordDrag(value.translation)
            }
            .onEnded { value in
                holdTask?.cancel()
                holdTask = nil

                guard didStartRecordingGesture else {
                    touchActive = false
                    cancelRecording = false
                    recordingLocked = false
                    return
                }

                updateRecordDrag(value.translation)
                finishRecordGesture()
            }
    }

    private func beginRecordTouch() {
        guard !canSend, !touchActive else { return }

        withAnimation(.easeOut(duration: 0.12)) {
            showMenu = false
        }

        touchActive = true
        didStartRecordingGesture = false
        cancelRecording = false
        recordingLocked = false

        holdTask?.cancel()
        holdTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: holdDelayNanoseconds)

            guard !Task.isCancelled, touchActive, !canSend else { return }
            beginSelectedRecordingAfterHold()
        }
    }

    private func beginSelectedRecordingAfterHold() {
        guard touchActive, !didStartRecordingGesture, !canSend else { return }

        didStartRecordingGesture = true

        if hapticsEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }

        switch recordMode {
        case .voice:
            Task { @MainActor in
                let started = await audioRecorder.startRecordingForHold()

                guard started else {
                    resetGestureState()
                    return
                }

                guard touchActive || recordingLocked else {
                    audioRecorder.cancel()
                    resetGestureState()
                    return
                }

                isInlineVoiceRecording = true
            }

        case .videoNote:
            onVideoNoteStarted()
        }
    }

    private func updateRecordDrag(_ translation: CGSize) {
        guard didStartRecordingGesture else { return }

        let horizontalCancel = translation.width <= cancelThreshold
        let verticalLock =
            translation.height <= lockThreshold &&
            abs(translation.height) > abs(translation.width)

        if horizontalCancel {
            if !cancelRecording {
                if hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            }

            cancelRecording = true
            recordingLocked = false
            return
        }

        cancelRecording = false

        if verticalLock, !recordingLocked {
            recordingLocked = true
            if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }

            if recordMode == .videoNote {
                onVideoNoteLocked()
            }
        }
    }

    private func finishRecordGesture() {
        touchActive = false

        if cancelRecording {
            cancelSelectedRecording()
            resetGestureState()
            return
        }

        if recordingLocked {
            // Voice continues inline. Video recorder remains open and
            // provides its own send/cancel controls.
            didStartRecordingGesture = false

            if recordMode == .videoNote {
                resetGestureState(keepLock: false)
            }
            return
        }

        switch recordMode {
        case .voice:
            finishVoiceRecordingAndSend()

        case .videoNote:
            onVideoNoteReleased()
            resetGestureState()
        }
    }

    private func cancelSelectedRecording() {
        switch recordMode {
        case .voice:
            audioRecorder.cancel()
            if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.warning) }

        case .videoNote:
            onVideoNoteCancelled()
            if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        }
    }

    private func finishVoiceRecordingAndSend() {
        if audioRecorder.isPreparing,
           !isInlineVoiceRecording,
           !audioRecorder.isRecording {
            audioRecorder.cancel()
            resetGestureState()
            return
        }

        guard isInlineVoiceRecording || audioRecorder.isRecording else {
            resetGestureState()
            return
        }

        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
        }

        guard let recording = audioRecorder.recording else {
            audioRecorder.shutdown()
            resetGestureState()
            return
        }

        if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        onAudioRecorded(recording)
        audioRecorder.shutdown()
        resetGestureState()
    }

    private func finishLockedVoiceRecording() {
        guard recordingLocked, recordMode == .voice else { return }
        recordingLocked = false
        finishVoiceRecordingAndSend()
    }

    private func resetGestureState(keepLock: Bool = false) {
        holdTask?.cancel()
        holdTask = nil
        touchActive = false
        didStartRecordingGesture = false
        isInlineVoiceRecording = keepLock && recordMode == .voice
        cancelRecording = false

        if !keepLock {
            recordingLocked = false
            isInlineVoiceRecording = false
        }
    }

    private func toggleRecordMode() {
        guard !canSend,
              !audioRecorder.isRecording,
              !audioRecorder.isPreparing,
              !recordingLocked
        else {
            return
        }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
            recordMode = recordMode == .voice ? .videoNote : .voice
        }

        if hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() }
    }

    // MARK: - Text send

    private func sendMessage() {
        guard canSend else { return }

        withAnimation(.spring(response: 0.20, dampingFraction: 0.60)) {
            isSending = true
        }

        onSend()
        sendTrigger.toggle()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isSending = false
            }
        }
    }
}

#Preview {
    ChatInputBar(
        text: .constant(""),
        sendTrigger: .constant(false),
        onSend: {},
        onAttachment: { _ in }
    )
}
