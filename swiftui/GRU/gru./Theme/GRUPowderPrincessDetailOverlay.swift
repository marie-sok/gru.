import SwiftUI

/// Powder Princess motion layer.
/// The cat artwork itself never moves. Only tiny decorative elements animate:
/// clouds drift by a few points, hearts softly pulse, crystals shimmer,
/// crowns glow and stars twinkle.
struct GRUPowderPrincessDetailOverlay: View {
    var intensity: Double = 1
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
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
            drawClouds(context: &context, size: size, time: time)
            drawHearts(context: &context, size: size, time: time)
            drawCrystals(context: &context, size: size, time: time)
            drawCrowns(context: &context, size: size, time: time)
            drawSparkles(context: &context, size: size, time: time)
        }
    }

    private var hotPink: Color {
        Color(red: 1.00, green: 0.26, blue: 0.58)
    }

    private var powderLight: Color {
        Color(red: 1.00, green: 0.82, blue: 0.90)
    }

    private func drawClouds(
        context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        for index in 0..<8 {
            let p = point(index, size: size, salt: 41)
            let driftX = CGFloat(sin(time * 0.20 + Double(index) * 0.73)) * 2.4
            let driftY = CGFloat(cos(time * 0.18 + Double(index) * 0.61)) * 1.8
            let alpha = 0.055 + 0.025 * (0.5 + 0.5 * sin(time * 0.55 + Double(index)))

            var cloud = Path()
            cloud.addEllipse(in: CGRect(x: p.x - 10 + driftX, y: p.y - 2 + driftY, width: 12, height: 8))
            cloud.addEllipse(in: CGRect(x: p.x - 3 + driftX, y: p.y - 7 + driftY, width: 15, height: 13))
            cloud.addEllipse(in: CGRect(x: p.x + 7 + driftX, y: p.y - 2 + driftY, width: 11, height: 8))

            context.stroke(
                cloud,
                with: .color(powderLight.opacity(alpha * intensity)),
                lineWidth: 0.9
            )
        }
    }

    private func drawHearts(
        context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        for index in 0..<12 {
            let p = point(index, size: size, salt: 59)
            let pulse = CGFloat(0.92 + 0.08 * (0.5 + 0.5 * sin(time * 0.82 + Double(index))))
            let bob = CGFloat(sin(time * 0.33 + Double(index)) * 1.8)
            let r: CGFloat = 4.3 * pulse

            var heart = Path()
            heart.move(to: CGPoint(x: p.x, y: p.y + r + bob))
            heart.addCurve(
                to: CGPoint(x: p.x - r, y: p.y - bob),
                control1: CGPoint(x: p.x - r * 0.20, y: p.y + r * 0.52 + bob),
                control2: CGPoint(x: p.x - r * 1.15, y: p.y + r * 0.38 + bob)
            )
            heart.addCurve(
                to: CGPoint(x: p.x, y: p.y - r * 0.72 + bob),
                control1: CGPoint(x: p.x - r, y: p.y - r * 0.72 + bob),
                control2: CGPoint(x: p.x - r * 0.28, y: p.y - r * 0.72 + bob)
            )
            heart.addCurve(
                to: CGPoint(x: p.x + r, y: p.y + bob),
                control1: CGPoint(x: p.x + r * 0.28, y: p.y - r * 0.72 + bob),
                control2: CGPoint(x: p.x + r, y: p.y - r * 0.72 + bob)
            )
            heart.addCurve(
                to: CGPoint(x: p.x, y: p.y + r + bob),
                control1: CGPoint(x: p.x + r * 1.15, y: p.y + r * 0.38 + bob),
                control2: CGPoint(x: p.x + r * 0.20, y: p.y + r * 0.52 + bob)
            )

            context.stroke(
                heart,
                with: .color(hotPink.opacity((0.10 + 0.08 * Double(pulse)) * intensity)),
                lineWidth: 0.9
            )
        }
    }

    private func drawCrystals(
        context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        for index in 0..<9 {
            let p = point(index, size: size, salt: 73)
            let shimmer = 0.5 + 0.5 * sin(time * 1.15 + Double(index) * 0.91)
            let bob = CGFloat(cos(time * 0.29 + Double(index)) * 2.0)

            var crystal = Path()
            crystal.move(to: CGPoint(x: p.x, y: p.y - 7 + bob))
            crystal.addLine(to: CGPoint(x: p.x + 4, y: p.y - 1 + bob))
            crystal.addLine(to: CGPoint(x: p.x + 1, y: p.y + 7 + bob))
            crystal.addLine(to: CGPoint(x: p.x - 4, y: p.y - 1 + bob))
            crystal.closeSubpath()
            crystal.move(to: CGPoint(x: p.x, y: p.y - 7 + bob))
            crystal.addLine(to: CGPoint(x: p.x, y: p.y + 7 + bob))

            context.stroke(
                crystal,
                with: .color(powderLight.opacity((0.10 + 0.17 * shimmer) * intensity)),
                lineWidth: 0.85
            )
        }
    }

    private func drawCrowns(
        context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        for index in 0..<6 {
            let p = point(index, size: size, salt: 89)
            let glow = 0.5 + 0.5 * sin(time * 0.72 + Double(index) * 1.27)
            let bob = CGFloat(sin(time * 0.24 + Double(index)) * 1.4)

            var crown = Path()
            crown.move(to: CGPoint(x: p.x - 7, y: p.y + 4 + bob))
            crown.addLine(to: CGPoint(x: p.x - 5, y: p.y - 4 + bob))
            crown.addLine(to: CGPoint(x: p.x, y: p.y + 1 + bob))
            crown.addLine(to: CGPoint(x: p.x + 5, y: p.y - 4 + bob))
            crown.addLine(to: CGPoint(x: p.x + 7, y: p.y + 4 + bob))
            crown.closeSubpath()

            context.stroke(
                crown,
                with: .color(hotPink.opacity((0.10 + 0.15 * glow) * intensity)),
                lineWidth: 0.95
            )
        }
    }

    private func drawSparkles(
        context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        for index in 0..<28 {
            let p = point(index, size: size, salt: 107)
            let twinkle = 0.5 + 0.5 * sin(time * (0.75 + Double(index % 4) * 0.11) + Double(index))
            let length = CGFloat(1.6 + twinkle * 1.8)

            var sparkle = Path()
            sparkle.move(to: CGPoint(x: p.x - length, y: p.y))
            sparkle.addLine(to: CGPoint(x: p.x + length, y: p.y))
            sparkle.move(to: CGPoint(x: p.x, y: p.y - length))
            sparkle.addLine(to: CGPoint(x: p.x, y: p.y + length))

            context.stroke(
                sparkle,
                with: .color(powderLight.opacity((0.08 + 0.20 * twinkle) * intensity)),
                lineWidth: 0.75
            )
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
