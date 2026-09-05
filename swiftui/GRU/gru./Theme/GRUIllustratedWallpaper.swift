import SwiftUI

/// Displays the user-approved illustration pack directly from Assets.xcassets.
/// Animation stays intentionally subtle so the artwork remains readable.
struct GRUIllustratedWallpaper: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var phase = false

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
                    .scaleEffect(shouldAnimate ? (phase ? 1.035 : 1.0) : 1.0)
                    .offset(
                        x: shouldAnimate ? (phase ? -6 : 6) : 0,
                        y: shouldAnimate ? (phase ? -8 : 8) : 0
                    )
                    .animation(
                        shouldAnimate
                            ? .easeInOut(duration: 12).repeatForever(autoreverses: true)
                            : .default,
                        value: phase
                    )

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.02),
                        .clear,
                        Color.black.opacity(0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .onAppear {
                phase = true
            }
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
