import Foundation
import SwiftUI

enum GRUAppTheme: String, CaseIterable, Identifiable {
    case obsidian
    case ultraviolet
    case cyberMint
    case electricRose
    case solarPulse
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
        return GRUAppTheme(rawValue: rawValue ?? "") ?? .obsidian
    }

    var title: String {
        switch self {
        case .obsidian: return "Obsidian"
        case .ultraviolet: return "Ultraviolet"
        case .cyberMint: return "Cyber Mint"
        case .electricRose: return "Electric Rose"
        case .solarPulse: return "Solar Pulse"
        case .arcticSignal: return "Arctic Signal"
        case .acidLime: return "Acid Lime"
        case .midnightGold: return "Midnight Gold"
        case .ultravioletUnicorn: return "Ultraviolet Unicorn"
        case .powderPrincess: return "Powder Princess"
        case .forestWitch: return "Forest Witch"
        case .cyberMidnight: return "Cyber Midnight"
        case .blackMoonCat: return "Black Moon Cat"
        case .ironKnight: return "Iron Knight"
        case .bloodDragon: return "Blood Dragon"
        case .greenAcidMonster: return "Green Acid Monster"
        case .neonCatDemon: return "Neon Cat Demon"
        }
    }

    var subtitle: String {
        switch self {
        case .obsidian: return "Графит, орбиты и холодное свечение"
        case .ultraviolet: return "Фиолетовые волны и электрические искры"
        case .cyberMint: return "Мятная сеть и цифровые импульсы"
        case .electricRose: return "Розовый неон и сердечный ритм"
        case .solarPulse: return "Солнечные дуги и горячий сигнал"
        case .arcticSignal: return "Лёд, снег и северные орбиты"
        case .acidLime: return "Лаймовые капли и кислотный ток"
        case .midnightGold: return "Чёрное золото, короны и звёзды"
        case .ultravioletUnicorn: return "Магический ультрафиолет и звёздная пыль"
        case .powderPrincess: return "Пудровые короны, жемчуг и мягкий блеск"
        case .forestWitch: return "Листья, луна и лесные руны"
        case .cyberMidnight: return "Ночная сетка, код и холодный неон"
        case .blackMoonCat: return "Чёрный кот, луна и следы лап"
        case .ironKnight: return "Сталь, щиты и холодные клинки"
        case .bloodDragon: return "Кровавое пламя, когти и драконьи дуги"
        case .greenAcidMonster: return "Ядовитые глаза, слизь и рейв-кислота"
        case .neonCatDemon: return "Демонический кот, рога, руны и фиолетовый огонь"
        }
    }

    var icon: String {
        switch self {
        case .obsidian: return "moon.stars.fill"
        case .ultraviolet: return "sparkles"
        case .cyberMint: return "bolt.fill"
        case .electricRose: return "heart.fill"
        case .solarPulse: return "sun.max.fill"
        case .arcticSignal: return "snowflake"
        case .acidLime: return "drop.triangle.fill"
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
        case .obsidian: return Color(red: 0.47, green: 0.90, blue: 1.00)
        case .ultraviolet: return Color(red: 0.70, green: 0.49, blue: 1.00)
        case .cyberMint: return Color(red: 0.26, green: 1.00, blue: 0.72)
        case .electricRose: return Color(red: 1.00, green: 0.35, blue: 0.72)
        case .solarPulse: return Color(red: 1.00, green: 0.68, blue: 0.25)
        case .arcticSignal: return Color(red: 0.35, green: 0.78, blue: 1.00)
        case .acidLime: return Color(red: 0.70, green: 1.00, blue: 0.18)
        case .midnightGold: return Color(red: 1.00, green: 0.78, blue: 0.28)
        case .ultravioletUnicorn: return Color(red: 0.88, green: 0.56, blue: 1.00)
        case .powderPrincess: return Color(red: 1.00, green: 0.74, blue: 0.84)
        case .forestWitch: return Color(red: 0.40, green: 0.86, blue: 0.56)
        case .cyberMidnight: return Color(red: 0.19, green: 0.83, blue: 1.00)
        case .blackMoonCat: return Color(red: 0.88, green: 0.80, blue: 1.00)
        case .ironKnight: return Color(red: 0.76, green: 0.82, blue: 0.91)
        case .bloodDragon: return Color(red: 1.00, green: 0.24, blue: 0.25)
        case .greenAcidMonster: return Color(red: 0.48, green: 1.00, blue: 0.16)
        case .neonCatDemon: return Color(red: 0.96, green: 0.20, blue: 1.00)
        }
    }

    var secondaryAccent: Color {
        switch self {
        case .obsidian: return Color(red: 0.47, green: 0.51, blue: 1.00)
        case .ultraviolet: return Color(red: 0.20, green: 0.88, blue: 1.00)
        case .cyberMint: return Color(red: 0.18, green: 0.67, blue: 1.00)
        case .electricRose: return Color(red: 0.58, green: 0.39, blue: 1.00)
        case .solarPulse: return Color(red: 1.00, green: 0.30, blue: 0.34)
        case .arcticSignal: return Color(red: 0.55, green: 0.46, blue: 1.00)
        case .acidLime: return Color(red: 0.08, green: 0.90, blue: 0.70)
        case .midnightGold: return Color(red: 1.00, green: 0.42, blue: 0.15)
        case .ultravioletUnicorn: return Color(red: 0.39, green: 0.90, blue: 1.00)
        case .powderPrincess: return Color(red: 0.80, green: 0.60, blue: 1.00)
        case .forestWitch: return Color(red: 0.70, green: 0.95, blue: 0.36)
        case .cyberMidnight: return Color(red: 0.52, green: 0.42, blue: 1.00)
        case .blackMoonCat: return Color(red: 1.00, green: 0.86, blue: 0.42)
        case .ironKnight: return Color(red: 0.45, green: 0.58, blue: 0.74)
        case .bloodDragon: return Color(red: 1.00, green: 0.62, blue: 0.12)
        case .greenAcidMonster: return Color(red: 0.04, green: 0.88, blue: 0.62)
        case .neonCatDemon: return Color(red: 0.35, green: 0.12, blue: 1.00)
        }
    }

    var background: Color {
        switch self {
        case .obsidian: return Color(red: 0.018, green: 0.024, blue: 0.040)
        case .ultraviolet: return Color(red: 0.030, green: 0.018, blue: 0.060)
        case .cyberMint: return Color(red: 0.012, green: 0.038, blue: 0.040)
        case .electricRose: return Color(red: 0.050, green: 0.014, blue: 0.042)
        case .solarPulse: return Color(red: 0.054, green: 0.026, blue: 0.014)
        case .arcticSignal: return Color(red: 0.010, green: 0.030, blue: 0.060)
        case .acidLime: return Color(red: 0.018, green: 0.034, blue: 0.018)
        case .midnightGold: return Color(red: 0.030, green: 0.024, blue: 0.012)
        case .ultravioletUnicorn: return Color(red: 0.040, green: 0.020, blue: 0.062)
        case .powderPrincess: return Color(red: 0.084, green: 0.056, blue: 0.074)
        case .forestWitch: return Color(red: 0.020, green: 0.048, blue: 0.030)
        case .cyberMidnight: return Color(red: 0.008, green: 0.016, blue: 0.038)
        case .blackMoonCat: return Color(red: 0.012, green: 0.012, blue: 0.020)
        case .ironKnight: return Color(red: 0.020, green: 0.026, blue: 0.032)
        case .bloodDragon: return Color(red: 0.052, green: 0.010, blue: 0.014)
        case .greenAcidMonster: return Color(red: 0.010, green: 0.026, blue: 0.014)
        case .neonCatDemon: return Color(red: 0.022, green: 0.006, blue: 0.034)
        }
    }

    var card: Color {
        switch self {
        case .obsidian: return Color(red: 0.060, green: 0.076, blue: 0.110)
        case .ultraviolet: return Color(red: 0.090, green: 0.054, blue: 0.145)
        case .cyberMint: return Color(red: 0.040, green: 0.105, blue: 0.105)
        case .electricRose: return Color(red: 0.120, green: 0.045, blue: 0.100)
        case .solarPulse: return Color(red: 0.125, green: 0.072, blue: 0.038)
        case .arcticSignal: return Color(red: 0.040, green: 0.080, blue: 0.140)
        case .acidLime: return Color(red: 0.060, green: 0.105, blue: 0.055)
        case .midnightGold: return Color(red: 0.100, green: 0.080, blue: 0.040)
        case .ultravioletUnicorn: return Color(red: 0.114, green: 0.060, blue: 0.164)
        case .powderPrincess: return Color(red: 0.160, green: 0.090, blue: 0.122)
        case .forestWitch: return Color(red: 0.060, green: 0.096, blue: 0.064)
        case .cyberMidnight: return Color(red: 0.030, green: 0.050, blue: 0.092)
        case .blackMoonCat: return Color(red: 0.055, green: 0.055, blue: 0.074)
        case .ironKnight: return Color(red: 0.090, green: 0.102, blue: 0.118)
        case .bloodDragon: return Color(red: 0.132, green: 0.040, blue: 0.045)
        case .greenAcidMonster: return Color(red: 0.050, green: 0.090, blue: 0.034)
        case .neonCatDemon: return Color(red: 0.104, green: 0.026, blue: 0.132)
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
        case .obsidian: return ["moon.fill", "sparkle", "circle.fill"]
        case .ultraviolet: return ["sparkles", "wave.3.right", "bolt.fill"]
        case .cyberMint: return ["cpu.fill", "bolt.fill", "point.3.connected.trianglepath.dotted"]
        case .electricRose: return ["heart.fill", "bolt.heart.fill", "sparkles"]
        case .solarPulse: return ["sun.max.fill", "flame.fill", "circle.dotted"]
        case .arcticSignal: return ["snowflake", "diamond.fill", "wind"]
        case .acidLime: return ["drop.fill", "bolt.fill", "atom"]
        case .midnightGold: return ["crown.fill", "star.fill", "moon.stars.fill"]
        case .ultravioletUnicorn: return ["wand.and.stars", "sparkles", "star.fill"]
        case .powderPrincess: return ["crown.fill", "heart.fill", "sparkle"]
        case .forestWitch: return ["leaf.fill", "moon.fill", "aqi.medium"]
        case .cyberMidnight: return ["cpu.fill", "terminal.fill", "circle.grid.cross.fill"]
        case .blackMoonCat: return ["cat.fill", "moon.fill", "pawprint.fill"]
        case .ironKnight: return ["shield.fill", "bolt.shield.fill", "diamond.fill"]
        case .bloodDragon: return ["flame.fill", "bolt.fill", "triangle.fill"]
        case .greenAcidMonster: return ["eye.fill", "drop.fill", "burst.fill"]
        case .neonCatDemon: return ["cat.fill", "flame.fill", "eye.fill"]
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
    private var themeRawValue = GRUAppTheme.obsidian.rawValue

    private var theme: GRUAppTheme {
        GRUAppTheme(rawValue: themeRawValue) ?? .obsidian
    }

    var body: some View {
        GRUSignatureWallpaper(theme: theme, intensity: 1.0)
            .ignoresSafeArea()
    }
}

struct GRUSignatureWallpaper: View {
    let theme: GRUAppTheme
    var intensity: Double = 1.0

    @AppStorage("gru.settings.appearance.dynamicBackground")
    private var dynamicBackground = true

    @AppStorage("gru.settings.accessibility.reduceMotion")
    private var reduceMotion = false

    @ViewBuilder
    var body: some View {
        if dynamicBackground && !reduceMotion {
            TimelineView(.animation) { context in
                GeometryReader { proxy in
                    wallpaperContent(
                        size: proxy.size,
                        phase: context.date.timeIntervalSinceReferenceDate * 0.28
                    )
                }
            }
        } else {
            GeometryReader { proxy in
                wallpaperContent(size: proxy.size, phase: 0)
            }
        }
    }

    private func wallpaperContent(size: CGSize, phase: Double) -> some View {
        ZStack {
            theme.background

            LinearGradient(
                colors: [
                    theme.background,
                    theme.card.opacity(0.84),
                    theme.accent.opacity(0.10 * intensity),
                    theme.secondaryAccent.opacity(0.08 * intensity),
                    theme.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            signatureGlow(size: size, phase: phase)
            signatureSymbols(size: size, phase: phase)
            signatureHero(size: size, phase: phase)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.10), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipped()
    }

    private func signatureGlow(size: CGSize, phase: Double) -> some View {
        ZStack {
            Circle()
                .fill(theme.accent.opacity(0.14 * intensity))
                .frame(width: size.width * 0.88, height: size.width * 0.88)
                .blur(radius: 74)
                .offset(
                    x: size.width * 0.28 + CGFloat(sin(phase)) * 24,
                    y: -size.height * 0.30 + CGFloat(cos(phase * 0.8)) * 18
                )

            Circle()
                .fill(theme.secondaryAccent.opacity(0.11 * intensity))
                .frame(width: size.width * 0.72, height: size.width * 0.72)
                .blur(radius: 78)
                .offset(
                    x: -size.width * 0.30 + CGFloat(cos(phase * 0.75)) * 20,
                    y: size.height * 0.34 + CGFloat(sin(phase * 0.9)) * 22
                )
        }
    }

    private func signatureSymbols(size: CGSize, phase: Double) -> some View {
        ZStack {
            ForEach(0..<18, id: \.self) { index in
                let symbols = theme.wallpaperSymbols
                let symbol = symbols[index % symbols.count]
                let xSeed = CGFloat((index * 47 + 11) % 97) / 96
                let ySeed = CGFloat((index * 71 + 19) % 101) / 100
                let driftX = CGFloat(sin(phase + Double(index) * 0.73)) * 12
                let driftY = CGFloat(cos(phase * 0.82 + Double(index) * 0.51)) * 15

                Image(systemName: symbol)
                    .font(.system(size: CGFloat(9 + (index % 5) * 3), weight: .bold))
                    .foregroundStyle(
                        index.isMultiple(of: 2)
                            ? theme.accent.opacity(0.055 * intensity)
                            : theme.secondaryAccent.opacity(0.045 * intensity)
                    )
                    .rotationEffect(.degrees(Double((index * 29) % 70) - 35 + sin(phase) * 5))
                    .position(
                        x: max(18, min(size.width - 18, xSeed * size.width + driftX)),
                        y: max(18, min(size.height - 18, ySeed * size.height + driftY))
                    )
            }
        }
    }

    @ViewBuilder
    private func signatureHero(size: CGSize, phase: Double) -> some View {
        switch theme {
        case .blackMoonCat:
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.055 * intensity))
                    .frame(width: 190, height: 190)
                    .overlay { Circle().stroke(theme.secondaryAccent.opacity(0.12), lineWidth: 1) }
                Image(systemName: "cat.fill")
                    .font(.system(size: 76, weight: .black))
                    .foregroundStyle(theme.accent.opacity(0.075 * intensity))
                    .offset(y: 28)
            }
            .offset(x: size.width * 0.22, y: -size.height * 0.18 + CGFloat(sin(phase)) * 7)

        case .forestWitch:
            ZStack {
                Circle().stroke(theme.accent.opacity(0.09 * intensity), lineWidth: 1.2).frame(width: 250, height: 250)
                Image(systemName: "moon.fill").font(.system(size: 62)).foregroundStyle(theme.secondaryAccent.opacity(0.08 * intensity))
                Image(systemName: "leaf.fill").font(.system(size: 50)).foregroundStyle(theme.accent.opacity(0.10 * intensity)).offset(x: 82, y: 70)
            }
            .rotationEffect(.degrees(sin(phase * 0.6) * 4))
            .offset(x: -size.width * 0.20, y: -size.height * 0.19)

        case .bloodDragon:
            ZStack {
                Circle().trim(from: 0.08, to: 0.88).stroke(theme.accent.opacity(0.11 * intensity), style: StrokeStyle(lineWidth: 8, lineCap: .round)).frame(width: 250, height: 250)
                Circle().trim(from: 0.45, to: 0.98).stroke(theme.secondaryAccent.opacity(0.08 * intensity), style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 190, height: 190)
                Image(systemName: "flame.fill").font(.system(size: 58)).foregroundStyle(theme.accent.opacity(0.10 * intensity))
            }
            .rotationEffect(.degrees(phase * 3.0))
            .offset(x: size.width * 0.18, y: -size.height * 0.18)

        case .cyberMidnight:
            Canvas { context, canvasSize in
                let step: CGFloat = 34
                var path = Path()
                stride(from: CGFloat.zero, through: canvasSize.width, by: step).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                }
                stride(from: CGFloat.zero, through: canvasSize.height, by: step).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                }
                context.stroke(path, with: .color(theme.accent.opacity(0.035 * intensity)), lineWidth: 0.6)
            }
            .offset(y: CGFloat(sin(phase)) * 5)

        case .neonCatDemon:
            ZStack {
                Circle()
                    .fill(theme.secondaryAccent.opacity(0.055 * intensity))
                    .frame(width: 230, height: 230)
                    .blur(radius: 2)
                Image(systemName: "flame.fill")
                    .font(.system(size: 155, weight: .black))
                    .foregroundStyle(theme.secondaryAccent.opacity(0.05 * intensity))
                    .scaleEffect(1 + CGFloat(sin(phase * 1.8)) * 0.035)
                Image(systemName: "cat.fill")
                    .font(.system(size: 92, weight: .black))
                    .foregroundStyle(theme.accent.opacity(0.11 * intensity))
                    .shadow(color: theme.accent.opacity(0.15), radius: 16)
                HStack(spacing: 34) {
                    Capsule().fill(theme.accent.opacity(0.21 * intensity)).frame(width: 18, height: 6)
                    Capsule().fill(theme.accent.opacity(0.21 * intensity)).frame(width: 18, height: 6)
                }
                .offset(y: -4)
                .blur(radius: 1)
            }
            .offset(x: size.width * 0.17, y: -size.height * 0.18 + CGFloat(sin(phase * 1.2)) * 8)

        case .greenAcidMonster:
            ZStack {
                Circle().stroke(theme.accent.opacity(0.09 * intensity), lineWidth: 7).frame(width: 210, height: 210)
                HStack(spacing: 28) {
                    Image(systemName: "eye.fill")
                    Image(systemName: "eye.fill")
                }
                .font(.system(size: 48, weight: .black))
                .foregroundStyle(theme.accent.opacity(0.11 * intensity))
            }
            .scaleEffect(1 + CGFloat(sin(phase * 1.3)) * 0.025)
            .offset(x: -size.width * 0.18, y: -size.height * 0.17)

        case .ultravioletUnicorn:
            ZStack {
                Circle().stroke(theme.accent.opacity(0.10 * intensity), lineWidth: 2).frame(width: 230, height: 230)
                Image(systemName: "wand.and.stars").font(.system(size: 82)).foregroundStyle(theme.accent.opacity(0.10 * intensity))
                Image(systemName: "sparkles").font(.system(size: 40)).foregroundStyle(theme.secondaryAccent.opacity(0.10 * intensity)).offset(x: 80, y: -70)
            }
            .rotationEffect(.degrees(sin(phase * 0.5) * 5))
            .offset(x: size.width * 0.17, y: -size.height * 0.18)

        case .powderPrincess:
            ZStack {
                Image(systemName: "crown.fill").font(.system(size: 104)).foregroundStyle(theme.accent.opacity(0.09 * intensity))
                Circle().stroke(theme.secondaryAccent.opacity(0.07 * intensity), lineWidth: 1).frame(width: 210, height: 210)
                Circle().fill(Color.white.opacity(0.05 * intensity)).frame(width: 10, height: 10).offset(x: 84, y: -72)
            }
            .offset(x: -size.width * 0.17, y: -size.height * 0.18 + CGFloat(cos(phase)) * 5)

        case .ironKnight:
            ZStack {
                Image(systemName: "shield.fill").font(.system(size: 120)).foregroundStyle(theme.accent.opacity(0.07 * intensity))
                Image(systemName: "bolt.shield.fill").font(.system(size: 58)).foregroundStyle(theme.secondaryAccent.opacity(0.08 * intensity))
            }
            .offset(x: size.width * 0.20, y: -size.height * 0.16)

        default:
            ZStack {
                Circle().stroke(theme.accent.opacity(0.07 * intensity), lineWidth: 1).frame(width: 220, height: 220)
                Image(systemName: theme.icon).font(.system(size: 70, weight: .bold)).foregroundStyle(theme.accent.opacity(0.08 * intensity))
            }
            .rotationEffect(.degrees(sin(phase * 0.45) * 4))
            .offset(x: size.width * 0.20, y: -size.height * 0.18)
        }
    }
}
