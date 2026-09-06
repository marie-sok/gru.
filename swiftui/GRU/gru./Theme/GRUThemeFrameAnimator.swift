import SwiftUI

/// Frame-based character animation for GRU illustrated themes.
/// No synthetic eyes or facial overlays are drawn on top of the artwork.
/// Each animated state is a real illustration frame in Assets.xcassets.
struct GRUThemeFrameAnimator: View {
    let theme: GRUAppTheme
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !animated || reduceMotion)) { timeline in
            GeometryReader { proxy in
                Image(frameName(at: timeline.date.timeIntervalSinceReferenceDate))
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func frameName(at time: TimeInterval) -> String {
        guard animated, !reduceMotion else {
            return idleFrameName
        }

        switch theme {
        case .powderPrincess:
            return powderPrincessFrame(at: time)
        default:
            return theme.illustrationAssetName
        }
    }

    private var idleFrameName: String {
        switch theme {
        case .powderPrincess:
            return "theme_powder_princess_idle"
        default:
            return theme.illustrationAssetName
        }
    }

    private func powderPrincessFrame(at time: TimeInterval) -> String {
        // Calm 10-second loop. Most of the time the cat stays idle.
        // Blink is deliberately short; expression and paw changes last longer.
        let phase = time.truncatingRemainder(dividingBy: 10.0)

        switch phase {
        case 0.00..<3.60:
            return "theme_powder_princess_idle"
        case 3.60..<3.82:
            return "theme_powder_princess_blink"
        case 3.82..<5.25:
            return "theme_powder_princess_idle"
        case 5.25..<6.30:
            return "theme_powder_princess_smile"
        case 6.30..<7.75:
            return "theme_powder_princess_idle"
        case 7.75..<8.75:
            return "theme_powder_princess_paw"
        default:
            return "theme_powder_princess_idle"
        }
    }
}
