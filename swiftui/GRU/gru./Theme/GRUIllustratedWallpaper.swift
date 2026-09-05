import SwiftUI

/// Live GRU wallpaper backed only by transparent SwiftUI/vector glyphs.
///
/// The previous bitmap atlas had a black matte that could become visible as
/// rectangular tiles on some devices/blend paths. The live product path no
/// longer decodes or draws that atlas at all.
struct GRUIllustratedWallpaper: View {
    let theme: GRUAppTheme
    var intensity: Double = 1
    var animated = true

    var body: some View {
        GRUAnimatedThemeScene(
            theme: theme,
            intensity: intensity,
            animated: animated
        )
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
