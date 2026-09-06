import SwiftUI

struct GRUAnimatedThemeScene: View {
    let theme: GRUAppTheme
    var intensity: Double = 1.0
    var animated = true

    @ViewBuilder
    var body: some View {
        if animated {
            TimelineView(.animation) { context in
                GeometryReader { proxy in
                    scene(
                        size: proxy.size,
                        phase: context.date.timeIntervalSinceReferenceDate
                    )
                }
            }
        } else {
            GeometryReader { proxy in
                scene(size: proxy.size, phase: 0)
            }
        }
    }

    private func scene(size: CGSize, phase: Double) -> some View {
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

            ambientGlow(size: size, phase: phase)

            switch theme {
            case .blackMoonCat:
                blackMoonCat(size: size, phase: phase)
            case .neonCatDemon:
                neonDemonCat(size: size, phase: phase)
            case .bloodDragon:
                bloodDragon(size: size, phase: phase)
            case .forestWitch:
                forestWitch(size: size, phase: phase)
            case .cyberMidnight:
                cyberMidnight(size: size, phase: phase)
            case .ultravioletUnicorn:
                ultravioletUnicorn(size: size, phase: phase)
            case .powderPrincess:
                powderPrincess(size: size, phase: phase)
            case .greenAcidMonster:
                greenAcidMonster(size: size, phase: phase)
            case .ironKnight:
                ironKnight(size: size, phase: phase)
            default:
                legacyPattern(size: size, phase: phase)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    .clear,
                    Color.black.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .clipped()
    }

    private func ambientGlow(size: CGSize, phase: Double) -> some View {
        ZStack {
            Circle()
                .fill(theme.accent.opacity(0.11 * intensity))
                .frame(width: max(180, size.width * 0.72))
                .blur(radius: 72)
                .offset(
                    x: size.width * 0.28 + CGFloat(sin(phase * 0.18)) * 20,
                    y: -size.height * 0.26 + CGFloat(cos(phase * 0.14)) * 18
                )

            Circle()
                .fill(theme.secondaryAccent.opacity(0.08 * intensity))
                .frame(width: max(160, size.width * 0.62))
                .blur(radius: 78)
                .offset(
                    x: -size.width * 0.28 + CGFloat(cos(phase * 0.15)) * 18,
                    y: size.height * 0.30 + CGFloat(sin(phase * 0.17)) * 18
                )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Black Moon Cat

    private func blackMoonCat(size: CGSize, phase: Double) -> some View {
        ZStack {
            ForEach(0..<22, id: \.self) { index in
                let p = point(index, in: size, salt: 3)
                let drift = drift(index, phase: phase, amount: 7)

                if index % 3 == 0 {
                    MoonCycleGlyph(stage: index % 8)
                        .stroke(
                            Color.white.opacity(0.16 * intensity),
                            style: StrokeStyle(lineWidth: 1.25, lineCap: .round)
                        )
                        .frame(width: CGFloat(18 + index % 4 * 5), height: CGFloat(18 + index % 4 * 5))
                        .position(x: p.x + drift.width, y: p.y + drift.height)
                } else if index % 3 == 1 {
                    CatFaceGlyph()
                        .stroke(
                            theme.accent.opacity((0.10 + 0.06 * glow(index, phase: phase)) * intensity),
                            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: CGFloat(24 + index % 5 * 4), height: CGFloat(21 + index % 5 * 4))
                        .shadow(color: theme.accent.opacity(0.12 * intensity), radius: 6)
                        .position(x: p.x + drift.width, y: p.y + drift.height)
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: CGFloat(10 + index % 4 * 3), weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.07 * intensity))
                        .position(x: p.x + drift.width, y: p.y + drift.height)
                }
            }

            ForEach(0..<26, id: \.self) { index in
                let p = point(index, in: size, salt: 37)
                Circle()
                    .fill(Color.white.opacity((0.045 + 0.08 * glow(index, phase: phase * 1.7)) * intensity))
                    .frame(width: CGFloat(1 + index % 3), height: CGFloat(1 + index % 3))
                    .position(p)
            }
        }
    }

    // MARK: - Neon Demon Cat

    private func neonDemonCat(size: CGSize, phase: Double) -> some View {
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                let p = point(index, in: size, salt: 19)
                let drift = drift(index, phase: phase * 1.15, amount: 9)
                let pulse = glow(index, phase: phase * 2.0)

                ZStack {
                    Circle()
                        .trim(from: 0.04, to: 0.92)
                        .stroke(
                            theme.accent.opacity((0.07 + 0.24 * pulse) * intensity),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(phase * 24 + Double(index * 29)))
                        .scaleEffect(1.0 + pulse * 0.18)

                    DemonCatGlyph(laugh: pulse)
                        .stroke(
                            theme.accent.opacity((0.17 + 0.22 * pulse) * intensity),
                            style: StrokeStyle(lineWidth: 1.55, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: theme.accent.opacity((0.16 + 0.32 * pulse) * intensity), radius: 8)
                        .scaleEffect(x: 1.0 + pulse * 0.05, y: 1.0 - pulse * 0.03)
                        .rotationEffect(.degrees(sin(phase * 4 + Double(index)) * 2.2))
                }
                .frame(width: CGFloat(30 + index % 4 * 7), height: CGFloat(30 + index % 4 * 7))
                .position(x: p.x + drift.width, y: p.y + drift.height)
            }

            ForEach(0..<22, id: \.self) { index in
                let p = point(index, in: size, salt: 51)
                Image(systemName: index.isMultiple(of: 3) ? "sparkles" : "plus")
                    .font(.system(size: CGFloat(8 + index % 3 * 3), weight: .bold))
                    .foregroundStyle(
                        (index.isMultiple(of: 2) ? theme.accent : theme.secondaryAccent)
                            .opacity((0.05 + 0.16 * glow(index, phase: phase * 1.6)) * intensity)
                    )
                    .position(p)
            }
        }
    }

