import SwiftUI

/// Live GRU wallpaper matching the user-approved nine-theme preview.
/// Character art stays dominant; motif overlays provide each world's specific atmosphere.
struct GRUIllustratedWallpaper: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    var body: some View {
        ZStack {
            GRUThemeCharacterSceneV2(
                theme: theme,
                intensity: intensity,
                animated: animated
            )

            GRUApprovedThemeOverlay(
                theme: theme,
                intensity: intensity,
                animated: animated
            )
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}