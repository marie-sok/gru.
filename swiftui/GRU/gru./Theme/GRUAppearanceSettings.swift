import Foundation

enum GRUAppearanceSettings {
    static let animationIntensityKey = "gru.settings.appearance.animationIntensity"
    static let dynamicBackgroundKey = "gru.settings.appearance.dynamicBackground"

    static let defaultAnimationIntensity = 0.72

    static func clampedIntensity(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