    // MARK: - Blood Dragon

    private func bloodDragon(size: CGSize, phase: Double) -> some View {
        ZStack {
            ForEach(0..<11, id: \.self) { index in
                let p = point(index, in: size, salt: 7)
                let drift = drift(index, phase: phase * 0.48, amount: 13)

                DragonGlyph()
                    .stroke(
                        theme.accent.opacity((0.10 + 0.12 * glow(index, phase: phase)) * intensity),
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: CGFloat(56 + index % 3 * 18), height: CGFloat(34 + index % 3 * 10))
                    .rotationEffect(.degrees(Double((index * 31) % 46) - 23 + sin(phase * 0.5 + Double(index)) * 4))
                    .shadow(color: theme.accent.opacity(0.15 * intensity), radius: 7)
                    .position(x: p.x + drift.width, y: p.y + drift.height)
            }

            ForEach(0..<24, id: \.self) { index in
                let p = point(index, in: size, salt: 73)
                Image(systemName: index % 4 == 0 ? "flame.fill" : "sparkles")
                    .font(.system(size: CGFloat(7 + index % 4 * 2), weight: .medium))
                    .foregroundStyle(theme.secondaryAccent.opacity((0.04 + 0.14 * glow(index, phase: phase * 1.8)) * intensity))
                    .offset(y: CGFloat(-phase.truncatingRemainder(dividingBy: 18)))
                    .position(p)
            }
        }
    }

    // MARK: - Forest Witch

