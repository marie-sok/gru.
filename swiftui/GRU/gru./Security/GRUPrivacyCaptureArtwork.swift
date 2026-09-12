import SwiftUI

/// Emergency switch for the experimental still-screenshot compositor.
/// Keep this scoped to ChatView; RootView/auth must never depend on it.
enum GRUPrivacyFeatures {
    static let chatScreenshotShieldEnabled = true
}

/// Capture replacement artwork intentionally styled like the GRU chat surface:
/// dark, sparse, playful and recognisably cat-first rather than a heavy modal.
struct GRUPrivacyCaptureArtwork: View {
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background
                chatDoodles(in: proxy.size)

                VStack(spacing: 22) {
                    Spacer(minLength: 70)

                    GRUPrivacyCat()
                        .frame(width: min(proxy.size.width * 0.56, 230), height: 250)

                    VStack(spacing: 8) {
                        Text("Упс…")
                            .font(.system(size: 31, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("this stays between us")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(GRUColors.accent)
                            .textCase(.lowercase)

                        Text("Частная жизнь имеет значение")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.96))
                            .padding(.top, 8)

                        Text("gru. уважает ценность частной жизни. Разговор между двумя людьми должен оставаться между ними.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.64))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 330)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Circle()
                            .fill(GRUColors.accent)
                            .frame(width: 6, height: 6)
                            .shadow(color: GRUColors.accent.opacity(0.85), radius: 7)

                        Text("people for people")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.44))
                    }
                    .padding(.bottom, 26)
                }
                .padding(.horizontal, 24)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .onTapGesture { onDismiss?() }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("gru. privacy")
    }

    private var background: some View {
        ZStack {
            Color(red: 0.025, green: 0.029, blue: 0.041)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.025),
                    Color.clear,
                    GRUColors.accent.opacity(0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [GRUColors.accent.opacity(0.10), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 320
            )
        }
    }

    @ViewBuilder
    private func chatDoodles(in size: CGSize) -> some View {
        ZStack {
            bubble(width: 112, height: 38, opacity: 0.045)
                .offset(x: -size.width * 0.31, y: -size.height * 0.31)

            bubble(width: 84, height: 34, opacity: 0.07)
                .offset(x: size.width * 0.34, y: -size.height * 0.22)

            bubble(width: 128, height: 42, opacity: 0.035)
                .offset(x: size.width * 0.27, y: size.height * 0.28)

            Circle()
                .stroke(GRUColors.accent.opacity(0.10), lineWidth: 1)
                .frame(width: 210, height: 210)
                .offset(x: size.width * 0.32, y: -size.height * 0.34)
        }
        .allowsHitTesting(false)
    }

    private func bubble(width: CGFloat, height: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: height / 2.2, style: .continuous)
            .fill(Color.white.opacity(opacity))
            .frame(width: width, height: height)
    }
}

private struct GRUPrivacyCat: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(GRUColors.accent.opacity(0.08))
                .frame(width: 196, height: 196)
                .blur(radius: 8)
                .offset(y: -18)

            VStack(spacing: -9) {
                catHead
                hoodie
            }
        }
    }

    private var catHead: some View {
        ZStack {
            HStack(spacing: 68) {
                ear(rotation: -14)
                ear(rotation: 14)
            }
            .offset(y: -39)

            RoundedRectangle(cornerRadius: 52, style: .continuous)
                .fill(Color(red: 0.055, green: 0.061, blue: 0.078))
                .frame(width: 128, height: 112)
                .overlay {
                    RoundedRectangle(cornerRadius: 52, style: .continuous)
                        .stroke(GRUColors.accent.opacity(0.92), lineWidth: 2)
                        .shadow(color: GRUColors.accent.opacity(0.55), radius: 8)
                }

            HStack(spacing: 31) {
                eye
                eye
            }
            .offset(y: -5)

            Path { path in
                path.move(to: CGPoint(x: 58, y: 67))
                path.addQuadCurve(
                    to: CGPoint(x: 70, y: 67),
                    control: CGPoint(x: 64, y: 74)
                )
            }
            .stroke(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
            .frame(width: 128, height: 112)
        }
        .frame(width: 164, height: 118)
    }

    private var hoodie: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(Color(red: 0.070, green: 0.076, blue: 0.096))
                .frame(width: 174, height: 118)
                .overlay {
                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }

            Text("ШТОШ")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.92))
                .offset(y: 6)

            HStack(spacing: 122) {
                paw(rotation: -23)
                paw(rotation: 23)
            }
            .offset(y: 18)
        }
    }

    private var eye: some View {
        Circle()
            .fill(Color.white.opacity(0.96))
            .frame(width: 14, height: 14)
            .overlay {
                Circle()
                    .fill(Color.black.opacity(0.82))
                    .frame(width: 6, height: 6)
            }
    }

    private func ear(rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color(red: 0.055, green: 0.061, blue: 0.078))
            .frame(width: 35, height: 45)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(GRUColors.accent.opacity(0.78), lineWidth: 1.7)
            }
            .rotationEffect(.degrees(rotation))
    }

    private func paw(rotation: Double) -> some View {
        Capsule(style: .continuous)
            .fill(Color(red: 0.055, green: 0.061, blue: 0.078))
            .frame(width: 33, height: 71)
            .overlay {
                Capsule(style: .continuous)
                    .stroke(GRUColors.accent.opacity(0.75), lineWidth: 1.7)
            }
            .rotationEffect(.degrees(rotation))
            .shadow(color: GRUColors.accent.opacity(0.28), radius: 8)
    }
}
