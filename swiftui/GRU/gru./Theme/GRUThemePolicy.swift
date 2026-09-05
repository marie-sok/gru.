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

    static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        let raw = defaults.string(forKey: GRUTheme.selectionKey)

        guard
            let raw,
            let selected = GRUAppTheme(rawValue: raw),
            allowed.contains(selected)
        else {
            defaults.set(
                GRUAppTheme.blackMoonCat.rawValue,
                forKey: GRUTheme.selectionKey
            )
            return
        }
    }
}