    private func forestWitch(size: CGSize, phase: Double) -> some View {
        ZStack {
            ForEach(0..<21, id: \.self) { index in
                let p = point(index, in: size, salt: 13)
                let drift = drift(index, phase: phase * 0.38, amount: 5)
                let pulse = glow(index, phase: phase * 1.2)

                Group {
                    switch index % 4 {
                    case 0:
                        RuneGlyph(variant: index % 5)
                            .stroke(theme.accent.opacity((0.09 + 0.15 * pulse) * intensity), lineWidth: 1.25)
                    case 1:
                        WitchHatGlyph()
                            .stroke(theme.secondaryAccent.opacity((0.09 + 0.10 * pulse) * intensity), lineWidth: 1.25)
                    case 2:
                        CauldronGlyph(steam: sin(phase * 1.4 + Double(index)))
                            .stroke(theme.accent.opacity((0.10 + 0.13 * pulse) * intensity), style: StrokeStyle(lineWidth: 1.25, lineCap: .round))
                    default:
                        Image(systemName: "leaf.fill")
                            .font(.system(size: CGFloat(12 + index % 4 * 3)))
                            .foregroundStyle(theme.accent.opacity((0.05 + 0.08 * pulse) * intensity))
                    }
                }
                .frame(width: CGFloat(24 + index % 4 * 6), height: CGFloat(24 + index % 4 * 6))
                .rotationEffect(.degrees(sin(phase * 0.4 + Double(index)) * 4))
                .position(x: p.x + drift.width, y: p.y + drift.height)
            }

            DotWorkField(color: theme.accent.opacity(0.07 * intensity), phase: phase)
        }
    }

    // MARK: - Cyber Midnight

    private func cyberMidnight(size: CGSize, phase: Double) -> some View {
        ZStack {
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
            .offset(x: CGFloat(sin(phase * 0.35)) * 3, y: CGFloat(phase.truncatingRemainder(dividingBy: 34)))

            ForEach(0..<18, id: \.self) { index in
                let p = point(index, in: size, salt: 29)
                let flicker = glow(index, phase: phase * 3.0)

                if index % 3 == 0 {
                    CyberCatGlyph()
                        .stroke(
                            (index.isMultiple(of: 2) ? theme.accent : theme.secondaryAccent)
                                .opacity((0.10 + 0.18 * flicker) * intensity),
                            style: StrokeStyle(lineWidth: 1.3, lineCap: .square, lineJoin: .miter)
                        )
                        .frame(width: CGFloat(27 + index % 4 * 5), height: CGFloat(25 + index % 4 * 5))
                        .shadow(color: theme.accent.opacity(0.20 * intensity), radius: 6)
                        .position(p)
                } else {
                    RoundedRectangle(cornerRadius: 1)
                        .stroke(
                            theme.accent.opacity((0.035 + 0.09 * flicker) * intensity),
                            lineWidth: 0.8
                        )
                        .frame(width: CGFloat(8 + index % 5 * 4), height: CGFloat(5 + index % 4 * 3))
                        .position(p)
                }
            }

            Rectangle()
                .fill(theme.accent.opacity(0.065 * intensity))
                .frame(height: 1)
                .offset(y: CGFloat((phase * 44).truncatingRemainder(dividingBy: max(size.height, 1))) - size.height / 2)
                .blur(radius: 0.5)
        }
    }

    // MARK: - Ultraviolet Unicorn

