import Foundation

enum GRUAppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"

    static let storageKey = "gru.settings.language.v1"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .russian:
            return Locale(identifier: "ru_RU")
        case .english:
            return Locale(identifier: "en_US")
        }
    }

    var badge: String {
        switch self {
        case .russian: return "RU"
        case .english: return "EN"
        }
    }

    var nativeTitle: String {
        switch self {
        case .russian: return "Русский"
        case .english: return "English"
        }
    }

    static var defaultLanguage: GRUAppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferred.hasPrefix("en") ? .english : .russian
    }

    static var selected: GRUAppLanguage {
        guard
            let raw = UserDefaults.standard.string(forKey: storageKey),
            let value = GRUAppLanguage(rawValue: raw)
        else {
            return defaultLanguage
        }
        return value
    }
}

enum GRUL10n {
    static var language: GRUAppLanguage {
        GRUAppLanguage.selected
    }

    static func text(_ key: String) -> String {
        guard
            let path = Bundle.main.path(
                forResource: language.rawValue,
                ofType: "lproj"
            ),
            let bundle = Bundle(path: path)
        else {
            return key
        }

        return bundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
    }

    static func format(
        _ key: String,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: text(key),
            locale: language.locale,
            arguments: arguments
        )
    }
}
