import SwiftUI
import UIKit

/// Animated micro-art wallpaper used by every release theme.
/// The artwork remains small and distributed across the whole screen so chat text stays readable.
struct GRUIllustratedWallpaper: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var moves: Bool {
        animated && !systemReduceMotion && scenePhase == .active
    }

    private var frameInterval: TimeInterval {
        lowPower ? 1.0 / 15.0 : 1.0 / 30.0
    }

    private var atlasRow: Int {
        switch theme {
        case .blackMoonCat: return 0
        case .neonCatDemon: return 1
        case .ultravioletUnicorn: return 2
        case .bloodDragon: return 3
        case .forestWitch: return 4
        case .cyberMidnight: return 5
        case .powderPrincess: return 6
        case .greenAcidMonster: return 7
        case .ironKnight: return 8
        default: return 0
        }
    }

    private var motionSpeed: Double {
        switch theme {
        case .neonCatDemon: return 1.55
        case .cyberMidnight: return 1.45
        case .bloodDragon: return 1.22
        case .greenAcidMonster: return 1.10
        case .ultravioletUnicorn: return 0.82
        case .powderPrincess: return 0.78
        case .forestWitch: return 0.74
        case .ironKnight: return 0.66
        default: return 0.88
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval, paused: !moves)) { timeline in
            let time = moves ? timeline.date.timeIntervalSinceReferenceDate : 0
            let sweep = CGFloat(sin(time / 5.0))
            let lift = CGFloat(cos(time / 6.7))

            ZStack {
                theme.background

                LinearGradient(
                    colors: [
                        theme.background,
                        theme.card.opacity(0.74),
                        theme.accent.opacity(0.11),
                        theme.background
                    ],
                    startPoint: UnitPoint(x: 0.05 + sweep * 0.08, y: 0.02),
                    endPoint: UnitPoint(x: 0.95, y: 0.98 + lift * 0.05)
                )

                Canvas { context, size in
                    draw(in: &context, size: size, time: time)
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: Double) {
        guard size.width > 0, size.height > 0 else { return }

        let sprites = GRUDoodleAtlas.images(for: atlasRow).map {
            context.resolve(Image(uiImage: $0))
        }
        guard sprites.count == 3 else { return }

        let columns = max(1, Int(ceil(size.width / 74)))
        let rows = max(1, Int(ceil(size.height / 86)))
        let cellWidth = size.width / Double(columns)
        let cellHeight = size.height / Double(rows)
        let strength = min(max(intensity, 0), 1)

        for row in 0..<rows {
            for column in 0..<columns {
                let index = row * columns + column
                let seed = Double(index) * 2.399963
                let pose = (row + column * 2) % 3
                let basePeriod = 2.8 + Double(index % 7) * 0.34
                let rhythm = (time * motionSpeed) / basePeriod + seed
                let breath = sin(rhythm)
                let sway = cos(rhythm * 0.83 + seed * 0.3)
                let sparkle = 0.5 + 0.5 * sin(time * (1.25 + Double(index % 4) * 0.13) + seed)

                let glitch: Double = {
                    switch theme {
                    case .neonCatDemon, .cyberMidnight:
                        return sin(time * 9.0 + seed) * 1.7
                    case .bloodDragon:
                        return sin(time * 3.4 + seed) * 0.8
                    default:
                        return 0
                    }
                }()

                let baseX = (Double(column) + 0.5) * cellWidth + sin(seed) * 5
                let baseY = (Double(row) + 0.5) * cellHeight + cos(seed) * 5
                let driftX = sway * (6.0 + Double(index % 3) * 1.8) + glitch
                let driftY = breath * (5.0 + Double((index + 1) % 4))
                let x = baseX + driftX
                let y = baseY + driftY
                let side = min(cellWidth, cellHeight) * (0.53 + Double(index % 3) * 0.055)
                let pulse = 1.0 + breath * 0.045

                var glow = context
                glow.blendMode = .plusLighter
                glow.opacity = strength * (0.055 + sparkle * 0.045)
                glow.translateBy(x: x, y: y)
                glow.scaleBy(x: pulse * 1.12, y: pulse * 1.12)
                glow.draw(
                    sprites[pose],
                    in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
                )

                var art = context
                art.blendMode = .screen
                art.opacity = strength * (0.40 + sparkle * 0.11)
                art.translateBy(x: x, y: y)
                art.rotate(
                    by: .degrees(
                        sin(seed) * 10 +
                        breath * (pose == 1 ? 2.2 : 5.5) +
                        glitch * 0.6
                    )
                )
                art.scaleBy(
                    x: (index.isMultiple(of: 2) ? 1 : -1) * pulse,
                    y: pulse
                )
                art.draw(
                    sprites[pose],
                    in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
                )

                var decor = context
                decor.opacity = strength * (0.20 + sparkle * 0.13)
                decor.translateBy(
                    x: Double(column) * cellWidth + 8 + sin(rhythm + 2) * 4,
                    y: Double(row) * cellHeight + 10 + cos(rhythm) * 4
                )
                decor.rotate(by: .degrees(breath * 14))
                decor.stroke(
                    decoration(index: index),
                    with: .color(index.isMultiple(of: 2) ? theme.accent : theme.secondaryAccent),
                    style: StrokeStyle(lineWidth: 0.95, lineCap: .round, lineJoin: .round)
                )

                if index.isMultiple(of: 4) {
                    var particle = context
                    particle.blendMode = .plusLighter
                    particle.opacity = strength * (0.18 + sparkle * 0.32)
                    let particleX = x + sin(time * 0.8 + seed) * 12
                    let particleY = y - 16 - sparkle * 8
                    var particlePath = Path()
                    particlePath.addEllipse(
                        in: CGRect(
                            x: particleX - 1.4,
                            y: particleY - 1.4,
                            width: 2.8,
                            height: 2.8
                        )
                    )
                    particle.fill(
                        particlePath,
                        with: .color(index.isMultiple(of: 8) ? theme.secondaryAccent : theme.accent)
                    )
                }
            }
        }

        drawThemeSpecificMotion(in: &context, size: size, time: time, strength: strength)
    }

    private func drawThemeSpecificMotion(
        in context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        strength: Double
    ) {
        if theme == .cyberMidnight {
            var scan = context
            scan.opacity = strength * 0.10
            let y = (time * 34).truncatingRemainder(dividingBy: max(size.height, 1))
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            scan.stroke(path, with: .color(theme.accent), lineWidth: 0.8)
        }

        if theme == .bloodDragon || theme == .neonCatDemon {
            var ember = context
            ember.blendMode = .plusLighter
            for index in 0..<7 {
                let seed = Double(index) * 1.71
                let x = (size.width * (0.08 + Double(index) * 0.14)) + sin(time + seed) * 8
                let rawY = size.height - (time * (16 + Double(index % 3) * 5) + seed * 37)
                let y = rawY.truncatingRemainder(dividingBy: max(size.height, 1))
                let alpha = 0.08 + 0.08 * (0.5 + 0.5 * sin(time * 2 + seed))
                ember.opacity = strength * alpha
                var path = Path()
                path.addEllipse(in: CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4))
                ember.fill(path, with: .color(theme.accent))
            }
        }
    }

    /// Tiny hand-drawn marks between the main doodles.
    private func decoration(index: Int) -> Path {
        var path = Path()

        if index % 3 == 0 {
            path.addEllipse(in: CGRect(x: -2.5, y: 0, width: 5, height: 4))
            for point in [CGPoint(x: -4, y: -3), CGPoint(x: 0, y: -5), CGPoint(x: 4, y: -3)] {
                path.addEllipse(in: CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2))
            }
        } else if theme == .powderPrincess {
            path.move(to: CGPoint(x: 0, y: 4))
            path.addCurve(
                to: CGPoint(x: 0, y: -2),
                control1: CGPoint(x: -10, y: -1),
                control2: CGPoint(x: -4, y: -8)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: 4),
                control1: CGPoint(x: 4, y: -8),
                control2: CGPoint(x: 10, y: -1)
            )
        } else if theme == .greenAcidMonster {
            path.addEllipse(in: CGRect(x: -4, y: -4, width: 8, height: 8))
            path.addEllipse(in: CGRect(x: 5, y: -7, width: 3, height: 3))
        } else if theme == .forestWitch {
            path.move(to: CGPoint(x: -4, y: 5))
            path.addQuadCurve(to: CGPoint(x: 4, y: -5), control: CGPoint(x: -7, y: -5))
            path.addQuadCurve(to: CGPoint(x: -4, y: 5), control: CGPoint(x: 8, y: 5))
            path.addLine(to: CGPoint(x: 4, y: -5))
        } else if theme == .ironKnight {
            path.move(to: CGPoint(x: 0, y: -6))
            path.addLine(to: CGPoint(x: 0, y: 6))
            path.move(to: CGPoint(x: -4, y: -2))
            path.addLine(to: CGPoint(x: 4, y: -2))
        } else {
            path.move(to: CGPoint(x: -4, y: 0))
            path.addLine(to: CGPoint(x: 4, y: 0))
            path.move(to: CGPoint(x: 0, y: -5))
            path.addLine(to: CGPoint(x: 0, y: 5))
            if theme == .cyberMidnight {
                path.addRect(CGRect(x: -3, y: -3, width: 6, height: 6))
            }
        }

        return path
    }
}

/// Crop once at load time. Never decode or crop the atlas on animation frames.
@MainActor
private enum GRUDoodleAtlas {
    static let cells: [UIImage] = {
        guard let atlas = UIImage(named: "GRUCatDoodleAtlas")?.cgImage else { return [] }

        return (0..<27).compactMap { index in
            let column = index % 3
            let row = index / 3
            let x = atlas.width * column / 3
            let y = atlas.height * row / 9
            let right = atlas.width * (column + 1) / 3
            let bottom = atlas.height * (row + 1) / 9

            guard let crop = atlas.cropping(
                to: CGRect(
                    x: x,
                    y: y,
                    width: right - x,
                    height: bottom - y
                )
            ) else {
                return nil
            }

            return UIImage(cgImage: crop)
        }
    }()

    static func images(for row: Int) -> [UIImage] {
        guard cells.count == 27, (0..<9).contains(row) else { return [] }
        return Array(cells[(row * 3)..<(row * 3 + 3)])
    }
}
