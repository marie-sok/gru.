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
                let pulse = 0.5 + 0.5 * sin(time * 1.15)
                let anchors = eyeAnchors(in: proxy.size)

                ZStack {
                    ForEach(Array(anchors.enumerated()), id: \.offset) { index, pair in
                        let blink = blinkAmount(at: time, index: index)
                        blinkPair(
                            left: pair.left,
                            right: pair.right,
                            blink: blink,
                            pulse: pulse,
                            scale: pair.scale
                        )
                    }

                    if theme == .powderPrincess {
                        powderPrincessExpressionLayer(
                            size: proxy.size,
                            time: time,
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

    private func blinkAmount(at time: TimeInterval, index: Int) -> Double {
        let baseCycle = 4.4 + Double(theme.rawValue.count % 5) * 0.31
        let cycle = baseCycle + Double(index % 4) * 0.53
        let phaseShift = Double(index) * 0.71
        let phase = (time + phaseShift).truncatingRemainder(dividingBy: cycle)

        let first = blinkPulse(phase, center: 0.18)
        let doubleBlink = blinkPulse(phase, center: 0.46) * 0.68
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
        pulse: Double,
        scale: CGFloat
    ) -> some View {
        let eyeWidth = (14.0 + 2.0 * intensity) * scale
        let openHeight = (5.2 + 0.8 * pulse) * scale
        let closedHeight = max(0.8, 1.2 * scale)
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
            .fill(theme.accent.opacity(0.28 + 0.14 * pulse))
            .frame(width: width, height: height)
            .shadow(color: theme.accent.opacity(0.52), radius: 4 + 2 * pulse)
            .position(point)
    }

    @ViewBuilder
    private func powderPrincessExpressionLayer(
        size: CGSize,
        time: TimeInterval,
        pulse: Double
    ) -> some View {
        let expression = 0.5 + 0.5 * sin(time * 0.72)
        let mainFace = CGPoint(x: size.width * 0.69, y: size.height * 0.62)
        let bow = CGPoint(x: size.width * 0.66, y: size.height * 0.69)

        ZStack {
            // Soft cheek expression: visible enough to feel alive, subtle enough
            // to preserve the original drawing.
            Circle()
                .fill(theme.accent.opacity(0.035 + 0.035 * expression))
                .frame(width: size.width * 0.055, height: size.width * 0.055)
                .blur(radius: 5)
                .position(x: mainFace.x - size.width * 0.043, y: mainFace.y + size.height * 0.018)

            Circle()
                .fill(theme.accent.opacity(0.035 + 0.035 * expression))
                .frame(width: size.width * 0.055, height: size.width * 0.055)
                .blur(radius: 5)
                .position(x: mainFace.x + size.width * 0.043, y: mainFace.y + size.height * 0.018)

            // Tiny smile accent gently changes with the face pulse.
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.16 + 0.12 * expression))
                .frame(width: size.width * 0.030, height: 1.2 + 0.8 * expression)
                .rotationEffect(.degrees(expression > 0.55 ? 7 : -4))
                .position(x: mainFace.x, y: mainFace.y + size.height * 0.031)

            // Bow sparkle makes the pose feel alive without moving the cat body.
            Image(systemName: "sparkle")
                .font(.system(size: max(8, size.width * 0.026), weight: .semibold))
                .foregroundStyle(theme.secondaryAccent.opacity(0.24 + 0.32 * pulse))
                .scaleEffect(0.88 + 0.16 * pulse)
                .position(bow)
        }
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

    private func eyeAnchors(in size: CGSize) -> [(left: CGPoint, right: CGPoint, scale: CGFloat)] {
        let normalized: [(CGFloat, CGFloat, CGFloat, CGFloat)]

        switch theme {
        case .blackMoonCat, .midnightGold:
            normalized = [(0.48, 0.43, 0.075, 1.0)]
        case .neonCatDemon, .electricRose:
            normalized = [(0.50, 0.40, 0.078, 1.0)]
        case .bloodDragon:
            normalized = [(0.50, 0.43, 0.080, 1.0)]
        case .forestWitch:
            normalized = [(0.50, 0.42, 0.076, 1.0)]
        case .cyberMidnight, .cyberMint, .arcticSignal:
            normalized = [(0.50, 0.42, 0.078, 1.0)]
        case .ultravioletUnicorn, .ultraviolet:
            normalized = [(0.50, 0.43, 0.075, 1.0)]
        case .powderPrincess:
            // New Powder Princess art: one main princess and several smaller
            // kittens around the frame. Each pair blinks on its own cadence.
            normalized = [
                (0.69, 0.605, 0.073, 1.00),
                (0.245, 0.105, 0.046, 0.60),
                (0.780, 0.122, 0.045, 0.58),
                (0.115, 0.285, 0.044, 0.56),
                (0.225, 0.450, 0.043, 0.55),
                (0.120, 0.715, 0.045, 0.57),
                (0.470, 0.895, 0.044, 0.56),
                (0.780, 0.900, 0.044, 0.56)
            ]
        case .greenAcidMonster, .acidLime:
            normalized = [(0.50, 0.42, 0.080, 1.0)]
        case .ironKnight:
            normalized = [(0.50, 0.42, 0.074, 1.0)]
        }

        return normalized.map { centerX, y, spacing, scale in
            (
                left: CGPoint(
                    x: size.width * (centerX - spacing / 2),
                    y: size.height * y
                ),
                right: CGPoint(
                    x: size.width * (centerX + spacing / 2),
                    y: size.height * y
                ),
                scale: scale
            )
        }
    }
}
