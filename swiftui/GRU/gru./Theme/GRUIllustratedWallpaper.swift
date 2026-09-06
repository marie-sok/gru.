import SwiftUI

/// Permanent edge-to-edge GRU wallpaper.
/// Character motion is produced by real illustration frames, never by drawing
/// synthetic eyes or facial features over a static PNG.
struct GRUIllustratedWallpaper: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                theme.background
                    .ignoresSafeArea(.container, edges: .all)

                GRUThemeFrameAnimator(
                    theme: theme,
                    animated: animated && !reduceMotion
                )
                .frame(width: proxy.size.width, height: proxy.size.height)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.01),
                        .clear,
                        Color.black.opacity(0.07)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
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
