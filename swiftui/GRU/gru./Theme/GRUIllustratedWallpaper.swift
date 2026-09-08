import Foundation
import SwiftUI

/// Permanent edge-to-edge GRU wallpaper.
/// The approved full-screen artwork remains the visual anchor, while a light
/// field of tiny theme-specific creatures and decoration adds motion across the
/// whole screen. Motion automatically stops for Reduce Motion, Low Power Mode,
/// and while the app is inactive.
struct GRUIllustratedWallpaper: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(GRUAppearanceSettings.animationIntensityKey)
    private var globalAnimationIntensity = GRUAppearanceSettings.defaultAnimationIntensity

    private var effectiveIntensity: Double {
        GRUAppearanceSettings.clampedIntensity(
            intensity * globalAnimationIntensity
        )
    }

    private var shouldAnimate: Bool {
        animated
            && !reduceMotion
            && scenePhase == .active
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
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

                GRUMicroDoodleOverlay(
                    theme: theme,
                    intensity: effectiveIntensity * 0.82,
                    animated: shouldAnimate
                )

                if shouldAnimate {
                    if theme == .powderPrincess {
                        GRUPowderPrincessDetailOverlay(
                            intensity: effectiveIntensity,
                            animated: true
                        )
                    } else {
                        GRUApprovedThemeOverlay(
                            theme: theme,
                            intensity: effectiveIntensity,
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
