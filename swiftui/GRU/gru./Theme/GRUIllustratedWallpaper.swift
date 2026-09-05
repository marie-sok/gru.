import SwiftUI

/// Live GRU wallpaper backed only by transparent SwiftUI/Canvas character art.
/// CAT PACK V2 keeps the characters large and high-contrast on real iPhones.
struct GRUIllustratedWallpaper: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    var body: some View {
        GRUThemeCharacterSceneV2(
            theme: theme,
            intensity: intensity,
            animated: animated
        )
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