    private func ultravioletUnicorn(size: CGSize, phase: Double) -> some View {
        ZStack {
            ForEach(0..<17, id: \.self) { index in
                let p = point(index, in: size, salt: 41)
                let drift = drift(index, phase: phase * 0.32, amount: 10)
                let pulse = glow(index, phase: phase * 1.1)

                Group {
                    switch index % 3 {
                    case 0:
                        UnicornGlyph()
                            .stroke(theme.accent.opacity((0.10 + 0.11 * pulse) * intensity), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
                    case 1:
                        CloudGlyph()
                            .stroke(Color.white.opacity((0.07 + 0.08 * pulse) * intensity), lineWidth: 1.15)
                    default:
                        RainbowGlyph()
                            .stroke(theme.secondaryAccent.opacity((0.08 + 0.10 * pulse) * intensity), style: StrokeStyle(lineWidth: 1.15, lineCap: .round))
                    }
                }
                .frame(width: CGFloat(30 + index % 4 * 7), height: CGFloat(24 + index % 4 * 5))
                .shadow(color: theme.accent.opacity(0.13 * intensity), radius: 6)
                .position(x: p.x + drift.width, y: p.y + drift.height)
            }

            ForEach(0..<24, id: \.self) { index in
                let p = point(index, in: size, salt: 83)
                Image(systemName: "sparkles")
                    .font(.system(size: CGFloat(7 + index % 3 * 2)))
                    .foregroundStyle(Color.white.opacity((0.04 + 0.13 * glow(index, phase: phase * 1.9)) * intensity))
                    .position(p)
            }
        }
    }

    // MARK: - Powder Princess

    private func powderPrincess(size: CGSize, phase: Double) -> some View {
        ZStack {
            ForEach(0..<18, id: \.self) { index in
                let p = point(index, in: size, salt: 17)
                let travel = CGFloat((phase * (5 + Double(index % 4))).truncatingRemainder(dividingBy: Double(max(size.height + 100, 1))))
                let y = (p.y - travel + size.height + 100).truncatingRemainder(dividingBy: size.height + 100) - 40

                Circle()
                    .stroke(
                        Color.white.opacity((0.07 + 0.08 * glow(index, phase: phase)) * intensity),
                        lineWidth: 1
                    )
                    .background(
                        Circle().fill(theme.accent.opacity(0.018 * intensity))
                    )
                    .frame(width: CGFloat(14 + index % 5 * 7), height: CGFloat(14 + index % 5 * 7))
                    .position(x: p.x, y: y)
            }

            ForEach(0..<18, id: \.self) { index in
                let p = point(index, in: size, salt: 61)
                let pulse = glow(index, phase: phase * 1.2)

                Group {
                    switch index % 3 {
                    case 0:
                        CrownGlyph()
                            .stroke(Color.white.opacity((0.09 + 0.10 * pulse) * intensity), style: StrokeStyle(lineWidth: 1.25, lineJoin: .round))
                    case 1:
                        Image(systemName: "heart.fill")
                            .font(.system(size: CGFloat(10 + index % 4 * 3)))
                            .foregroundStyle(theme.accent.opacity((0.07 + 0.10 * pulse) * intensity))
                    default:
                        Image(systemName: "star.fill")
                            .font(.system(size: CGFloat(8 + index % 4 * 2)))
                            .foregroundStyle(Color.white.opacity((0.06 + 0.12 * pulse) * intensity))
                    }
                }
                .frame(width: 30, height: 24)
                .position(p)
            }
        }
    }

    // MARK: - Green Acid Monster

    private func greenAcidMonster(size: CGSize, phase: Double) -> some View {
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                let p = point(index, in: size, salt: 23)
                let drift = drift(index, phase: phase * 0.6, amount: 8)
                let blink = pow(glow(index, phase: phase * 2.1), 4)

                SwampMonsterGlyph(blink: blink)
                    .stroke(
                        theme.accent.opacity((0.11 + 0.17 * glow(index, phase: phase)) * intensity),
                        style: StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: CGFloat(30 + index % 5 * 7), height: CGFloat(28 + index % 5 * 7))
                    .shadow(color: theme.accent.opacity(0.18 * intensity), radius: 7)
                    .position(x: p.x + drift.width, y: p.y + drift.height)
            }

            ForEach(0..<20, id: \.self) { index in
                let p = point(index, in: size, salt: 91)
                Capsule()
                    .fill(theme.accent.opacity((0.035 + 0.08 * glow(index, phase: phase * 1.5)) * intensity))
                    .frame(width: CGFloat(3 + index % 3), height: CGFloat(8 + index % 5 * 5))
                    .offset(y: CGFloat((phase * Double(5 + index % 4)).truncatingRemainder(dividingBy: 24)))
                    .position(p)
            }
        }
    }

    // MARK: - Iron Knight

    private func ironKnight(size: CGSize, phase: Double) -> some View {
        ZStack {
            ForEach(0..<18, id: \.self) { index in
                let p = point(index, in: size, salt: 31)
                let pulse = glow(index, phase: phase * 0.7)

                Group {
                    switch index % 3 {
                    case 0:
                        SwordGlyph()
                            .stroke(Color.white.opacity((0.08 + 0.10 * pulse) * intensity), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                    case 1:
                        KnightHelmetGlyph()
                            .stroke(theme.accent.opacity((0.08 + 0.11 * pulse) * intensity), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                    default:
                        ShieldGlyph()
                            .stroke(theme.secondaryAccent.opacity((0.08 + 0.10 * pulse) * intensity), lineWidth: 1.2)
                    }
                }
                .frame(width: CGFloat(26 + index % 4 * 7), height: CGFloat(30 + index % 4 * 7))
                .rotationEffect(.degrees(Double((index * 23) % 30) - 15))
                .position(p)
            }

            LinearGradient(
                colors: [.clear, Color.white.opacity(0.10 * intensity), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 90)
            .rotationEffect(.degrees(18))
            .offset(x: CGFloat((phase * 38).truncatingRemainder(dividingBy: Double(max(size.width + 180, 1)))) - size.width / 2 - 90)
            .blur(radius: 3)
            .allowsHitTesting(false)
        }
    }

    private func legacyPattern(size: CGSize, phase: Double) -> some View {
        ForEach(0..<18, id: \.self) { index in
            let p = point(index, in: size, salt: 11)
            Image(systemName: theme.wallpaperSymbols[index % theme.wallpaperSymbols.count])
                .font(.system(size: CGFloat(10 + index % 4 * 3), weight: .medium))
                .foregroundStyle(theme.accent.opacity((0.05 + 0.07 * glow(index, phase: phase)) * intensity))
                .position(p)
        }
    }

    // MARK: - Deterministic motion helpers

    private func point(_ index: Int, in size: CGSize, salt: Int) -> CGPoint {
        let xSeed = CGFloat((index * 47 + salt * 13 + 11) % 101) / 100
        let ySeed = CGFloat((index * 71 + salt * 17 + 19) % 103) / 102
        return CGPoint(
            x: max(16, min(size.width - 16, xSeed * size.width)),
            y: max(16, min(size.height - 16, ySeed * size.height))
        )
    }

    private func drift(_ index: Int, phase: Double, amount: CGFloat) -> CGSize {
        CGSize(
            width: CGFloat(sin(phase + Double(index) * 0.73)) * amount,
            height: CGFloat(cos(phase * 0.82 + Double(index) * 0.51)) * amount
        )
    }

    private func glow(_ index: Int, phase: Double) -> Double {
        (sin(phase + Double(index) * 0.91) + 1) * 0.5
    }
}

// MARK: - Theme glyphs

private struct CatFaceGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.18, y: h * 0.35))
        p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.05))
        p.addLine(to: CGPoint(x: w * 0.34, y: h * 0.20))
        p.addQuadCurve(to: CGPoint(x: w * 0.66, y: h * 0.20), control: CGPoint(x: w * 0.50, y: h * 0.10))
        p.addLine(to: CGPoint(x: w * 0.90, y: h * 0.05))
        p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.35))
        p.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.90), control: CGPoint(x: w * 0.92, y: h * 0.78))
        p.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.35), control: CGPoint(x: w * 0.08, y: h * 0.78))
        p.move(to: CGPoint(x: w * 0.30, y: h * 0.49))
        p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.46))
        p.move(to: CGPoint(x: w * 0.60, y: h * 0.46))
        p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.49))
        p.move(to: CGPoint(x: w * 0.44, y: h * 0.63))
        p.addQuadCurve(to: CGPoint(x: w * 0.56, y: h * 0.63), control: CGPoint(x: w * 0.50, y: h * 0.69))
        return p
    }
}

