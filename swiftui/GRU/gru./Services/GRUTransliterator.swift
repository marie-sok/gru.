import Foundation

enum GRUTransliterator {
    static func latin(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        let latin = text.applyingTransform(.toLatin, reverse: false) ?? text
        return latin.applyingTransform(.stripDiacritics, reverse: false) ?? latin
    }

    static func display(_ text: String, enabled: Bool) -> String {
        enabled ? latin(text) : text
    }
}
