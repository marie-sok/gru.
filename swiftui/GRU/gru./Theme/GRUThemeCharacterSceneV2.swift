import SwiftUI

/// CAT PACK V2 — high-visibility GRU character wallpaper.
/// Characters are intentionally larger/brighter than V1 so they remain
/// unmistakable on real iPhone displays and inside theme previews.
struct GRUThemeCharacterSceneV2: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                    scene(time: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                scene(time: 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func scene(time: TimeInterval) -> some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        theme.background,
                        theme.card.opacity(0.92),
                        theme.background
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Canvas { context, size in
                    drawDecor(context: &context, size: size, time: time)
                    drawCats(context: &context, size: size, time: time)
                }
            }
        }
        .clipped()
    }

    private func drawCats(
        context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        let count = 30

        for index in 0..<count {
            let p = point(index: index, size: size, salt: 17)
            let driftX = CGFloat(sin(time * 0.48 + Double(index) * 0.71)) * 9
            let driftY = CGFloat(cos(time * 0.41 + Double(index) * 0.53)) * 8
            let base = CGFloat(31 + (index * 11) % 24)
            let pulse = CGFloat(0.96 + sin(time * 1.1 + Double(index)) * 0.045)
            let rotation = Angle.degrees(
                Double((index * 13) % 14 - 7) + sin(time * 0.45 + Double(index)) * 2.5
            )

            context.drawLayer { layer in
                layer.translateBy(x: p.x + driftX, y: p.y + driftY)
                layer.rotate(by: rotation)
                layer.scaleBy(x: pulse, y: pulse)

                drawThemeCat(
                    context: &layer,
                    size: base,
                    pose: index % 5,
                    time: time
                )
            }
        }
    }

    private func drawThemeCat(
        context: inout GraphicsContext,
        size: CGFloat,
        pose: Int,
        time: TimeInterval
    ) {
        switch theme {
        case .bloodDragon:
            catDragon(context: &context, size: size, pose: pose)
        case .ultravioletUnicorn:
            caticorn(context: &context, size: size, pose: pose)
        case .neonCatDemon:
            demonCat(context: &context, size: size, pose: pose)
        case .forestWitch:
            witchCat(context: &context, size: size, pose: pose)
        case .cyberMidnight:
            cyberCat(context: &context, size: size, pose: pose)
        case .powderPrincess:
            princessCat(context: &context, size: size, pose: pose)
        case .greenAcidMonster:
            monsterCat(context: &context, size: size, pose: pose)
        case .ironKnight:
            knightCat(context: &context, size: size, pose: pose)
        default:
            moonCat(context: &context, size: size, pose: pose)
        }
    }

    // MARK: - Shared cat

    private func catHead(radius r: CGFloat, folded: Bool = false) -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: -r, y: -r * 0.78, width: r * 2, height: r * 1.60))

        if folded {
            p.move(to: CGPoint(x: -r * 0.78, y: -r * 0.48))
            p.addQuadCurve(
                to: CGPoint(x: -r * 0.32, y: -r * 0.66),
                control: CGPoint(x: -r * 0.82, y: -r * 1.10)
            )
            p.addQuadCurve(
                to: CGPoint(x: -r * 0.70, y: -r * 0.18),
                control: CGPoint(x: -r * 0.28, y: -r * 0.18)
            )

            p.move(to: CGPoint(x: r * 0.78, y: -r * 0.48))
            p.addQuadCurve(
                to: CGPoint(x: r * 0.32, y: -r * 0.66),
                control: CGPoint(x: r * 0.82, y: -r * 1.10)
            )
            p.addQuadCurve(
                to: CGPoint(x: r * 0.70, y: -r * 0.18),
                control: CGPoint(x: r * 0.28, y: -r * 0.18)
            )
        } else {
            p.move(to: CGPoint(x: -r * 0.72, y: -r * 0.44))
            p.addLine(to: CGPoint(x: -r * 0.54, y: -r * 1.14))
            p.addLine(to: CGPoint(x: -r * 0.12, y: -r * 0.68))
            p.move(to: CGPoint(x: r * 0.72, y: -r * 0.44))
            p.addLine(to: CGPoint(x: r * 0.54, y: -r * 1.14))
            p.addLine(to: CGPoint(x: r * 0.12, y: -r * 0.68))
        }
        return p
    }

    private func face(context: inout GraphicsContext, r: CGFloat, grin: Bool = false) {
        let ink = theme.accent.opacity(0.92 * intensity)
        let second = theme.secondaryAccent.opacity(0.78 * intensity)

        var eyes = Path()
        eyes.addEllipse(in: CGRect(x: -r * 0.42, y: -r * 0.20, width: r * 0.15, height: r * 0.20))
        eyes.addEllipse(in: CGRect(x: r * 0.27, y: -r * 0.20, width: r * 0.15, height: r * 0.20))
        context.fill(eyes, with: .color(ink))

        var mouth = Path()
        mouth.move(to: CGPoint(x: 0, y: r * 0.04))
        mouth.addLine(to: CGPoint(x: 0, y: r * 0.18))
        mouth.move(to: CGPoint(x: 0, y: r * 0.18))
        mouth.addQuadCurve(
            to: CGPoint(x: -r * 0.25, y: r * (grin ? 0.18 : 0.29)),
            control: CGPoint(x: -r * 0.12, y: r * 0.32)
        )
        mouth.move(to: CGPoint(x: 0, y: r * 0.18))
        mouth.addQuadCurve(
            to: CGPoint(x: r * 0.25, y: r * (grin ? 0.18 : 0.29)),
            control: CGPoint(x: r * 0.12, y: r * 0.32)
        )
        context.stroke(mouth, with: .color(second), lineWidth: 1.35)

        var whiskers = Path()
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            whiskers.move(to: CGPoint(x: s * r * 0.47, y: r * 0.09))
            whiskers.addLine(to: CGPoint(x: s * r * 0.98, y: r * 0.00))
            whiskers.move(to: CGPoint(x: s * r * 0.47, y: r * 0.23))
            whiskers.addLine(to: CGPoint(x: s * r * 0.98, y: r * 0.34))
        }
        context.stroke(whiskers, with: .color(ink.opacity(0.72)), lineWidth: 1.05)
    }

    private func stroke(
        _ path: Path,
        context: inout GraphicsContext,
        secondary: Bool = false,
        width: CGFloat = 1.8
    ) {
        let color = secondary ? theme.secondaryAccent : theme.accent
        context.stroke(
            path,
            with: .color(color.opacity(0.78 * intensity)),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }

    private func basicCat(context: inout GraphicsContext, size: CGFloat, folded: Bool = false, grin: Bool = false) {
        let r = size * 0.31
        stroke(catHead(radius: r, folded: folded), context: &context, width: 2.0)
        face(context: &context, r: r, grin: grin)

        var body = Path()
        body.move(to: CGPoint(x: -r * 0.52, y: r * 0.72))
        body.addQuadCurve(
            to: CGPoint(x: r * 0.52, y: r * 0.72),
            control: CGPoint(x: 0, y: r * 1.46)
        )
        stroke(body, context: &context, width: 1.6)
    }

    // MARK: - Characters

    private func moonCat(context: inout GraphicsContext, size: CGFloat, pose: Int) {
        basicCat(context: &context, size: size, folded: pose == 3)
        let r = size * 0.31
        var moon = Path()
        moon.addArc(
            center: CGPoint(x: r * 0.92, y: -r * 0.92),
            radius: r * 0.34,
            startAngle: .degrees(45),
            endAngle: .degrees(300),
            clockwise: false
        )
        stroke(moon, context: &context, secondary: true, width: 1.4)
    }

    private func demonCat(context: inout GraphicsContext, size: CGFloat, pose: Int) {
        basicCat(context: &context, size: size, folded: false, grin: true)
        let r = size * 0.31
        var horns = Path()
        horns.move(to: CGPoint(x: -r * 0.48, y: -r * 0.72))
        horns.addQuadCurve(to: CGPoint(x: -r * 0.98, y: -r * 1.28), control: CGPoint(x: -r * 0.90, y: -r * 0.80))
        horns.move(to: CGPoint(x: r * 0.48, y: -r * 0.72))
        horns.addQuadCurve(to: CGPoint(x: r * 0.98, y: -r * 1.28), control: CGPoint(x: r * 0.90, y: -r * 0.80))
        stroke(horns, context: &context, secondary: true, width: 2.0)

        var tail = Path()
        tail.move(to: CGPoint(x: r * 0.48, y: r * 0.70))
        tail.addCurve(
            to: CGPoint(x: r * 1.48, y: -r * 0.04),
            control1: CGPoint(x: r * 1.15, y: r * 1.04),
            control2: CGPoint(x: r * 1.55, y: r * 0.42)
        )
        stroke(tail, context: &context, width: 1.7)
    }

    private func catDragon(context: inout GraphicsContext, size: CGFloat, pose: Int) {
        basicCat(context: &context, size: size, folded: true, grin: pose == 4)
        let r = size * 0.31

        var wings = Path()
        wings.move(to: CGPoint(x: -r * 0.54, y: r * 0.42))
        wings.addLine(to: CGPoint(x: -r * 1.28, y: r * 0.02))
        wings.addLine(to: CGPoint(x: -r * 1.02, y: r * 0.72))
        wings.addLine(to: CGPoint(x: -r * 0.52, y: r * 0.56))
        wings.move(to: CGPoint(x: r * 0.54, y: r * 0.42))
        wings.addLine(to: CGPoint(x: r * 1.28, y: r * 0.02))
        wings.addLine(to: CGPoint(x: r * 1.02, y: r * 0.72))
        wings.addLine(to: CGPoint(x: r * 0.52, y: r * 0.56))
        stroke(wings, context: &context, secondary: true, width: 1.8)

        var tail = Path()
        tail.move(to: CGPoint(x: r * 0.42, y: r * 0.78))
        tail.addCurve(
            to: CGPoint(x: r * 1.78, y: -r * 0.10),
            control1: CGPoint(x: r * 1.18, y: r * 1.35),
            control2: CGPoint(x: r * 1.86, y: r * 0.54)
        )
        stroke(tail, context: &context, width: 1.8)

        for i in 0..<3 {
            var scale = Path()
            let x = r * (0.22 + CGFloat(i) * 0.20)
            scale.addEllipse(in: CGRect(x: x, y: r * 0.63, width: r * 0.10, height: r * 0.10))
            context.fill(scale, with: .color(theme.secondaryAccent.opacity(0.72 * intensity)))
        }
    }

    private func caticorn(context: inout GraphicsContext, size: CGFloat, pose: Int) {
        basicCat(context: &context, size: size, folded: pose == 3)
        let r = size * 0.31
        var horn = Path()
        horn.move(to: CGPoint(x: -r * 0.10, y: -r * 0.70))
        horn.addLine(to: CGPoint(x: 0, y: -r * 1.62))
        horn.addLine(to: CGPoint(x: r * 0.10, y: -r * 0.70))
        stroke(horn, context: &context, secondary: true, width: 1.9)

        if pose.isMultiple(of: 2) {
            var wing = Path()
            wing.move(to: CGPoint(x: r * 0.48, y: r * 0.40))
            wing.addQuadCurve(to: CGPoint(x: r * 1.28, y: r * 0.12), control: CGPoint(x: r * 0.98, y: -r * 0.02))
            wing.addQuadCurve(to: CGPoint(x: r * 0.52, y: r * 0.62), control: CGPoint(x: r * 1.04, y: r * 0.66))
            stroke(wing, context: &context, width: 1.6)
        }
    }

    private func witchCat(context: inout GraphicsContext, size: CGFloat, pose: Int) {
        basicCat(context: &context, size: size, folded: pose == 4)
        let r = size * 0.31
        var hat = Path()
        hat.move(to: CGPoint(x: -r * 0.76, y: -r * 0.70))
        hat.addLine(to: CGPoint(x: r * 0.78, y: -r * 0.70))
        hat.move(to: CGPoint(x: -r * 0.48, y: -r * 0.72))
        hat.addQuadCurve(to: CGPoint(x: r * 0.12, y: -r * 1.72), control: CGPoint(x: -r * 0.05, y: -r * 1.40))
        hat.addQuadCurve(to: CGPoint(x: r * 0.48, y: -r * 0.72), control: CGPoint(x: r * 0.62, y: -r * 1.24))
        stroke(hat, context: &context, secondary: true, width: 1.8)
    }

    private func cyberCat(context: inout GraphicsContext, size: CGFloat, pose: Int) {
        basicCat(context: &context, size: size, folded: false)
        let r = size * 0.31
        var visor = Path()
        visor.addRoundedRect(
            in: CGRect(x: -r * 0.52, y: -r * 0.25, width: r * 1.04, height: r * 0.28),
            cornerSize: CGSize(width: r * 0.08, height: r * 0.08)
        )
        stroke(visor, context: &context, secondary: true, width: 1.6)
    }

    private func princessCat(context: inout GraphicsContext, size: CGFloat, pose: Int) {
        basicCat(context: &context, size: size, folded: pose == 2)
        let r = size * 0.31
        var crown = Path()
        crown.move(to: CGPoint(x: -r * 0.52, y: -r * 0.72))
        crown.addLine(to: CGPoint(x: -r * 0.32, y: -r * 1.18))
        crown.addLine(to: CGPoint(x: 0, y: -r * 0.88))
        crown.addLine(to: CGPoint(x: r * 0.32, y: -r * 1.18))
        crown.addLine(to: CGPoint(x: r * 0.52, y: -r * 0.72))
        stroke(crown, context: &context, secondary: true, width: 1.7)
    }

    private func monsterCat(context: inout GraphicsContext, size: CGFloat, pose: Int) {
        basicCat(context: &context, size: size, folded: pose == 1, grin: true)
        let r = size * 0.31
        var slime = Path()
        slime.move(to: CGPoint(x: -r * 0.72, y: r * 0.48))
        slime.addQuadCurve(to: CGPoint(x: -r * 0.48, y: r * 1.30), control: CGPoint(x: -r * 0.72, y: r * 1.02))
        slime.move(to: CGPoint(x: r * 0.72, y: r * 0.48))
        slime.addQuadCurve(to: CGPoint(x: r * 0.48, y: r * 1.24), control: CGPoint(x: r * 0.72, y: r * 0.98))
        stroke(slime, context: &context, secondary: true, width: 1.7)
    }

    private func knightCat(context: inout GraphicsContext, size: CGFloat, pose: Int) {
        basicCat(context: &context, size: size, folded: true)
        let r = size * 0.31
        var helmet = Path()
        helmet.addArc(center: .zero, radius: r * 0.92, startAngle: .degrees(198), endAngle: .degrees(342), clockwise: false)
        helmet.move(to: CGPoint(x: -r * 0.54, y: -r * 0.02))
        helmet.addLine(to: CGPoint(x: r * 0.54, y: -r * 0.02))
        stroke(helmet, context: &context, secondary: true, width: 1.8)

        if pose.isMultiple(of: 2) {
            var sword = Path()
            sword.move(to: CGPoint(x: r * 0.82, y: r * 0.72))
            sword.addLine(to: CGPoint(x: r * 1.48, y: -r * 0.64))
            sword.move(to: CGPoint(x: r * 0.72, y: r * 0.28))
            sword.addLine(to: CGPoint(x: r * 1.18, y: r * 0.50))
            stroke(sword, context: &context, width: 1.7)
        }
    }

    // MARK: - Decor

    private func drawDecor(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<42 {
            let p = point(index: index, size: size, salt: 91)
            let wobble = CGFloat(sin(time * 0.7 + Double(index)) * 3)
            let c = index.isMultiple(of: 2) ? theme.accent : theme.secondaryAccent
            let alpha = (0.18 + 0.18 * (0.5 + 0.5 * sin(time + Double(index)))) * intensity

            if index % 4 == 0 {
                var sparkle = Path()
                sparkle.move(to: CGPoint(x: p.x - 3, y: p.y + wobble))
                sparkle.addLine(to: CGPoint(x: p.x + 3, y: p.y + wobble))
                sparkle.move(to: CGPoint(x: p.x, y: p.y - 3 + wobble))
                sparkle.addLine(to: CGPoint(x: p.x, y: p.y + 3 + wobble))
                context.stroke(sparkle, with: .color(c.opacity(alpha)), lineWidth: 1)
            } else {
                context.fill(
                    Path(ellipseIn: CGRect(x: p.x - 1.2, y: p.y - 1.2 + wobble, width: 2.4, height: 2.4)),
                    with: .color(c.opacity(alpha))
                )
            }
        }
    }

    private func point(index: Int, size: CGSize, salt: Int) -> CGPoint {
        let xSeed = Double((index * 47 + salt * 19) % 997) / 997.0
        let ySeed = Double((index * 83 + salt * 29) % 991) / 991.0
        return CGPoint(
            x: CGFloat(0.06 + xSeed * 0.88) * size.width,
            y: CGFloat(0.05 + ySeed * 0.90) * size.height
        )
    }
}
