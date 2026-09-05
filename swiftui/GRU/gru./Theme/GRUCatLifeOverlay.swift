import SwiftUI

/// Adds life to the approved static artwork without moving the artwork itself.
/// Blinks are short, irregular and theme-tinted; Reduce Motion disables them.
struct GRUCatLifeOverlay: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !animated || reduceMotion)) { timeline in
            GeometryReader { proxy in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let blink = blinkAmount(at: time)
                let pulse = 0.5 + 0.5 * sin(time * 1.15)
                let anchors = eyeAnchors(in: proxy.size)

                ZStack {
                    ForEach(Array(anchors.enumerated()), id: \.offset) { _, pair in
                        blinkPair(
                            left: pair.left,
                            right: pair.right,
                            blink: blink,
                            pulse: pulse
                        )
                    }

                    sparkleLayer(size: proxy.size, time: time)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func blinkAmount(at time: TimeInterval) -> Double {
        // Different cats blink at slightly different-feeling intervals, while
        // keeping the motion deterministic and calm.
        let cycle = 4.6 + Double(theme.rawValue.count % 5) * 0.37
        let phase = time.truncatingRemainder(dividingBy: cycle)
        let first = blinkPulse(phase, center: 0.18)
        let doubleBlink = blinkPulse(phase, center: 0.46) * 0.72
        return min(1, first + doubleBlink)
    }

    private func blinkPulse(_ phase: Double, center: Double) -> Double {
        let width = 0.115
        let distance = abs(phase - center)
        guard distance < width else { return 0 }
        let normalized = 1 - distance / width
        return sin(normalized * .pi / 2)
    }

    @ViewBuilder
    private func blinkPair(
        left: CGPoint,
        right: CGPoint,
        blink: Double,
        pulse: Double
    ) -> some View {
        let eyeWidth = 14.0 + 2.0 * intensity
        let openHeight = 5.2 + 0.8 * pulse
        let closedHeight = 1.2
        let eyeHeight = openHeight * (1 - blink) + closedHeight * blink

        Group {
            eyeGlow(at: left, width: eyeWidth, height: eyeHeight, pulse: pulse)
            eyeGlow(at: right, width: eyeWidth, height: eyeHeight, pulse: pulse)
        }
        .animation(.linear(duration: 0.06), value: blink)
    }

    private func eyeGlow(
        at point: CGPoint,
        width: Double,
        height: Double,
        pulse: Double
    ) -> some View {
        Capsule(style: .continuous)
            .fill(theme.accent.opacity(0.32 + 0.16 * pulse))
            .frame(width: width, height: height)
            .shadow(color: theme.accent.opacity(0.58), radius: 5 + 2 * pulse)
            .position(point)
    }

    @ViewBuilder
    private func sparkleLayer(size: CGSize, time: TimeInterval) -> some View {
        Canvas { context, canvasSize in
            for index in 0..<10 {
                let fx = Double((index * 37 + 17) % 97) / 97.0
                let fy = Double((index * 61 + 23) % 89) / 89.0
                let twinkle = 0.5 + 0.5 * sin(time * (0.8 + Double(index % 3) * 0.17) + Double(index))
                let radius = 0.8 + twinkle * 1.4
                let rect = CGRect(
                    x: canvasSize.width * fx - radius,
                    y: canvasSize.height * fy - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(theme.secondaryAccent.opacity(0.10 + 0.16 * twinkle))
                )
            }
        }
    }

    private func eyeAnchors(in size: CGSize) -> [(left: CGPoint, right: CGPoint)] {
        let normalized: [(CGFloat, CGFloat, CGFloat)]

        switch theme {
        case .blackMoonCat, .midnightGold:
            normalized = [(0.48, 0.43, 0.075)]
        case .neonCatDemon, .electricRose:
            normalized = [(0.50, 0.40, 0.078)]
        case .bloodDragon:
            normalized = [(0.50, 0.43, 0.080)]
        case .forestWitch:
            normalized = [(0.50, 0.42, 0.076)]
        case .cyberMidnight, .cyberMint, .arcticSignal:
            normalized = [(0.50, 0.42, 0.078)]
        case .ultravioletUnicorn, .ultraviolet:
            normalized = [(0.50, 0.43, 0.075)]
        case .powderPrincess:
            normalized = [(0.50, 0.43, 0.072)]
        case .greenAcidMonster, .acidLime:
            normalized = [(0.50, 0.42, 0.080)]
        case .ironKnight:
            normalized = [(0.50, 0.42, 0.074)]
        }

        return normalized.map { centerX, y, spacing in
            (
                left: CGPoint(
                    x: size.width * (centerX - spacing / 2),
                    y: size.height * y
                ),
                right: CGPoint(
                    x: size.width * (centerX + spacing / 2),
                    y: size.height * y
                )
            )
        }
    }
}
