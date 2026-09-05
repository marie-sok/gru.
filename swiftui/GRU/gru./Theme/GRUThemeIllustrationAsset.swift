import Foundation

extension GRUAppTheme {
    var illustrationAssetName: String {
        switch self {
        case .blackMoonCat, .midnightGold:
            return "theme_black_moon_cat"
        case .neonCatDemon, .electricRose:
            return "theme_neon_demon_cat"
        case .bloodDragon:
            return "theme_blood_dragon"
        case .forestWitch:
            return "theme_forest_witch"
        case .cyberMidnight, .cyberMint, .arcticSignal:
            return "theme_cyber_midnight"
        case .ultravioletUnicorn, .ultraviolet:
            return "theme_ultraviolet_unicorn"
        case .powderPrincess:
            return "theme_powder_princess"
        case .greenAcidMonster, .acidLime:
            return "theme_green_acid_monster"
        case .ironKnight:
            return "theme_iron_knight"
        }
    }
}
