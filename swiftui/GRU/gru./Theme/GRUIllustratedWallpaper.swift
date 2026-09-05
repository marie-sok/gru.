import SwiftUI

/// Displays the approved illustration pack as a permanent edge-to-edge layer.
/// The artwork itself never scales, slides or collapses. Animation lives only
/// in ambient glow and the cat-life overlay above the fixed PNG.
struct GRUIllustratedWallpaper: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var glowPhase = false

    private var shouldAnimate: Bool {
        animated && !systemReduceMotion
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                theme.background
                    .ignoresSafeArea()

                Image(theme.illustrationAssetName)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height
                    )
                    .clipped()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.015),
                        .clear,
                        Color.black.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if shouldAnimate {
                    ambientGlowLayer(size: proxy.size)

                    GRUCatLifeOverlay(
                        theme: theme,
                        intensity: intensity,
                        animated: true
                    )
                }
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
            .clipped()
            .ignoresSafeArea(.container, edges: .all)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                glowPhase = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .all)
    }

    @ViewBuilder
    private func ambientGlowLayer(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(theme.accent.opacity(glowPhase ? 0.10 : 0.05))
                .frame(
                    width: min(size.width, size.height) * 0.70,
                    height: min(size.width, size.height) * 0.70
                )
                .blur(radius: 72)
                .offset(
                    x: -size.width * 0.26,
                    y: -size.height * 0.27
                )

            Circle()
                .fill(theme.secondaryAccent.opacity(glowPhase ? 0.08 : 0.035))
                .frame(
                    width: min(size.width, size.height) * 0.82,
                    height: min(size.width, size.height) * 0.82
                )
                .blur(radius: 86)
                .offset(
                    x: size.width * 0.30,
                    y: size.height * 0.30
                )
        }
        .animation(
            .easeInOut(duration: 4.8).repeatForever(autoreverses: true),
            value: glowPhase
        )
    }
}
