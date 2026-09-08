import SwiftUI

/// Lightweight full-screen micro-art layer used on top of the illustrated
/// wallpaper. The motion is deliberately tiny: the drawings stay readable,
/// while the screen feels alive instead of behaving like a moving poster.
struct GRUMicroDoodleOverlay: View {
    let theme: GRUAppTheme
    var intensity: Double = 1.0
    var animated = true

    var body: some View {
        Group {
            if animated {
                TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { context in
                    GeometryReader { proxy in
                        field(
                            size: proxy.size,
                            phase: context.date.timeIntervalSinceReferenceDate
                        )
                    }
                }
            } else {
                GeometryReader { proxy in
                    field(size: proxy.size, phase: 0)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func field(size: CGSize, phase: Double) -> some View {
        ZStack {
            ForEach(0..<20, id: \.self) { index in
                let point = point(index, in: size, salt: 11)
                let drift = drift(index, phase: phase)
                let pulse = pulse(index, phase: phase)
                let scale = 0.92 + pulse * 0.10
                let opacity = (0.10 + pulse * 0.14) * intensity

                creature(index: index, opacity: opacity)
                    .frame(
                        width: CGFloat(25 + (index % 5) * 4),
                        height: CGFloat(21 + (index % 4) * 4)
                    )
                    .scaleEffect(scale)
                    .rotationEffect(
                        .degrees(
                            Double((index * 13) % 9 - 4)
                                + sin(phase * 0.36 + Double(index)) * 1.8
                        )
                    )
                    .position(
                        x: point.x + drift.width,
                        y: point.y + drift.height
                    )
            }

            ForEach(0..<24, id: \.self) { index in
                let point = point(index, in: size, salt: 47)
                let shimmer = pulse(index, phase: phase * 1.35)

                Image(systemName: decorationSymbols[index % decorationSymbols.count])
                    .font(
                        .system(
                            size: CGFloat(6 + (index % 4) * 2),
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        (index.isMultiple(of: 2) ? theme.accent : theme.secondaryAccent)
                            .opacity((0.035 + shimmer * 0.10) * intensity)
                    )
                    .rotationEffect(.degrees(Double((index * 19) % 34) - 17))
                    .position(point)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private func creature(index: Int, opacity: Double) -> some View {
        let color = index.isMultiple(of: 3) ? theme.secondaryAccent : theme.accent
        let style = StrokeStyle(
            lineWidth: 1.15,
            lineCap: .round,
            lineJoin: .round
        )

        switch theme {
        case .bloodDragon:
            GRUFoldEarCatDragonDoodle()
                .stroke(color.opacity(opacity), style: style)
                .shadow(color: theme.accent.opacity(opacity * 0.65), radius: 3)

        case .ultravioletUnicorn:
            GRUCaticornDoodle()
                .stroke(color.opacity(opacity), style: style)
                .shadow(color: theme.accent.opacity(opacity * 0.55), radius: 3)

        default:
            GRUMiniCatDoodle()
                .stroke(color.opacity(opacity), style: style)
                .shadow(color: theme.accent.opacity(opacity * 0.40), radius: 2)
        }
    }

    private var decorationSymbols: [String] {
        switch theme {
        case .bloodDragon:
            return ["flame.fill", "sparkles", "star.fill", "flame.fill"]
        case .ultravioletUnicorn:
            return ["sparkles", "star.fill", "cloud.fill", "sparkles"]
        case .blackMoonCat:
            return ["moon.fill", "star.fill", "sparkles"]
        case .forestWitch:
            return ["leaf.fill", "moon.fill", "sparkles"]
        case .cyberMidnight:
            return ["plus", "bolt.fill", "square.fill"]
        case .powderPrincess:
            return ["heart.fill", "star.fill", "crown.fill"]
        case .greenAcidMonster:
            return ["drop.fill", "sparkles", "circle.fill"]
        case .ironKnight:
            return ["shield.fill", "sparkles", "diamond.fill"]
        case .neonCatDemon:
            return ["sparkles", "flame.fill", "plus"]
        default:
            return ["sparkles", "star.fill", "circle.fill"]
        }
    }

    private func point(_ index: Int, in size: CGSize, salt: Int) -> CGPoint {
        let margin: CGFloat = 18
        let usableWidth = max(1, size.width - margin * 2)
        let usableHeight = max(1, size.height - margin * 2)

        let xSeed = CGFloat((index * 53 + salt * 29 + 7) % 101) / 100
        let ySeed = CGFloat((index * 71 + salt * 17 + 23) % 103) / 102

        return CGPoint(
            x: margin + xSeed * usableWidth,
            y: margin + ySeed * usableHeight
        )
    }

    private func drift(_ index: Int, phase: Double) -> CGSize {
        let amount = CGFloat(2.4 + Double(index % 4) * 0.55)

        return CGSize(
            width: CGFloat(sin(phase * 0.34 + Double(index) * 0.71)) * amount,
            height: CGFloat(cos(phase * 0.29 + Double(index) * 0.47)) * amount
        )
    }

    private func pulse(_ index: Int, phase: Double) -> Double {
        (sin(phase + Double(index) * 0.83) + 1) * 0.5
    }
}

/// Minimal average cat silhouette for non-character themes.
private struct GRUMiniCatDoodle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.18, y: h * 0.40))
        path.addLine(to: CGPoint(x: w * 0.14, y: h * 0.12))
        path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.25))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.66, y: h * 0.25),
            control: CGPoint(x: w * 0.50, y: h * 0.16)
        )
        path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.12))
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.40))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.88),
            control: CGPoint(x: w * 0.90, y: h * 0.76)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.18, y: h * 0.40),
            control: CGPoint(x: w * 0.10, y: h * 0.76)
        )

        path.move(to: CGPoint(x: w * 0.32, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.39, y: h * 0.48))
        path.move(to: CGPoint(x: w * 0.61, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.50))
        path.move(to: CGPoint(x: w * 0.45, y: h * 0.66))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.66),
            control: CGPoint(x: w * 0.50, y: h * 0.71)
        )

        return path
    }
}

