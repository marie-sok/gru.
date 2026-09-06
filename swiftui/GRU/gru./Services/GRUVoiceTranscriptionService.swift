import Foundation
import Speech

enum GRUVoiceTranscriptionError: LocalizedError {
    case permissionDenied
    case permissionRestricted
    case recognizerUnavailable
    case audioMissing
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Разреши распознавание речи для gru. в Настройках iPhone."
        case .permissionRestricted:
            return "Распознавание речи ограничено на этом устройстве."
        case .recognizerUnavailable:
            return "Распознавание речи сейчас недоступно. Попробуй ещё раз позже."
        case .audioMissing:
            return "Аудиофайл голосового сообщения не найден."
        case .emptyResult:
            return "Не удалось уверенно распознать речь в этом голосовом."
        }
    }
}

@MainActor
final class GRUVoiceTranscriptionService {
    static let shared = GRUVoiceTranscriptionService()

    private init() {}

    func transcribe(audioURL: URL) async throws -> String {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw GRUVoiceTranscriptionError.audioMissing
        }

        let authorization = await ensureAuthorization()

        switch authorization {
        case .authorized:
            break
        case .denied:
            throw GRUVoiceTranscriptionError.permissionDenied
        case .restricted:
            throw GRUVoiceTranscriptionError.permissionRestricted
        case .notDetermined:
            throw GRUVoiceTranscriptionError.permissionDenied
        @unknown default:
            throw GRUVoiceTranscriptionError.permissionDenied
        }

        let recognizer =
            SFSpeechRecognizer(locale: Locale.current)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))

        guard let recognizer, recognizer.isAvailable else {
            throw GRUVoiceTranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        // Prefer private/local processing when Apple has an on-device model
        // for the current recognition locale. Fall back to Apple's normal
        // Speech service when the locale has no local model.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<String, Error>) in

            var didFinish = false
            var recognitionTask: SFSpeechRecognitionTask? = nil

            recognitionTask = recognizer.recognitionTask(with: request) {
                result,
                error in

                guard !didFinish else { return }

                if let error {
                    didFinish = true
                    recognitionTask?.cancel()
                    continuation.resume(throwing: error)
                    return
                }

                guard let result, result.isFinal else {
                    return
                }

                let resolvedText =
                    result.bestTranscription
                        .formattedString
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

                didFinish = true
                recognitionTask?.cancel()

                guard !resolvedText.isEmpty else {
                    continuation.resume(
                        throwing: GRUVoiceTranscriptionError.emptyResult
                    )
                    return
                }

                continuation.resume(returning: resolvedText)
            }
        }
    }

    private func ensureAuthorization() async
        -> SFSpeechRecognizerAuthorizationStatus
    {
        let current = SFSpeechRecognizer.authorizationStatus()

        guard current == .notDetermined else {
            return current
        }

        return await withCheckedContinuation {
            (continuation:
                CheckedContinuation<
                    SFSpeechRecognizerAuthorizationStatus,
                    Never
                >) in

            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
