import SwiftUI

/// Live GRU wallpaper backed only by transparent SwiftUI/Canvas character art.
/// No bitmap atlas is decoded or drawn in the product path.
struct GRUIllustratedWallpaper: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    var body: some View {
        GRUThemeCharacterScene(
            theme: theme,
            intensity: intensity,
            animated: animated
        )
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
