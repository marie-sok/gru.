import NaturalLanguage
import SwiftUI

#if canImport(Translation)
import Translation
#endif

enum GRUTranslationLanguage: String, Equatable {
    case russian = "ru"
    case english = "en"

    var badge: String {
        switch self {
        case .russian: return "RU"
        case .english: return "EN"
        }
    }

    var opposite: GRUTranslationLanguage {
        switch self {
        case .russian: return .english
        case .english: return .russian
        }
    }

    var localeLanguage: Locale.Language {
        Locale.Language(identifier: rawValue)
    }

    static func detect(in text: String) -> GRUTranslationLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        switch recognizer.dominantLanguage {
        case .russian:
            return .russian
        case .english:
            return .english
        default:
            let containsCyrillic = text.unicodeScalars.contains { scalar in
                (0x0400...0x04FF).contains(Int(scalar.value))
            }
            return containsCyrillic ? .russian : .english
        }
    }
}

struct GRUInlineTranslation: View {
    let text: String
    var sourceHint: GRUTranslationLanguage? = nil
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            if #available(iOS 18.0, *) {
                #if canImport(Translation)
                GRUTranslationRuntimeView(
                    text: text,
                    sourceHint: sourceHint,
                    isPresented: $isPresented
                )
                #else
                unavailableView
                #endif
            } else {
                unavailableView
            }
        }
    }

    private var unavailableView: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "character.book.closed")
                .foregroundStyle(GRUColors.accent)

            Text(
                GRUAppLanguage.selected == .english
                ? "Inline RU ↔ EN translation requires iOS 18 or later."
                : "Перевод RU ↔ EN прямо в чате доступен на iOS 18 и новее."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
            }
            .buttonStyle(.plain)
        }
        .padding(9)
        .background(
            GRUColors.card.opacity(0.88),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

#if canImport(Translation)
@available(iOS 18.0, *)
private struct GRUTranslationRuntimeView: View {
    let text: String
    let sourceHint: GRUTranslationLanguage?
    @Binding var isPresented: Bool

    @State private var configuration: TranslationSession.Configuration?
    @State private var translatedText: String?
    @State private var translationError: String?
    @State private var isTranslating = false

    private var sourceLanguage: GRUTranslationLanguage {
        sourceHint ?? GRUTranslationLanguage.detect(in: text)
    }

    private var targetLanguage: GRUTranslationLanguage {
        sourceLanguage.opposite
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "character.book.closed.fill")
                    .foregroundStyle(GRUColors.accent)

                Text("\(sourceLanguage.badge) → \(targetLanguage.badge)")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(GRUColors.accent)

                Spacer(minLength: 6)

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isTranslating {
                HStack(spacing: 7) {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(GRUColors.accent)

                    Text(
                        GRUAppLanguage.selected == .english
                        ? "Translating…"
                        : "Перевожу…"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else if let translatedText {
                Text(translatedText)
                    .font(.system(size: 14.5, weight: .medium, design: .rounded))
                    .foregroundStyle(GRUColors.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } else if let translationError {
                Text(translationError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(9)
        .background(
            GRUColors.card.opacity(0.90),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(GRUColors.accent.opacity(0.18), lineWidth: 0.8)
        }
        .task(id: text) {
            guard configuration == nil else { return }
            configuration = TranslationSession.Configuration(
                source: sourceLanguage.localeLanguage,
                target: targetLanguage.localeLanguage
            )
        }
        .translationTask(configuration) { session in
            guard isPresented else { return }

            await MainActor.run {
                isTranslating = true
                translationError = nil
            }

            do {
                try await session.prepareTranslation()
                let response = try await session.translate(text)

                await MainActor.run {
                    translatedText = response.targetText
                    translationError = nil
                    isTranslating = false
                }
            } catch {
                await MainActor.run {
                    translatedText = nil
                    isTranslating = false
                    translationError =
                        GRUAppLanguage.selected == .english
                        ? "Translation is unavailable right now. Check downloaded Translation languages in iPhone Settings."
                        : "Перевод сейчас недоступен. Проверь загруженные языки перевода в Настройках iPhone."
                }
            }
        }
    }
}
#endif
