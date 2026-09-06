import SwiftUI

/// Permanent edge-to-edge GRU wallpaper.
/// Character artwork is always static. Motion is limited to tiny decorative
/// details so the wallpaper feels alive without distorting or re-framing cats.
struct GRUIllustratedWallpaper: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shouldAnimate: Bool {
        animated && !reduceMotion
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                theme.background
                    .ignoresSafeArea(.container, edges: .all)

                Image(theme.illustrationAssetName)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [
                        Color.black.opacity(theme == .powderPrincess ? 0.00 : 0.01),
                        .clear,
                        Color.black.opacity(theme == .powderPrincess ? 0.025 : 0.07)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if shouldAnimate {
                    if theme == .powderPrincess {
                        GRUPowderPrincessDetailOverlay(
                            intensity: intensity,
                            animated: true
                        )
                    } else {
                        GRUApprovedThemeOverlay(
                            theme: theme,
                            intensity: intensity,
                            animated: true
                        )
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .ignoresSafeArea(.container, edges: .all)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .all)
    }
}
