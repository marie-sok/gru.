import SwiftUI

/// GRU's release character wallpaper language.
/// Every illustration is drawn directly into a transparent SwiftUI Canvas:
/// no bitmap tiles, no matte rectangles, no stock-looking glyph atlas.
struct GRUThemeCharacterScene: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    var body: some View {
        if animated {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                scene(at: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            scene(at: 0)
        }
    }

    private func scene(at time: TimeInterval) -> some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        theme.background,
                        theme.card.opacity(0.86),
                        theme.background
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Canvas { context, size in
                    drawCharacters(
                        context: &context,
                        size: size,
                        time: time
                    )
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawCharacters(
        context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        for index in 0..<34 {
            let point = layoutPoint(index, size: size)
            let drift = animatedDrift(index, time: time)
            let center = CGPoint(
                x: point.x + drift.width,
                y: point.y + drift.height
            )

            let base = CGFloat(19 + (index * 7) % 18)
            let rotation = Angle.degrees(
                Double((index * 17) % 18 - 9) + sin(time * 0.55 + Double(index)) * 4
            )
            let pulse = CGFloat(0.93 + 0.08 * sin(time * 1.25 + Double(index) * 0.7))

            context.drawLayer { layer in
                layer.translateBy(x: center.x, y: center.y)
                layer.rotate(by: rotation)
                layer.scaleBy(x: pulse, y: pulse)

                drawThemeCharacter(
                    context: &layer,
                    index: index,
                    size: base,
                    time: time
                )
            }
        }

        // Tiny decor deliberately fills the negative space between characters.
        for index in 0..<46 {
            let p = layoutPoint(index + 61, size: size)
            let drift = animatedDrift(index + 91, time: time * 0.72)
            drawDecor(
                context: &context,
                center: CGPoint(x: p.x + drift.width, y: p.y + drift.height),
                index: index,
                time: time
            )
        }
    }

    private func drawThemeCharacter(
        context: inout GraphicsContext,
        index: Int,
        size: CGFloat,
        time: TimeInterval
    ) {
        switch theme {
        case .blackMoonCat:
            drawMoonCat(context: &context, size: size, pose: index % 4, time: time)
        case .neonCatDemon:
            drawDemonCat(context: &context, size: size, pose: index % 4, time: time)
        case .bloodDragon:
            drawFoldedEarCatDragon(context: &context, size: size, pose: index % 5, time: time)
        case .forestWitch:
            drawWitchCat(context: &context, size: size, pose: index % 4, time: time)
        case .cyberMidnight:
            drawCyberCat(context: &context, size: size, pose: index % 4, time: time)
        case .ultravioletUnicorn:
            drawCaticorn(context: &context, size: size, pose: index % 5, time: time)
        case .powderPrincess:
            drawPrincessCat(context: &context, size: size, pose: index % 4, time: time)
        case .greenAcidMonster:
            drawAcidMonsterCat(context: &context, size: size, pose: index % 4, time: time)
        case .ironKnight:
            drawKnightCat(context: &context, size: size, pose: index % 4, time: time)
        default:
            drawMoonCat(context: &context, size: size, pose: index % 4, time: time)
        }
    }

    // MARK: - Shared face / body

    private func catHead(
        center: CGPoint = .zero,
        radius: CGFloat,
        foldedEars: Bool = false
    ) -> Path {
        var path = Path()

        path.addEllipse(
            in: CGRect(
                x: center.x - radius,
                y: center.y - radius * 0.78,
                width: radius * 2,
                height: radius * 1.62
            )
        )

        if foldedEars {
            path.move(to: CGPoint(x: center.x - radius * 0.78, y: center.y - radius * 0.50))
            path.addQuadCurve(
                to: CGPoint(x: center.x - radius * 0.36, y: center.y - radius * 0.68),
                control: CGPoint(x: center.x - radius * 0.78, y: center.y - radius * 1.05)
            )
            path.addQuadCurve(
                to: CGPoint(x: center.x - radius * 0.74, y: center.y - radius * 0.22),
                control: CGPoint(x: center.x - radius * 0.36, y: center.y - radius * 0.20)
            )

            path.move(to: CGPoint(x: center.x + radius * 0.78, y: center.y - radius * 0.50))
            path.addQuadCurve(
                to: CGPoint(x: center.x + radius * 0.36, y: center.y - radius * 0.68),
                control: CGPoint(x: center.x + radius * 0.78, y: center.y - radius * 1.05)
            )
            path.addQuadCurve(
                to: CGPoint(x: center.x + radius * 0.74, y: center.y - radius * 0.22),
                control: CGPoint(x: center.x + radius * 0.36, y: center.y - radius * 0.20)
            )
        } else {
            path.move(to: CGPoint(x: center.x - radius * 0.72, y: center.y - radius * 0.48))
            path.addLine(to: CGPoint(x: center.x - radius * 0.55, y: center.y - radius * 1.10))
            path.addLine(to: CGPoint(x: center.x - radius * 0.16, y: center.y - radius * 0.70))

            path.move(to: CGPoint(x: center.x + radius * 0.72, y: center.y - radius * 0.48))
            path.addLine(to: CGPoint(x: center.x + radius * 0.55, y: center.y - radius * 1.10))
            path.addLine(to: CGPoint(x: center.x + radius * 0.16, y: center.y - radius * 0.70))
        }

        return path
    }

    private func drawCatFace(
        context: inout GraphicsContext,
        radius: CGFloat,
        grin: Bool = false,
        sleepy: Bool = false
    ) {
        let ink = theme.accent.opacity(0.48 * intensity)
        let secondary = theme.secondaryAccent.opacity(0.34 * intensity)

        var eyes = Path()
        if sleepy {
            eyes.move(to: CGPoint(x: -radius * 0.42, y: -radius * 0.12))
            eyes.addQuadCurve(
                to: CGPoint(x: -radius * 0.10, y: -radius * 0.12),
                control: CGPoint(x: -radius * 0.26, y: radius * 0.02)
            )
            eyes.move(to: CGPoint(x: radius * 0.10, y: -radius * 0.12))
            eyes.addQuadCurve(
                to: CGPoint(x: radius * 0.42, y: -radius * 0.12),
                control: CGPoint(x: radius * 0.26, y: radius * 0.02)
            )
        } else {
            eyes.addEllipse(in: CGRect(x: -radius * 0.40, y: -radius * 0.18, width: radius * 0.12, height: radius * 0.18))
            eyes.addEllipse(in: CGRect(x: radius * 0.28, y: -radius * 0.18, width: radius * 0.12, height: radius * 0.18))
        }
        context.stroke(eyes, with: .color(ink), lineWidth: 1.05)

        var noseMouth = Path()
        noseMouth.move(to: CGPoint(x: 0, y: radius * 0.04))
        noseMouth.addLine(to: CGPoint(x: 0, y: radius * 0.17))
        noseMouth.move(to: CGPoint(x: 0, y: radius * 0.17))
        noseMouth.addQuadCurve(
            to: CGPoint(x: -radius * 0.22, y: radius * (grin ? 0.20 : 0.28)),
            control: CGPoint(x: -radius * 0.10, y: radius * (grin ? 0.32 : 0.24))
        )
        noseMouth.move(to: CGPoint(x: 0, y: radius * 0.17))
        noseMouth.addQuadCurve(
            to: CGPoint(x: radius * 0.22, y: radius * (grin ? 0.20 : 0.28)),
            control: CGPoint(x: radius * 0.10, y: radius * (grin ? 0.32 : 0.24))
        )
        context.stroke(noseMouth, with: .color(secondary), lineWidth: 0.9)

        var whiskers = Path()
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            whiskers.move(to: CGPoint(x: s * radius * 0.46, y: radius * 0.10))
            whiskers.addLine(to: CGPoint(x: s * radius * 0.90, y: radius * 0.02))
            whiskers.move(to: CGPoint(x: s * radius * 0.46, y: radius * 0.23))
            whiskers.addLine(to: CGPoint(x: s * radius * 0.90, y: radius * 0.31))
        }
        context.stroke(whiskers, with: .color(ink.opacity(0.72)), lineWidth: 0.75)
    }

