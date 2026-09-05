import Foundation
import SwiftUI

enum GRUAppTheme: String, CaseIterable, Identifiable {
    // Legacy cases remain decodable for old installations. Only customThemes
    // are exposed in the current gru. theme picker.
    case ultraviolet
    case cyberMint
    case electricRose
    case arcticSignal
    case acidLime
    case midnightGold
    case ultravioletUnicorn
    case powderPrincess
    case forestWitch
    case cyberMidnight
    case blackMoonCat
    case ironKnight
    case bloodDragon
    case greenAcidMonster
    case neonCatDemon

    var id: String { rawValue }

    static var current: GRUAppTheme {
        let rawValue = UserDefaults.standard.string(forKey: GRUTheme.selectionKey)
        let selected = GRUAppTheme(rawValue: rawValue ?? "") ?? .blackMoonCat
        return customThemes.contains(selected) ? selected : .blackMoonCat
    }

    static let customThemes: [GRUAppTheme] = [
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

    var title: String {
        switch self {
        case .ultraviolet: return "Ultraviolet"
        case .cyberMint: return "Cyber Mint"
        case .electricRose: return "Electric Rose"
        case .arcticSignal: return "Arctic Signal"
        case .acidLime: return "Acid Lime"
        case .midnightGold: return "Midnight Gold"
        case .ultravioletUnicorn: return "Ultraviolet Caticorn"
        case .powderPrincess: return "Powder Princess"
        case .forestWitch: return "Forest Witch"
        case .cyberMidnight: return "Cyber Midnight"
        case .blackMoonCat: return "Black Moon Cat"
        case .ironKnight: return "Iron Knight"
        case .bloodDragon: return "Fold-Eared Cat Dragon"
        case .greenAcidMonster: return "Green Acid Monster"
        case .neonCatDemon: return "Neon Demon Cat"
        }
    }

    var subtitle: String {
        switch self {
        case .ultraviolet: return "Фиолетовые волны и электрические искры"
        case .cyberMint: return "Мятная сеть и цифровые импульсы"
        case .electricRose: return "Розовый неон и сердечный ритм"
        case .arcticSignal: return "Лёд, снег и северные орбиты"
        case .acidLime: return "Лаймовые капли и кислотный ток"
        case .midnightGold: return "Чёрное золото, короны и звёзды"
        case .ultravioletUnicorn: return "Котоединороги, облака и ультрафиолетовые радуги"
        case .powderPrincess: return "Пудровые пузыри, короны, звёзды и сердца"
        case .forestWitch: return "Болотная магия, dot-work руны, котлы и шляпы"
        case .cyberMidnight: return "Киберпанк-полночь, сетка, сканирование и коты"
        case .blackMoonCat: return "Коты, лунный цикл, лапки и ночное мерцание"
        case .ironKnight: return "Серебро, сталь, мечи, латы и рыцарские силуэты"
        case .bloodDragon: return "Вислоухие котодраконы, алый неон и искры"
        case .greenAcidMonster: return "Кислотное болото, монстры, глаза и слизь"
        case .neonCatDemon: return "Неоновые кошачьи мордочки, огоньки и злое хихиканье"
        }
    }

    var icon: String {
        switch self {
        case .ultraviolet: return "sparkles"
        case .cyberMint: return "bolt.fill"
        case .electricRose: return "heart.fill"
        case .arcticSignal: return "snowflake"
        case .acidLime: return "drop.fill"
        case .midnightGold: return "crown.fill"
        case .ultravioletUnicorn: return "wand.and.stars.inverse"
        case .powderPrincess: return "crown.fill"
        case .forestWitch: return "leaf.fill"
        case .cyberMidnight: return "cpu.fill"
        case .blackMoonCat: return "cat.fill"
        case .ironKnight: return "shield.fill"
        case .bloodDragon: return "flame.fill"
        case .greenAcidMonster: return "eye.fill"
        case .neonCatDemon: return "cat.fill"
        }
    }

    var accent: Color {
        switch self {
        case .ultraviolet: return Color(red: 0.70, green: 0.49, blue: 1.00)
        case .cyberMint: return Color(red: 0.26, green: 1.00, blue: 0.72)
        case .electricRose: return Color(red: 1.00, green: 0.35, blue: 0.72)
        case .arcticSignal: return Color(red: 0.35, green: 0.78, blue: 1.00)
        case .acidLime: return Color(red: 0.70, green: 1.00, blue: 0.18)
        case .midnightGold: return Color(red: 1.00, green: 0.78, blue: 0.28)
        case .ultravioletUnicorn: return Color(red: 0.78, green: 0.42, blue: 1.00)
        case .powderPrincess: return Color(red: 1.00, green: 0.70, blue: 0.82)
        case .forestWitch: return Color(red: 0.48, green: 0.72, blue: 0.22)
        case .cyberMidnight: return Color(red: 0.12, green: 0.75, blue: 1.00)
        case .blackMoonCat: return Color(red: 0.86, green: 0.86, blue: 0.94)
        case .ironKnight: return Color(red: 0.78, green: 0.84, blue: 0.92)
        case .bloodDragon: return Color(red: 1.00, green: 0.13, blue: 0.16)
        case .greenAcidMonster: return Color(red: 0.47, green: 1.00, blue: 0.08)
        case .neonCatDemon: return Color(red: 1.00, green: 0.12, blue: 0.76)
        }
    }

    var secondaryAccent: Color {
        switch self {
        case .ultraviolet: return Color(red: 0.20, green: 0.88, blue: 1.00)
        case .cyberMint: return Color(red: 0.18, green: 0.67, blue: 1.00)
        case .electricRose: return Color(red: 0.58, green: 0.39, blue: 1.00)
        case .arcticSignal: return Color(red: 0.55, green: 0.46, blue: 1.00)
        case .acidLime: return Color(red: 0.08, green: 0.90, blue: 0.70)
        case .midnightGold: return Color(red: 1.00, green: 0.42, blue: 0.15)
        case .ultravioletUnicorn: return Color(red: 0.45, green: 0.88, blue: 1.00)
        case .powderPrincess: return Color(red: 1.00, green: 0.90, blue: 0.94)
        case .forestWitch: return Color(red: 0.72, green: 0.88, blue: 0.35)
        case .cyberMidnight: return Color(red: 0.55, green: 0.25, blue: 1.00)
        case .blackMoonCat: return Color(red: 0.58, green: 0.62, blue: 0.74)
        case .ironKnight: return Color(red: 0.44, green: 0.56, blue: 0.72)
        case .bloodDragon: return Color(red: 0.78, green: 0.02, blue: 0.04)
        case .greenAcidMonster: return Color(red: 0.16, green: 0.56, blue: 0.06)
        case .neonCatDemon: return Color(red: 0.35, green: 0.12, blue: 1.00)
        }
    }

    var background: Color {
        switch self {
        case .ultraviolet: return Color(red: 0.030, green: 0.018, blue: 0.060)
        case .cyberMint: return Color(red: 0.012, green: 0.038, blue: 0.040)
        case .electricRose: return Color(red: 0.050, green: 0.014, blue: 0.042)
        case .arcticSignal: return Color(red: 0.010, green: 0.030, blue: 0.060)
        case .acidLime: return Color(red: 0.018, green: 0.034, blue: 0.018)
        case .midnightGold: return Color(red: 0.030, green: 0.024, blue: 0.012)
        case .ultravioletUnicorn: return Color(red: 0.055, green: 0.018, blue: 0.105)
        case .powderPrincess: return Color(red: 0.165, green: 0.095, blue: 0.125)
        case .forestWitch: return Color(red: 0.028, green: 0.060, blue: 0.025)
        case .cyberMidnight: return Color(red: 0.005, green: 0.012, blue: 0.040)
        case .blackMoonCat: return Color(red: 0.008, green: 0.009, blue: 0.016)
        case .ironKnight: return Color(red: 0.026, green: 0.032, blue: 0.042)
        case .bloodDragon: return Color(red: 0.070, green: 0.005, blue: 0.008)
        case .greenAcidMonster: return Color(red: 0.008, green: 0.040, blue: 0.006)
        case .neonCatDemon: return Color(red: 0.026, green: 0.004, blue: 0.034)
        }
    }

    var card: Color {
        switch self {
        case .ultraviolet: return Color(red: 0.090, green: 0.054, blue: 0.145)
        case .cyberMint: return Color(red: 0.040, green: 0.105, blue: 0.105)
        case .electricRose: return Color(red: 0.120, green: 0.045, blue: 0.100)
        case .arcticSignal: return Color(red: 0.040, green: 0.080, blue: 0.140)
        case .acidLime: return Color(red: 0.060, green: 0.105, blue: 0.055)
        case .midnightGold: return Color(red: 0.100, green: 0.080, blue: 0.040)
        case .ultravioletUnicorn: return Color(red: 0.120, green: 0.058, blue: 0.190)
        case .powderPrincess: return Color(red: 0.265, green: 0.150, blue: 0.195)
        case .forestWitch: return Color(red: 0.070, green: 0.110, blue: 0.055)
        case .cyberMidnight: return Color(red: 0.025, green: 0.050, blue: 0.110)
        case .blackMoonCat: return Color(red: 0.050, green: 0.052, blue: 0.072)
        case .ironKnight: return Color(red: 0.095, green: 0.108, blue: 0.125)
        case .bloodDragon: return Color(red: 0.145, green: 0.025, blue: 0.032)
        case .greenAcidMonster: return Color(red: 0.045, green: 0.105, blue: 0.025)
        case .neonCatDemon: return Color(red: 0.110, green: 0.018, blue: 0.130)
        }
    }

    var previewGradient: LinearGradient {
        LinearGradient(
            colors: [background, card, accent.opacity(0.44), secondaryAccent.opacity(0.54)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var wallpaperSymbols: [String] {
        switch self {
        case .ultraviolet: return ["sparkles", "wave.3.right", "bolt.fill"]
        case .cyberMint: return ["cpu.fill", "bolt.fill", "circle.hexagongrid.fill"]
        case .electricRose: return ["heart.fill", "bolt.heart.fill", "sparkles"]
        case .arcticSignal: return ["snowflake", "diamond.fill", "wind"]
        case .acidLime: return ["drop.fill", "bolt.fill", "atom"]
        case .midnightGold: return ["crown.fill", "star.fill", "moon.stars.fill"]
        case .ultravioletUnicorn: return ["wand.and.stars", "cloud.fill", "sparkles"]
        case .powderPrincess: return ["crown.fill", "heart.fill", "star.fill"]
        case .forestWitch: return ["leaf.fill", "moon.fill", "sparkles"]
        case .cyberMidnight: return ["cpu.fill", "terminal.fill", "circle.grid.cross.fill"]
        case .blackMoonCat: return ["cat.fill", "moon.fill", "pawprint.fill"]
        case .ironKnight: return ["shield.fill", "diamond.fill", "sparkles"]
        case .bloodDragon: return ["flame.fill", "sparkles", "circle.fill"]
        case .greenAcidMonster: return ["eye.fill", "drop.fill", "burst.fill"]
        case .neonCatDemon: return ["cat.fill", "flame.fill", "sparkles"]
        }
    }
}

enum GRUTheme {
    static let selectionKey = "gru.app.theme.v5"
    static let radius: CGFloat = 22
    static let tabBarHeight: CGFloat = 72
    static let spacing: CGFloat = 18
    static let animation: Animation = .spring(response: 0.38, dampingFraction: 0.82)
}

struct GRUAppBackdrop: View {
    @AppStorage(GRUTheme.selectionKey)
    private var themeRawValue = GRUAppTheme.blackMoonCat.rawValue

    private var theme: GRUAppTheme {
        let selected = GRUAppTheme(rawValue: themeRawValue) ?? .blackMoonCat
        return GRUAppTheme.customThemes.contains(selected) ? selected : .blackMoonCat
    }

    var body: some View {
        GRUSignatureWallpaper(theme: theme, intensity: 1.0)
            .ignoresSafeArea()
    }
}

struct GRUSignatureWallpaper: View {
    let theme: GRUAppTheme
    var intensity: Double = 1.0
    var animated = true

    @AppStorage("gru.settings.appearance.dynamicBackground")
    private var dynamicBackground = true

    @AppStorage("gru.settings.accessibility.reduceMotion")
    private var reduceMotion = false

    var body: some View {
        GRUIllustratedWallpaper(
            theme: theme,
            intensity: intensity,
            animated: animated && dynamicBackground && !reduceMotion
        )
    }
}