/// Fold-eared cat + tiny dragon wing/tail. Kept deliberately icon-like so
/// many of them can live across the wallpaper without becoming noisy.
private struct GRUFoldEarCatDragonDoodle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Fold-eared cat head.
        path.move(to: CGPoint(x: w * 0.16, y: h * 0.44))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.28, y: h * 0.26),
            control: CGPoint(x: w * 0.12, y: h * 0.28)
        )
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.16))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.38, y: h * 0.26),
            control: CGPoint(x: w * 0.23, y: h * 0.31)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.62, y: h * 0.26),
            control: CGPoint(x: w * 0.50, y: h * 0.18)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.16),
            control: CGPoint(x: w * 0.77, y: h * 0.31)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.84, y: h * 0.44),
            control: CGPoint(x: w * 0.88, y: h * 0.28)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.72),
            control: CGPoint(x: w * 0.78, y: h * 0.76)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.16, y: h * 0.44),
            control: CGPoint(x: w * 0.22, y: h * 0.76)
        )

        // Eyes and tiny muzzle.
        path.move(to: CGPoint(x: w * 0.31, y: h * 0.46))
        path.addLine(to: CGPoint(x: w * 0.39, y: h * 0.44))
        path.move(to: CGPoint(x: w * 0.61, y: h * 0.44))
        path.addLine(to: CGPoint(x: w * 0.69, y: h * 0.46))
        path.move(to: CGPoint(x: w * 0.46, y: h * 0.58))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.54, y: h * 0.58),
            control: CGPoint(x: w * 0.50, y: h * 0.63)
        )

        // Small dragon wing.
        path.move(to: CGPoint(x: w * 0.72, y: h * 0.66))
        path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.54))
        path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.74))
        path.addLine(to: CGPoint(x: w * 0.98, y: h * 0.82))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.70, y: h * 0.73),
            control: CGPoint(x: w * 0.88, y: h * 0.88)
        )

        // Curled dragon tail.
        path.move(to: CGPoint(x: w * 0.29, y: h * 0.70))
        path.addCurve(
            to: CGPoint(x: w * 0.06, y: h * 0.82),
            control1: CGPoint(x: w * 0.17, y: h * 0.76),
            control2: CGPoint(x: w * 0.09, y: h * 0.68)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.13, y: h * 0.94),
            control: CGPoint(x: w * 0.01, y: h * 0.90)
        )

        return path
    }
}

/// Cat face with a compact unicorn horn and a curved little mane.
private struct GRUCaticornDoodle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = GRUMiniCatDoodle().path(in: rect)
        let w = rect.width
        let h = rect.height

        // Horn.
        path.move(to: CGPoint(x: w * 0.46, y: h * 0.23))
        path.addLine(to: CGPoint(x: w * 0.53, y: 0))
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.24))

        // Tiny mane curl.
        path.move(to: CGPoint(x: w * 0.76, y: h * 0.34))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.92, y: h * 0.50),
            control: CGPoint(x: w * 0.96, y: h * 0.30)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.62),
            control: CGPoint(x: w * 0.98, y: h * 0.63)
        )

        return path
    }
}