    private func strokeCharacter(
        _ path: Path,
        context: inout GraphicsContext,
        strong: Bool = false
    ) {
        context.stroke(
            path,
            with: .color(theme.accent.opacity((strong ? 0.58 : 0.38) * intensity)),
            style: StrokeStyle(
                lineWidth: strong ? 1.45 : 1.15,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    // MARK: - Black Moon Cat

    private func drawMoonCat(
        context: inout GraphicsContext,
        size: CGFloat,
        pose: Int,
        time: TimeInterval
    ) {
        let r = size * 0.34
        strokeCharacter(catHead(radius: r), context: &context)
        drawCatFace(context: &context, radius: r, sleepy: pose == 2)

        var moon = Path()
        moon.addArc(
            center: CGPoint(x: r * 0.72, y: -r * 0.92),
            radius: r * 0.34,
            startAngle: .degrees(55),
            endAngle: .degrees(300),
            clockwise: false
        )
        context.stroke(moon, with: .color(Color.white.opacity(0.25 * intensity)), lineWidth: 1)

        if pose == 1 {
            var tail = Path()
            tail.move(to: CGPoint(x: -r * 0.55, y: r * 0.78))
            tail.addCurve(
                to: CGPoint(x: -r * 1.1, y: r * 0.10),
                control1: CGPoint(x: -r * 1.2, y: r * 0.9),
                control2: CGPoint(x: -r * 1.25, y: r * 0.25)
            )
            strokeCharacter(tail, context: &context)
        }
    }

    // MARK: - Neon Demon Cat

    private func drawDemonCat(
        context: inout GraphicsContext,
        size: CGFloat,
        pose: Int,
        time: TimeInterval
    ) {
        let r = size * 0.34
        strokeCharacter(catHead(radius: r), context: &context, strong: true)
        drawCatFace(context: &context, radius: r, grin: true)

        var horns = Path()
        horns.move(to: CGPoint(x: -r * 0.46, y: -r * 0.72))
        horns.addQuadCurve(
            to: CGPoint(x: -r * 0.90, y: -r * 1.18),
            control: CGPoint(x: -r * 0.82, y: -r * 0.82)
        )
        horns.move(to: CGPoint(x: r * 0.46, y: -r * 0.72))
        horns.addQuadCurve(
            to: CGPoint(x: r * 0.90, y: -r * 1.18),
            control: CGPoint(x: r * 0.82, y: -r * 0.82)
        )
        context.stroke(
            horns,
            with: .color(theme.secondaryAccent.opacity(0.58 * intensity)),
            style: StrokeStyle(lineWidth: 1.35, lineCap: .round)
        )

        if pose.isMultiple(of: 2) {
            var flameTail = Path()
            flameTail.move(to: CGPoint(x: r * 0.48, y: r * 0.70))
            flameTail.addCurve(
                to: CGPoint(x: r * 1.18, y: r * 0.18),
                control1: CGPoint(x: r * 1.06, y: r * 0.92),
                control2: CGPoint(x: r * 1.28, y: r * 0.44)
            )
            flameTail.addQuadCurve(
                to: CGPoint(x: r * 1.04, y: -r * 0.10),
                control: CGPoint(x: r * 1.35, y: r * 0.04)
            )
            strokeCharacter(flameTail, context: &context, strong: true)
        }
    }

    // MARK: - Fold-eared Cat Dragon

    private func drawFoldedEarCatDragon(
        context: inout GraphicsContext,
        size: CGFloat,
        pose: Int,
        time: TimeInterval
    ) {
        let r = size * 0.30
        strokeCharacter(catHead(radius: r, foldedEars: true), context: &context, strong: true)
        drawCatFace(context: &context, radius: r, grin: pose == 3)

        var body = Path()
        body.move(to: CGPoint(x: -r * 0.50, y: r * 0.70))
        body.addQuadCurve(
            to: CGPoint(x: r * 0.42, y: r * 1.10),
            control: CGPoint(x: -r * 0.06, y: r * 1.34)
        )
        body.addQuadCurve(
            to: CGPoint(x: r * 1.35, y: r * 0.55),
            control: CGPoint(x: r * 1.04, y: r * 1.18)
        )
        body.addCurve(
            to: CGPoint(x: r * 1.70, y: -r * 0.10),
            control1: CGPoint(x: r * 1.58, y: r * 0.36),
            control2: CGPoint(x: r * 1.50, y: r * 0.02)
        )
        strokeCharacter(body, context: &context, strong: true)

        var wings = Path()
        wings.move(to: CGPoint(x: -r * 0.25, y: r * 0.78))
        wings.addLine(to: CGPoint(x: -r * 0.98, y: r * 0.20))
        wings.addLine(to: CGPoint(x: -r * 0.68, y: r * 0.88))
        wings.addLine(to: CGPoint(x: -r * 1.20, y: r * 1.02))
        wings.addLine(to: CGPoint(x: -r * 0.18, y: r * 1.06))
        context.stroke(
            wings,
            with: .color(theme.secondaryAccent.opacity(0.45 * intensity)),
            style: StrokeStyle(lineWidth: 1.05, lineCap: .round, lineJoin: .round)
        )

        // Tiny scales make the hybrid unmistakably dragon-like.
        for i in 0..<3 {
            var scale = Path()
            let x = r * (0.34 + CGFloat(i) * 0.26)
            scale.addArc(
                center: CGPoint(x: x, y: r * 0.84),
                radius: r * 0.10,
                startAngle: .degrees(200),
                endAngle: .degrees(340),
                clockwise: false
            )
            context.stroke(scale, with: .color(theme.accent.opacity(0.28 * intensity)), lineWidth: 0.7)
        }
    }

    // MARK: - Forest Witch

    private func drawWitchCat(
        context: inout GraphicsContext,
        size: CGFloat,
        pose: Int,
        time: TimeInterval
    ) {
        let r = size * 0.31
        strokeCharacter(catHead(radius: r), context: &context)
        drawCatFace(context: &context, radius: r, sleepy: pose == 3)

        var hat = Path()
        hat.move(to: CGPoint(x: -r * 0.95, y: -r * 0.72))
        hat.addLine(to: CGPoint(x: r * 0.92, y: -r * 0.72))
        hat.move(to: CGPoint(x: -r * 0.56, y: -r * 0.74))
        hat.addQuadCurve(
            to: CGPoint(x: r * 0.18, y: -r * 1.72),
            control: CGPoint(x: -r * 0.16, y: -r * 1.44)
        )
        hat.addQuadCurve(
            to: CGPoint(x: r * 0.54, y: -r * 0.82),
            control: CGPoint(x: r * 0.62, y: -r * 1.34)
        )
        context.stroke(hat, with: .color(theme.secondaryAccent.opacity(0.48 * intensity)), lineWidth: 1.2)
    }

    // MARK: - Cyber Cat

    private func drawCyberCat(
        context: inout GraphicsContext,
        size: CGFloat,
        pose: Int,
        time: TimeInterval
    ) {
        let r = size * 0.31
        strokeCharacter(catHead(radius: r), context: &context, strong: true)
        drawCatFace(context: &context, radius: r)

        var visor = Path()
        visor.move(to: CGPoint(x: -r * 0.58, y: -r * 0.17))
        visor.addLine(to: CGPoint(x: r * 0.58, y: -r * 0.17))
        context.stroke(
            visor,
            with: .color(theme.secondaryAccent.opacity(0.70 * intensity)),
            lineWidth: 1.5
        )

        var antenna = Path()
        antenna.move(to: CGPoint(x: r * 0.50, y: -r * 0.72))
        antenna.addLine(to: CGPoint(x: r * 0.92, y: -r * 1.18))
        antenna.addEllipse(in: CGRect(x: r * 0.84, y: -r * 1.30, width: r * 0.18, height: r * 0.18))
        strokeCharacter(antenna, context: &context)
    }

    // MARK: - Caticorn

    private func drawCaticorn(
        context: inout GraphicsContext,
        size: CGFloat,
        pose: Int,
        time: TimeInterval
    ) {
        let r = size * 0.31
        strokeCharacter(catHead(radius: r), context: &context, strong: true)
        drawCatFace(context: &context, radius: r, sleepy: pose == 2)

        var horn = Path()
        horn.move(to: CGPoint(x: -r * 0.08, y: -r * 0.78))
        horn.addLine(to: CGPoint(x: r * 0.08, y: -r * 1.75))
        horn.addLine(to: CGPoint(x: r * 0.25, y: -r * 0.78))
        context.stroke(
            horn,
            with: .color(theme.secondaryAccent.opacity(0.64 * intensity)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
        )

        var mane = Path()
        mane.move(to: CGPoint(x: r * 0.58, y: -r * 0.42))
        mane.addCurve(
            to: CGPoint(x: r * 0.72, y: r * 0.62),
            control1: CGPoint(x: r * 1.10, y: -r * 0.04),
            control2: CGPoint(x: r * 0.42, y: r * 0.34)
        )
        context.stroke(mane, with: .color(theme.secondaryAccent.opacity(0.42 * intensity)), lineWidth: 1.1)

        if pose == 4 {
            var tinyWing = Path()
            tinyWing.move(to: CGPoint(x: -r * 0.50, y: r * 0.64))
            tinyWing.addQuadCurve(
                to: CGPoint(x: -r * 1.05, y: r * 0.24),
                control: CGPoint(x: -r * 0.96, y: r * 0.66)
            )
            tinyWing.addQuadCurve(
                to: CGPoint(x: -r * 0.54, y: r * 0.84),
                control: CGPoint(x: -r * 1.00, y: r * 0.98)
            )
            strokeCharacter(tinyWing, context: &context)
        }
    }

    // MARK: - Princess Cat

    private func drawPrincessCat(
        context: inout GraphicsContext,
        size: CGFloat,
        pose: Int,
        time: TimeInterval
    ) {
        let r = size * 0.31
        strokeCharacter(catHead(radius: r), context: &context)
        drawCatFace(context: &context, radius: r, sleepy: pose == 1)

        var crown = Path()
        crown.move(to: CGPoint(x: -r * 0.62, y: -r * 0.84))
        crown.addLine(to: CGPoint(x: -r * 0.42, y: -r * 1.30))
        crown.addLine(to: CGPoint(x: -r * 0.08, y: -r * 0.94))
        crown.addLine(to: CGPoint(x: r * 0.20, y: -r * 1.36))
        crown.addLine(to: CGPoint(x: r * 0.54, y: -r * 0.88))
        context.stroke(crown, with: .color(theme.secondaryAccent.opacity(0.52 * intensity)), lineWidth: 1.05)

        if pose == 3 {
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: r * 0.66, y: r * 0.25))
            ribbon.addQuadCurve(
                to: CGPoint(x: r * 1.18, y: r * 0.10),
                control: CGPoint(x: r * 1.02, y: r * 0.48)
            )
            ribbon.addQuadCurve(
                to: CGPoint(x: r * 0.78, y: r * 0.62),
                control: CGPoint(x: r * 1.20, y: r * 0.70)
            )
            strokeCharacter(ribbon, context: &context)
        }
    }

    // MARK: - Acid Monster Cat

    private func drawAcidMonsterCat(
        context: inout GraphicsContext,
        size: CGFloat,
        pose: Int,
        time: TimeInterval
    ) {
        let r = size * 0.31
        strokeCharacter(catHead(radius: r), context: &context, strong: true)
        drawCatFace(context: &context, radius: r, grin: true)

        var slime = Path()
        slime.move(to: CGPoint(x: -r * 0.58, y: r * 0.58))
        slime.addQuadCurve(
            to: CGPoint(x: -r * 0.28, y: r * 1.18),
            control: CGPoint(x: -r * 0.56, y: r * 1.04)
        )
        slime.addQuadCurve(
            to: CGPoint(x: 0, y: r * 0.66),
            control: CGPoint(x: -r * 0.08, y: r * 1.24)
        )
        slime.addQuadCurve(
            to: CGPoint(x: r * 0.54, y: r * 1.02),
            control: CGPoint(x: r * 0.22, y: r * 0.82)
        )
        context.stroke(
            slime,
            with: .color(theme.secondaryAccent.opacity(0.58 * intensity)),
            style: StrokeStyle(lineWidth: 1.35, lineCap: .round)
        )
    }

    // MARK: - Knight Cat

    private func drawKnightCat(
        context: inout GraphicsContext,
        size: CGFloat,
        pose: Int,
        time: TimeInterval
    ) {
        let r = size * 0.31
        strokeCharacter(catHead(radius: r), context: &context, strong: true)
        drawCatFace(context: &context, radius: r)

        var helmet = Path()
        helmet.move(to: CGPoint(x: -r * 0.74, y: -r * 0.18))
        helmet.addQuadCurve(
            to: CGPoint(x: r * 0.74, y: -r * 0.18),
            control: CGPoint(x: 0, y: -r * 1.30)
        )
        helmet.move(to: CGPoint(x: -r * 0.68, y: -r * 0.02))
        helmet.addLine(to: CGPoint(x: r * 0.68, y: -r * 0.02))
        context.stroke(helmet, with: .color(theme.secondaryAccent.opacity(0.46 * intensity)), lineWidth: 1.15)

        if pose.isMultiple(of: 2) {
            var sword = Path()
            sword.move(to: CGPoint(x: r * 0.68, y: r * 0.48))
            sword.addLine(to: CGPoint(x: r * 1.42, y: -r * 0.42))
            sword.move(to: CGPoint(x: r * 0.58, y: r * 0.22))
            sword.addLine(to: CGPoint(x: r * 0.92, y: r * 0.52))
            context.stroke(sword, with: .color(theme.accent.opacity(0.46 * intensity)), lineWidth: 1.05)
        }
    }

    // MARK: - Decor

    private func drawDecor(
        context: inout GraphicsContext,
        center: CGPoint,
        index: Int,
        time: TimeInterval
    ) {
        let alpha = (0.10 + 0.08 * sin(time * 1.1 + Double(index))) * intensity
        let radius = CGFloat(1.2 + Double(index % 3) * 0.75)

        context.drawLayer { layer in
            layer.translateBy(x: center.x, y: center.y)

            switch theme {
            case .blackMoonCat:
                if index.isMultiple(of: 4) {
                    var crescent = Path()
                    crescent.addArc(center: .zero, radius: radius * 3.2, startAngle: .degrees(45), endAngle: .degrees(310), clockwise: false)
                    layer.stroke(crescent, with: .color(Color.white.opacity(alpha)), lineWidth: 0.8)
                } else {
                    layer.fill(Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)), with: .color(Color.white.opacity(alpha)))
                }

            case .bloodDragon:
                var spark = Path()
                spark.move(to: CGPoint(x: 0, y: -radius * 3))
                spark.addQuadCurve(to: CGPoint(x: radius, y: radius * 3), control: CGPoint(x: radius * 2, y: 0))
                spark.addQuadCurve(to: CGPoint(x: -radius, y: radius * 2), control: CGPoint(x: -radius * 2, y: radius))
                spark.closeSubpath()
                layer.stroke(spark, with: .color(theme.secondaryAccent.opacity(alpha)), lineWidth: 0.8)

            case .forestWitch:
                var leaf = Path()
                leaf.addEllipse(in: CGRect(x: -radius * 2.4, y: -radius, width: radius * 4.8, height: radius * 2))
                layer.stroke(leaf, with: .color(theme.accent.opacity(alpha)), lineWidth: 0.7)

            case .cyberMidnight:
                let rect = CGRect(x: -radius * 2.5, y: -radius, width: radius * 5, height: radius * 2)
                layer.stroke(Path(rect), with: .color(theme.accent.opacity(alpha)), lineWidth: 0.65)

            case .ultravioletUnicorn:
                var star = Path()
                star.move(to: CGPoint(x: 0, y: -radius * 3))
                star.addLine(to: CGPoint(x: 0, y: radius * 3))
                star.move(to: CGPoint(x: -radius * 3, y: 0))
                star.addLine(to: CGPoint(x: radius * 3, y: 0))
                layer.stroke(star, with: .color(Color.white.opacity(alpha)), lineWidth: 0.8)

            case .powderPrincess:
                var heart = Path()
                heart.move(to: CGPoint(x: 0, y: radius * 2.3))
                heart.addCurve(
                    to: CGPoint(x: 0, y: -radius * 0.2),
                    control1: CGPoint(x: -radius * 3, y: radius * 0.5),
                    control2: CGPoint(x: -radius * 2, y: -radius * 2.2)
                )
                heart.addCurve(
                    to: CGPoint(x: 0, y: radius * 2.3),
                    control1: CGPoint(x: radius * 2, y: -radius * 2.2),
                    control2: CGPoint(x: radius * 3, y: radius * 0.5)
                )
                layer.stroke(heart, with: .color(theme.secondaryAccent.opacity(alpha)), lineWidth: 0.75)

            case .greenAcidMonster:
                layer.fill(
                    Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 3.2)),
                    with: .color(theme.secondaryAccent.opacity(alpha))
                )

            case .ironKnight:
                var cross = Path()
                cross.move(to: CGPoint(x: 0, y: -radius * 3))
                cross.addLine(to: CGPoint(x: 0, y: radius * 3))
                cross.move(to: CGPoint(x: -radius * 1.8, y: -radius * 0.8))
                cross.addLine(to: CGPoint(x: radius * 1.8, y: -radius * 0.8))
                layer.stroke(cross, with: .color(theme.secondaryAccent.opacity(alpha)), lineWidth: 0.75)

            case .neonCatDemon:
                var spark = Path()
                spark.move(to: CGPoint(x: 0, y: -radius * 3))
                spark.addLine(to: CGPoint(x: radius * 1.0, y: -radius * 0.4))
                spark.addLine(to: CGPoint(x: 0, y: radius * 3))
                spark.addLine(to: CGPoint(x: -radius, y: -radius * 0.2))
                spark.closeSubpath()
                layer.stroke(spark, with: .color(theme.accent.opacity(alpha)), lineWidth: 0.8)

            default:
                layer.fill(Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)), with: .color(theme.accent.opacity(alpha)))
            }
        }
    }

    // MARK: - Deterministic layout

    private func layoutPoint(_ index: Int, size: CGSize) -> CGPoint {
        let columns = 6
        let row = index / columns
        let column = index % columns

        let cellWidth = size.width / CGFloat(columns)
        let cellHeight = max(70, size.height / 8.0)

        let jitterX = CGFloat((index * 37) % 29 - 14)
        let jitterY = CGFloat((index * 53) % 31 - 15)

        return CGPoint(
            x: cellWidth * (CGFloat(column) + 0.5) + jitterX,
            y: cellHeight * (CGFloat(row) + 0.55) + jitterY
        )
    }

    private func animatedDrift(_ index: Int, time: TimeInterval) -> CGSize {
        guard animated else { return .zero }

        return CGSize(
            width: CGFloat(sin(time * 0.42 + Double(index) * 0.73)) * 4.8,
            height: CGFloat(cos(time * 0.37 + Double(index) * 0.61)) * 4.2
        )
    }
}