private struct DemonCatGlyph: Shape {
    let laugh: Double

    func path(in rect: CGRect) -> Path {
        var p = CatFaceGlyph().path(in: rect)
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.23, y: h * 0.18))
        p.addQuadCurve(to: CGPoint(x: w * 0.35, y: h * 0.05), control: CGPoint(x: w * 0.20, y: h * 0.03))
        p.move(to: CGPoint(x: w * 0.77, y: h * 0.18))
        p.addQuadCurve(to: CGPoint(x: w * 0.65, y: h * 0.05), control: CGPoint(x: w * 0.80, y: h * 0.03))
        let y = h * (0.68 + 0.05 * laugh)
        p.move(to: CGPoint(x: w * 0.38, y: y))
        p.addQuadCurve(to: CGPoint(x: w * 0.62, y: y), control: CGPoint(x: w * 0.50, y: h * (0.79 + 0.05 * laugh)))
        return p
    }
}

private struct MoonCycleGlyph: Shape {
    let stage: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: rect.insetBy(dx: 1, dy: 1))
        let shift = CGFloat(stage - 4) / 4
        let inner = rect.insetBy(dx: rect.width * 0.22, dy: 1)
            .offsetBy(dx: shift * rect.width * 0.28, dy: 0)
        p.addEllipse(in: inner)
        return p
    }
}

