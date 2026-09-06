import Foundation
import NaturalLanguage
import Speech

enum GRUVoiceLanguage: String, Codable, CaseIterable, Identifiable {
    case russian = "ru-RU"
    case english = "en-US"

    var id: String { rawValue }

    var badge: String {
        switch self {
        case .russian: return "RU"
        case .english: return "EN"
        }
    }

    var title: String {
        switch self {
        case .russian: return GRUL10n.text("Русский")
        case .english: return "English"
        }
    }

    var nlLanguage: NLLanguage {
        switch self {
        case .russian: return .russian
        case .english: return .english
        }
    }
}

struct GRUVoiceTranscript: Codable, Equatable {
    let text: String
    let language: GRUVoiceLanguage
    let confidence: Double
    let createdAt: Date
}

enum GRUVoiceTranscriptionError: LocalizedError {
    case permissionDenied
    case permissionRestricted
    case recognizerUnavailable(GRUVoiceLanguage)
    case audioMissing
    case emptyResult
    case bothLanguagesFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return GRUL10n.text(
                "Разреши распознавание речи для gru. в Настройках iPhone."
            )
        case .permissionRestricted:
            return GRUL10n.text(
                "Распознавание речи ограничено на этом устройстве."
            )
        case .recognizerUnavailable(let language):
            if GRUAppLanguage.selected == .english {
                return "\(language.badge) Speech Recognition is currently unavailable."
            }
            return "Распознавание \(language.badge) сейчас недоступно."
        case .audioMissing:
            return GRUL10n.text(
                "Аудиофайл голосового сообщения не найден."
            )
        case .emptyResult:
            return GRUL10n.text(
                "Не удалось уверенно распознать речь."
            )
        case .bothLanguagesFailed:
            return GRUL10n.text(
                "Не удалось распознать голосовое ни как русскую, ни как английскую речь."
            )
        }
    }
}

@MainActor
final class GRUVoiceTranscriptionService {
    static let shared = GRUVoiceTranscriptionService()

    private init() {}

    func transcribeAuto(
        audioURL: URL
    ) async throws -> GRUVoiceTranscript {
        try await ensureAudioAndAuthorization(audioURL)

        var candidates: [GRUVoiceTranscript] = []

        for language in preferredRecognitionOrder {
            do {
                let candidate = try await recognize(
                    audioURL: audioURL,
                    language: language
                )
                candidates.append(candidate)
            } catch {
                print(
                    "⚠️ VOICE TRANSCRIPTION \(language.badge):",
                    error.localizedDescription
                )
            }
        }

        guard !candidates.isEmpty else {
            throw GRUVoiceTranscriptionError.bothLanguagesFailed
        }

        let ranked = candidates.sorted {
            weightedScore($0) > weightedScore($1)
        }

        guard
            let best = ranked.first,
            !best.text.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        else {
            throw GRUVoiceTranscriptionError.emptyResult
        }

        return best
    }

    func transcribe(
        audioURL: URL,
        language: GRUVoiceLanguage
    ) async throws -> GRUVoiceTranscript {
        try await ensureAudioAndAuthorization(audioURL)

        return try await recognize(
            audioURL: audioURL,
            language: language
        )
    }

    private var preferredRecognitionOrder: [GRUVoiceLanguage] {
        GRUAppLanguage.selected == .english
            ? [.english, .russian]
            : [.russian, .english]
    }

    private func ensureAudioAndAuthorization(
        _ audioURL: URL
    ) async throws {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw GRUVoiceTranscriptionError.audioMissing
        }

        let authorization = await ensureAuthorization()

        switch authorization {
        case .authorized:
            return
        case .denied:
            throw GRUVoiceTranscriptionError.permissionDenied
        case .restricted:
            throw GRUVoiceTranscriptionError.permissionRestricted
        case .notDetermined:
            throw GRUVoiceTranscriptionError.permissionDenied
        @unknown default:
            throw GRUVoiceTranscriptionError.permissionDenied
        }
    }

    private func recognize(
        audioURL: URL,
        language: GRUVoiceLanguage
    ) async throws -> GRUVoiceTranscript {
        guard
            let recognizer = SFSpeechRecognizer(
                locale: Locale(identifier: language.rawValue)
            ),
            recognizer.isAvailable
        else {
            throw GRUVoiceTranscriptionError.recognizerUnavailable(language)
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let result = try await performRecognition(
            recognizer: recognizer,
            request: request
        )

        let text = result.bestTranscription.formattedString
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw GRUVoiceTranscriptionError.emptyResult
        }

        let segments = result.bestTranscription.segments

        let averageConfidence: Double
        if segments.isEmpty {
            averageConfidence = 0.35
        } else {
            let sum = segments.reduce(0.0) {
                $0 + Double($1.confidence)
            }
            averageConfidence = sum / Double(segments.count)
        }

        let languageFit = languageFitness(
            text: text,
            expected: language
        )

        let combined = min(
            1.0,
            max(
                0.0,
                averageConfidence * 0.68
                    + languageFit * 0.32
            )
        )

        return GRUVoiceTranscript(
            text: text,
            language: language,
            confidence: combined,
            createdAt: Date()
        )
    }

    private func performRecognition(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechURLRecognitionRequest
    ) async throws -> SFSpeechRecognitionResult {
        try await withCheckedThrowingContinuation {
            (
                continuation:
                    CheckedContinuation<SFSpeechRecognitionResult, Error>
            ) in

            var finished = false
            var task: SFSpeechRecognitionTask?

            task = recognizer.recognitionTask(with: request) {
                result,
                error in

                guard !finished else { return }

                if let error {
                    finished = true
                    task?.cancel()
                    continuation.resume(throwing: error)
                    return
                }

                guard let result, result.isFinal else {
                    return
                }

                finished = true
                task?.cancel()
                continuation.resume(returning: result)
            }
        }
    }

    private func weightedScore(
        _ transcript: GRUVoiceTranscript
    ) -> Double {
        let fit = languageFitness(
            text: transcript.text,
            expected: transcript.language
        )

        let lengthBonus = min(
            0.08,
            Double(transcript.text.count) / 400.0
        )

        return transcript.confidence
            + fit * 0.25
            + lengthBonus
    }

    private func languageFitness(
        text: String,
        expected: GRUVoiceLanguage
    ) -> Double {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        let dominant = recognizer.dominantLanguage

        let letters = text.unicodeScalars.filter {
            CharacterSet.letters.contains($0)
        }

        guard !letters.isEmpty else {
            return 0.25
        }

        let cyrillicCount = letters.filter {
            (0x0400...0x04FF).contains(Int($0.value))
        }.count

        let latinCount = letters.filter {
            (0x0041...0x005A).contains(Int($0.value))
                || (0x0061...0x007A).contains(Int($0.value))
        }.count

        let total = Double(letters.count)

        let scriptFit: Double
        switch expected {
        case .russian:
            scriptFit = Double(cyrillicCount) / total
        case .english:
            scriptFit = Double(latinCount) / total
        }

        let languageMatch =
            dominant == expected.nlLanguage ? 1.0 : 0.0

        return min(
            1.0,
            scriptFit * 0.72 + languageMatch * 0.28
        )
    }

    private func ensureAuthorization()
        async -> SFSpeechRecognizerAuthorizationStatus
    {
        let current = SFSpeechRecognizer.authorizationStatus()

        guard current == .notDetermined else {
            return current
        }

        return await withCheckedContinuation {
            (
                continuation:
                    CheckedContinuation<
                        SFSpeechRecognizerAuthorizationStatus,
                        Never
                    >
            ) in

            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
