import SwiftUI
import UIKit

/// Small independently moving doodles, not a moving full-screen bitmap.
struct GRUIllustratedWallpaper: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var moves: Bool {
        animated && !systemReduceMotion && !lowPower && scenePhase == .active
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

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !moves)) { timeline in
            let time = moves ? timeline.date.timeIntervalSinceReferenceDate : 0
            ZStack {
                LinearGradient(
                    colors: [theme.background, theme.card.opacity(0.65), theme.background],
                    startPoint: .topLeading, endPoint: .bottomTrailing
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
        let columns = max(1, Int(ceil(size.width / 86)))
        let rows = max(1, Int(ceil(size.height / 98)))
        let cellWidth = size.width / Double(columns)
        let cellHeight = size.height / Double(rows)
        let strength = min(max(intensity, 0), 1)

        for row in 0..<rows {
            for column in 0..<columns {
                let index = row * columns + column
                let seed = Double(index) * 2.399963
                let pose = (row + column * 2) % 3
                let rhythm = time / (3.5 + Double(index % 7) * 0.5) + seed
                let x = (Double(column) + 0.5) * cellWidth + sin(seed) * 5
                let y = (Double(row) + 0.5) * cellHeight + cos(seed) * 5
                let side = min(cellWidth, cellHeight) * (0.66 + Double(index % 3) * 0.07)
                let breath = sin(rhythm)
                var cat = context
                // Atlas has a pure black matte; screen blending removes it.
                cat.blendMode = .screen
                cat.opacity = strength * (0.33 + 0.06 * (breath + 1))
                cat.translateBy(x: x, y: y + breath * (pose == 1 ? 1 : 3))
                cat.rotate(by: .degrees(sin(seed) * 12 + breath * (pose == 1 ? 1 : 4)))
                cat.scaleBy(
                    x: index.isMultiple(of: 2) ? 1 : -1,
                    y: 1 + breath * (pose == 1 ? 0.035 : 0.018)
                )
                cat.draw(sprites[pose], in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side))

                var decor = context
                decor.opacity = strength * (0.16 + 0.06 * (sin(rhythm + 1) + 1))
                decor.translateBy(
                    x: Double(column) * cellWidth + 7 + sin(rhythm + 2) * 2,
                    y: Double(row) * cellHeight + 9 + cos(rhythm) * 2
                )
                decor.rotate(by: .degrees(breath * 8))
                let path = decoration(index: index)
                decor.stroke(path, with: .color(theme.accent), style: StrokeStyle(lineWidth: 0.85, lineCap: .round, lineJoin: .round))
            }
        }
    }

    /// Tiny hand-drawn marks between cats; no extra UI or oversized icons.
    private func decoration(index: Int) -> Path {
        var path = Path()
        if index % 3 == 0 {
            path.addEllipse(in: CGRect(x: -2.5, y: 0, width: 5, height: 4))
            for point in [CGPoint(x: -4, y: -3), CGPoint(x: 0, y: -5), CGPoint(x: 4, y: -3)] {
                path.addEllipse(in: CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2))
            }
        } else if theme == .powderPrincess {
            path.move(to: CGPoint(x: 0, y: 4))
            path.addCurve(to: CGPoint(x: 0, y: -2), control1: CGPoint(x: -10, y: -1), control2: CGPoint(x: -4, y: -8))
            path.addCurve(to: CGPoint(x: 0, y: 4), control1: CGPoint(x: 4, y: -8), control2: CGPoint(x: 10, y: -1))
        } else if theme == .greenAcidMonster {
            path.addEllipse(in: CGRect(x: -4, y: -4, width: 8, height: 8))
            path.addEllipse(in: CGRect(x: 5, y: -7, width: 3, height: 3))
        } else if theme == .forestWitch {
            path.move(to: CGPoint(x: -4, y: 5))
            path.addQuadCurve(to: CGPoint(x: 4, y: -5), control: CGPoint(x: -7, y: -5))
            path.addQuadCurve(to: CGPoint(x: -4, y: 5), control: CGPoint(x: 8, y: 5))
            path.addLine(to: CGPoint(x: 4, y: -5))
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

/// Crop once at load time. Never decode or crop a bitmap on animation frames.
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
            guard let crop = atlas.cropping(to: CGRect(x: x, y: y, width: right - x, height: bottom - y)) else { return nil }
            return UIImage(cgImage: crop)
        }
    }()

    static func images(for row: Int) -> [UIImage] {
        guard cells.count == 27, (0..<9).contains(row) else { return [] }
        return Array(cells[(row * 3)..<(row * 3 + 3)])
    }
}