private struct DragonGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.05, y: h * 0.62))
        p.addCurve(
            to: CGPoint(x: w * 0.46, y: h * 0.34),
            control1: CGPoint(x: w * 0.16, y: h * 0.12),
            control2: CGPoint(x: w * 0.34, y: h * 0.88)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.42),
            control1: CGPoint(x: w * 0.58, y: h * 0.02),
            control2: CGPoint(x: w * 0.70, y: h * 0.78)
        )
        p.addQuadCurve(to: CGPoint(x: w * 0.95, y: h * 0.32), control: CGPoint(x: w * 0.90, y: h * 0.46))
        p.move(to: CGPoint(x: w * 0.80, y: h * 0.40))
        p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.20))
        p.addLine(to: CGPoint(x: w * 0.91, y: h * 0.39))
        p.move(to: CGPoint(x: w * 0.84, y: h * 0.46))
        p.addLine(to: CGPoint(x: w * 0.96, y: h * 0.52))
        p.move(to: CGPoint(x: w * 0.93, y: h * 0.31))
        p.addLine(to: CGPoint(x: w, y: h * 0.26))
        p.move(to: CGPoint(x: w * 0.27, y: h * 0.52))
        p.addLine(to: CGPoint(x: w * 0.19, y: h * 0.78))
        p.move(to: CGPoint(x: w * 0.56, y: h * 0.42))
        p.addLine(to: CGPoint(x: w * 0.63, y: h * 0.70))
        return p
    }
}

private struct RuneGlyph: Shape {
    let variant: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        if variant.isMultiple(of: 2) {
            p.move(to: CGPoint(x: w * 0.50, y: 0))
            p.addLine(to: CGPoint(x: w * 0.15, y: h * 0.80))
            p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.80))
            p.closeSubpath()
            p.move(to: CGPoint(x: w * 0.50, y: h * 0.22))
            p.addLine(to: CGPoint(x: w * 0.50, y: h))
        } else {
            p.move(to: CGPoint(x: w * 0.18, y: h * 0.18))
            p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.82))
            p.move(to: CGPoint(x: w * 0.82, y: h * 0.18))
            p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.82))
            p.addEllipse(in: rect.insetBy(dx: w * 0.28, dy: h * 0.28))
        }
        return p
    }
}

private struct WitchHatGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.18, y: h * 0.72))
        p.addQuadCurve(to: CGPoint(x: w * 0.58, y: h * 0.05), control: CGPoint(x: w * 0.36, y: h * 0.40))
        p.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.65), control: CGPoint(x: w * 0.74, y: h * 0.22))
        p.move(to: CGPoint(x: w * 0.05, y: h * 0.75))
        p.addQuadCurve(to: CGPoint(x: w * 0.95, y: h * 0.76), control: CGPoint(x: w * 0.50, y: h * 0.95))
        p.move(to: CGPoint(x: w * 0.28, y: h * 0.58))
        p.addLine(to: CGPoint(x: w * 0.76, y: h * 0.58))
        return p
    }
}

