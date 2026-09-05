import SwiftUI

/// Secondary motif layer matching the user-approved preview.
/// Keeps the cats dominant while adding each world's specific visual language.
struct GRUApprovedThemeOverlay: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                    canvas(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                canvas(time: 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func canvas(time: TimeInterval) -> some View {
        Canvas { context, size in
            switch theme {
            case .bloodDragon:
                drawFlames(context: &context, size: size, time: time)
            case .ultravioletUnicorn:
                drawDreamDust(context: &context, size: size, time: time)
            case .neonCatDemon:
                drawDemonRunes(context: &context, size: size, time: time)
            case .forestWitch:
                drawForestMagic(context: &context, size: size, time: time)
            case .cyberMidnight:
                drawCyberCity(context: &context, size: size, time: time)
            case .powderPrincess:
                drawPrincessDecor(context: &context, size: size, time: time)
            case .greenAcidMonster:
                drawAcidDecor(context: &context, size: size, time: time)
            case .ironKnight:
                drawKnightDecor(context: &context, size: size, time: time)
            case .blackMoonCat:
                drawGoldenMoon(context: &context, size: size, time: time)
            default:
                break
            }
        }
    }

    private func drawFlames(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for i in 0..<14 {
            let p = point(i, size: size, salt: 11)
            let flicker = CGFloat(0.75 + 0.25 * sin(time * 2.1 + Double(i)))
            var flame = Path()
            flame.move(to: CGPoint(x: p.x, y: p.y + 7))
            flame.addQuadCurve(to: CGPoint(x: p.x - 5, y: p.y - 2), control: CGPoint(x: p.x - 8, y: p.y + 2))
            flame.addQuadCurve(to: CGPoint(x: p.x, y: p.y - 10 * flicker), control: CGPoint(x: p.x - 2, y: p.y - 5))
            flame.addQuadCurve(to: CGPoint(x: p.x + 5, y: p.y - 2), control: CGPoint(x: p.x + 7, y: p.y - 5))
            flame.addQuadCurve(to: CGPoint(x: p.x, y: p.y + 7), control: CGPoint(x: p.x + 7, y: p.y + 4))
            context.stroke(flame, with: .color(theme.accent.opacity(0.42 * intensity)), lineWidth: 1.2)
        }
        sparkleField(context: &context, size: size, time: time, count: 26)
    }

    private func drawDreamDust(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        sparkleField(context: &context, size: size, time: time, count: 38)
        for i in 0..<8 {
            let p = point(i, size: size, salt: 23)
            var cloud = Path()
            cloud.addEllipse(in: CGRect(x: p.x - 8, y: p.y - 2, width: 10, height: 7))
            cloud.addEllipse(in: CGRect(x: p.x - 2, y: p.y - 5, width: 12, height: 10))
            cloud.addEllipse(in: CGRect(x: p.x + 5, y: p.y - 1, width: 9, height: 7))
            context.stroke(cloud, with: .color(theme.secondaryAccent.opacity(0.28 * intensity)), lineWidth: 1)
        }
    }

    private func drawDemonRunes(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for i in 0..<18 {
            let p = point(i, size: size, salt: 31)
            let pulse = CGFloat(0.55 + 0.45 * sin(time * 1.6 + Double(i)))
            var rune = Path()
            rune.move(to: CGPoint(x: p.x - 4, y: p.y))
            rune.addLine(to: CGPoint(x: p.x + 4, y: p.y))
            rune.move(to: CGPoint(x: p.x, y: p.y - 4))
            rune.addLine(to: CGPoint(x: p.x, y: p.y + 4))
            if i.isMultiple(of: 3) {
                rune.move(to: CGPoint(x: p.x - 3, y: p.y - 3))
                rune.addLine(to: CGPoint(x: p.x + 3, y: p.y + 3))
            }
            context.stroke(rune, with: .color(theme.accent.opacity((0.22 + 0.28 * pulse) * intensity)), lineWidth: 1.1)
        }
        sparkleField(context: &context, size: size, time: time, count: 20)
    }

    private func drawForestMagic(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for i in 0..<15 {
            let p = point(i, size: size, salt: 43)
            var stem = Path()
            stem.move(to: CGPoint(x: p.x, y: p.y + 7))
            stem.addQuadCurve(to: CGPoint(x: p.x + 1, y: p.y - 7), control: CGPoint(x: p.x - 3, y: p.y))
            stem.move(to: CGPoint(x: p.x, y: p.y))
            stem.addQuadCurve(to: CGPoint(x: p.x - 6, y: p.y - 3), control: CGPoint(x: p.x - 4, y: p.y - 1))
            stem.move(to: CGPoint(x: p.x, y: p.y - 2))
            stem.addQuadCurve(to: CGPoint(x: p.x + 6, y: p.y - 6), control: CGPoint(x: p.x + 4, y: p.y - 4))
            context.stroke(stem, with: .color(theme.accent.opacity(0.32 * intensity)), lineWidth: 1)
        }
        sparkleField(context: &context, size: size, time: time, count: 18)
    }

    private func drawCyberCity(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let baseline = size.height * 0.82
        var city = Path()
        var x: CGFloat = 0
        var i = 0
        while x < size.width {
            let w = CGFloat(14 + (i * 11) % 24)
            let h = CGFloat(18 + (i * 17) % 56)
            city.addRect(CGRect(x: x, y: baseline - h, width: w, height: h))
            x += w + 4
            i += 1
        }
        context.stroke(city, with: .color(theme.accent.opacity(0.24 * intensity)), lineWidth: 1)

        let scanY = CGFloat((time.truncatingRemainder(dividingBy: 3.0)) / 3.0) * size.height
        var scan = Path()
        scan.move(to: CGPoint(x: 0, y: scanY))
        scan.addLine(to: CGPoint(x: size.width, y: scanY))
        context.stroke(scan, with: .color(theme.secondaryAccent.opacity(0.22 * intensity)), lineWidth: 1)
        sparkleField(context: &context, size: size, time: time, count: 24)
    }

    private func drawPrincessDecor(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for i in 0..<18 {
            let p = point(i, size: size, salt: 59)
            if i.isMultiple(of: 2) {
                var heart = Path()
                heart.move(to: CGPoint(x: p.x, y: p.y + 4))
                heart.addCurve(to: CGPoint(x: p.x - 6, y: p.y - 1), control1: CGPoint(x: p.x - 2, y: p.y + 1), control2: CGPoint(x: p.x - 7, y: p.y + 1))
                heart.addCurve(to: CGPoint(x: p.x, y: p.y - 6), control1: CGPoint(x: p.x - 6, y: p.y - 6), control2: CGPoint(x: p.x - 2, y: p.y - 6))
                heart.addCurve(to: CGPoint(x: p.x + 6, y: p.y - 1), control1: CGPoint(x: p.x + 2, y: p.y - 6), control2: CGPoint(x: p.x + 6, y: p.y - 6))
                heart.addCurve(to: CGPoint(x: p.x, y: p.y + 4), control1: CGPoint(x: p.x + 7, y: p.y + 1), control2: CGPoint(x: p.x + 2, y: p.y + 1))
                context.stroke(heart, with: .color(theme.accent.opacity(0.34 * intensity)), lineWidth: 1)
            }
        }
        sparkleField(context: &context, size: size, time: time, count: 28)
    }

    private func drawAcidDecor(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for i in 0..<20 {
            let p = point(i, size: size, salt: 71)
            let bob = CGFloat(sin(time + Double(i)) * 3)
            var drop = Path()
            drop.addEllipse(in: CGRect(x: p.x - 2, y: p.y - 2 + bob, width: 4, height: 6))
            context.fill(drop, with: .color(theme.accent.opacity(0.28 * intensity)))
        }
        sparkleField(context: &context, size: size, time: time, count: 16)
    }

    private func drawKnightDecor(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for i in 0..<12 {
            let p = point(i, size: size, salt: 83)
            var sword = Path()
            sword.move(to: CGPoint(x: p.x - 5, y: p.y + 7))
            sword.addLine(to: CGPoint(x: p.x + 5, y: p.y - 7))
            sword.move(to: CGPoint(x: p.x - 2, y: p.y + 1))
            sword.addLine(to: CGPoint(x: p.x + 3, y: p.y + 5))
            context.stroke(sword, with: .color(theme.accent.opacity(0.28 * intensity)), lineWidth: 1.1)
        }
        sparkleField(context: &context, size: size, time: time, count: 15)
    }

    private func drawGoldenMoon(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let center = CGPoint(x: size.width * 0.76, y: size.height * 0.26)
        let radius = min(size.width, size.height) * 0.12

        var moon = Path()
        moon.addArc(center: center, radius: radius, startAngle: .degrees(55), endAngle: .degrees(305), clockwise: false)
        context.stroke(moon, with: .color(theme.accent.opacity(0.62 * intensity)), lineWidth: 2.2)

        for i in 0..<28 {
            let p = point(i, size: size, salt: 97)
            let twinkle = 0.30 + 0.32 * (0.5 + 0.5 * sin(time * 1.4 + Double(i)))
            var star = Path()
            star.move(to: CGPoint(x: p.x - 3, y: p.y))
            star.addLine(to: CGPoint(x: p.x + 3, y: p.y))
            star.move(to: CGPoint(x: p.x, y: p.y - 3))
            star.addLine(to: CGPoint(x: p.x, y: p.y + 3))
            context.stroke(star, with: .color(theme.accent.opacity(twinkle * intensity)), lineWidth: 1)
        }
    }

    private func sparkleField(context: inout GraphicsContext, size: CGSize, time: TimeInterval, count: Int) {
        for i in 0..<count {
            let p = point(i, size: size, salt: 101)
            let alpha = 0.16 + 0.20 * (0.5 + 0.5 * sin(time * 1.2 + Double(i)))
            var s = Path()
            s.move(to: CGPoint(x: p.x - 2, y: p.y))
            s.addLine(to: CGPoint(x: p.x + 2, y: p.y))
            s.move(to: CGPoint(x: p.x, y: p.y - 2))
            s.addLine(to: CGPoint(x: p.x, y: p.y + 2))
            context.stroke(s, with: .color(theme.secondaryAccent.opacity(alpha * intensity)), lineWidth: 0.8)
        }
    }

    private func point(_ index: Int, size: CGSize, salt: Int) -> CGPoint {
        let xSeed = Double((index * 47 + salt * 19) % 997) / 997.0
        let ySeed = Double((index * 83 + salt * 29) % 991) / 991.0
        return CGPoint(
            x: CGFloat(0.05 + xSeed * 0.90) * size.width,
            y: CGFloat(0.05 + ySeed * 0.90) * size.height
        )
    }
}