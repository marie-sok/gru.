import Foundation

enum GRUThemePolicy {
    static let allowed: [GRUAppTheme] = [
        .blackMoonCat,
        .neonCatDemon,
        .bloodDragon,
        .forestWitch,
        .cyberMidnight,
        .ultravioletUnicorn,
        .powderPrincess,
        .greenAcidMonster,
        .ironKnight
    ]

    static func displayName(for theme: GRUAppTheme) -> String {
        switch theme {
        case .blackMoonCat: return "Black Moon Cat"
        case .neonCatDemon: return "Neon Demon Cat"
        case .bloodDragon: return "Blood Dragon"
        case .forestWitch: return "Forest Witch"
        case .cyberMidnight: return "Cyber Midnight"
        case .ultravioletUnicorn: return "Ultraviolet Unicorn"
        case .powderPrincess: return "Powder Princess"
        case .greenAcidMonster: return "Green Acid Monster"
        case .ironKnight: return "Iron Knight"
        default: return "Black Moon Cat"
        }
    }

    static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        let raw = defaults.string(forKey: GRUTheme.selectionKey)

        if let raw,
           let selected = GRUAppTheme(rawValue: raw),
           allowed.contains(selected) {
            // current selection is already valid
        } else {
            defaults.set(
                GRUAppTheme.blackMoonCat.rawValue,
                forKey: GRUTheme.selectionKey
            )
        }

        // Old chat wallpapers (Neon Grid, Aurora, Midnight Paws, etc.) are no
        // longer part of the product theme set. Migrate them to the app theme
        // bridge (`obsidian`), which ChatView already renders through the
        // currently selected GRU signature theme.
        for (key, value) in defaults.dictionaryRepresentation() {
            guard key.hasPrefix("gru.chat.background."),
                  let rawValue = value as? String else {
                continue
            }

            if rawValue == "obsidian" {
                continue
            }

            if let theme = GRUAppTheme(rawValue: rawValue),
               allowed.contains(theme) {
                continue
            }

            defaults.set("obsidian", forKey: key)
        }
    }
}