private struct CauldronGlyph: Shape {
    let steam: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.16, y: h * 0.48))
        p.addQuadCurve(to: CGPoint(x: w * 0.84, y: h * 0.48), control: CGPoint(x: w * 0.50, y: h * 0.40))
        p.addQuadCurve(to: CGPoint(x: w * 0.68, y: h * 0.88), control: CGPoint(x: w * 0.86, y: h * 0.78))
        p.addLine(to: CGPoint(x: w * 0.32, y: h * 0.88))
        p.addQuadCurve(to: CGPoint(x: w * 0.16, y: h * 0.48), control: CGPoint(x: w * 0.14, y: h * 0.78))
        p.move(to: CGPoint(x: w * 0.38, y: h * 0.42))
        p.addCurve(to: CGPoint(x: w * 0.42, y: h * 0.06), control1: CGPoint(x: w * (0.28 + 0.04 * steam), y: h * 0.30), control2: CGPoint(x: w * 0.53, y: h * 0.18))
        p.move(to: CGPoint(x: w * 0.60, y: h * 0.42))
        p.addCurve(to: CGPoint(x: w * 0.62, y: h * 0.10), control1: CGPoint(x: w * (0.72 - 0.04 * steam), y: h * 0.31), control2: CGPoint(x: w * 0.50, y: h * 0.20))
        return p
    }
}

private struct DotWorkField: View {
    let color: Color
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<42, id: \.self) { index in
                let x = CGFloat((index * 43 + 11) % 101) / 100 * proxy.size.width
                let y = CGFloat((index * 67 + 17) % 103) / 102 * proxy.size.height
                Circle()
                    .fill(color.opacity(0.45 + 0.55 * ((sin(phase + Double(index)) + 1) * 0.5)))
                    .frame(width: CGFloat(1 + index % 2), height: CGFloat(1 + index % 2))
                    .position(x: x, y: y)
            }
        }
    }
}

private struct CyberCatGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = CatFaceGlyph().path(in: rect)
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: 0, y: h * 0.50))
        p.addLine(to: CGPoint(x: w * 0.14, y: h * 0.50))
        p.move(to: CGPoint(x: w * 0.86, y: h * 0.50))
        p.addLine(to: CGPoint(x: w, y: h * 0.50))
        return p
    }
}

private struct UnicornGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.addEllipse(in: CGRect(x: w * 0.28, y: h * 0.24, width: w * 0.38, height: h * 0.34))
        p.move(to: CGPoint(x: w * 0.58, y: h * 0.25))
        p.addLine(to: CGPoint(x: w * 0.74, y: 0))
        p.move(to: CGPoint(x: w * 0.28, y: h * 0.44))
        p.addCurve(to: CGPoint(x: w * 0.06, y: h * 0.72), control1: CGPoint(x: w * 0.12, y: h * 0.36), control2: CGPoint(x: w * 0.20, y: h * 0.76))
        p.move(to: CGPoint(x: w * 0.43, y: h * 0.57))
        p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.96))
        p.move(to: CGPoint(x: w * 0.57, y: h * 0.57))
        p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.96))
        p.move(to: CGPoint(x: w * 0.66, y: h * 0.40))
        p.addQuadCurve(to: CGPoint(x: w * 0.90, y: h * 0.32), control: CGPoint(x: w * 0.80, y: h * 0.48))
        return p
    }
}

private struct CloudGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.10, y: h * 0.68))
        p.addCurve(to: CGPoint(x: w * 0.36, y: h * 0.42), control1: CGPoint(x: w * 0.08, y: h * 0.50), control2: CGPoint(x: w * 0.20, y: h * 0.40))
        p.addCurve(to: CGPoint(x: w * 0.66, y: h * 0.42), control1: CGPoint(x: w * 0.43, y: h * 0.08), control2: CGPoint(x: w * 0.67, y: h * 0.16))
        p.addCurve(to: CGPoint(x: w * 0.90, y: h * 0.68), control1: CGPoint(x: w * 0.84, y: h * 0.38), control2: CGPoint(x: w * 0.94, y: h * 0.52))
        p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.68))
        return p
    }
}

private struct RainbowGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        for inset in [CGFloat(0), rect.width * 0.12, rect.width * 0.24] {
            let radius = rect.width * 0.48 - inset
            p.addArc(center: center, radius: radius, startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
        }
        return p
    }
}

private struct CrownGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.08, y: h * 0.30))
        p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.64))
        p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.18))
        p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.64))
        p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.30))
        p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.82))
        p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.82))
        p.closeSubpath()
        return p
    }
}

private struct SwampMonsterGlyph: Shape {
    let blink: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.16, y: h * 0.80))
        p.addCurve(to: CGPoint(x: w * 0.16, y: h * 0.30), control1: CGPoint(x: w * 0.02, y: h * 0.60), control2: CGPoint(x: w * 0.06, y: h * 0.34))
        p.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.10), control: CGPoint(x: w * 0.26, y: 0))
        p.addQuadCurve(to: CGPoint(x: w * 0.84, y: h * 0.30), control: CGPoint(x: w * 0.74, y: 0))
        p.addCurve(to: CGPoint(x: w * 0.84, y: h * 0.80), control1: CGPoint(x: w * 0.94, y: h * 0.34), control2: CGPoint(x: w * 0.98, y: h * 0.62))
        p.addQuadCurve(to: CGPoint(x: w * 0.16, y: h * 0.80), control: CGPoint(x: w * 0.50, y: h))
        let eyeHeight = h * max(0.02, 0.08 * (1 - blink))
        p.addEllipse(in: CGRect(x: w * 0.28, y: h * 0.42, width: w * 0.14, height: eyeHeight))
        p.addEllipse(in: CGRect(x: w * 0.58, y: h * 0.42, width: w * 0.14, height: eyeHeight))
        p.move(to: CGPoint(x: w * 0.38, y: h * 0.67))
        p.addQuadCurve(to: CGPoint(x: w * 0.62, y: h * 0.67), control: CGPoint(x: w * 0.50, y: h * 0.76))
        return p
    }
}

private struct SwordGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.50, y: 0))
        p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.68))
        p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.82))
        p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.68))
        p.closeSubpath()
        p.move(to: CGPoint(x: w * 0.22, y: h * 0.72))
        p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.72))
        p.move(to: CGPoint(x: w * 0.50, y: h * 0.82))
        p.addLine(to: CGPoint(x: w * 0.50, y: h))
        return p
    }
}

private struct KnightHelmetGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.22, y: h * 0.88))
        p.addLine(to: CGPoint(x: w * 0.16, y: h * 0.36))
        p.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.08), control: CGPoint(x: w * 0.24, y: h * 0.04))
        p.addQuadCurve(to: CGPoint(x: w * 0.84, y: h * 0.36), control: CGPoint(x: w * 0.76, y: h * 0.04))
        p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.88))
        p.move(to: CGPoint(x: w * 0.20, y: h * 0.48))
        p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.48))
        p.move(to: CGPoint(x: w * 0.50, y: h * 0.10))
        p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.88))
        return p
    }
}

private struct ShieldGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX * 0.86, y: rect.minY + rect.height * 0.18))
        p.addLine(to: CGPoint(x: rect.maxX * 0.78, y: rect.minY + rect.height * 0.66))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX * 0.70, y: rect.maxY * 0.86))
        p.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.66), control: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.maxY * 0.86))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.18))
        p.closeSubpath()
        return p
    }
}
