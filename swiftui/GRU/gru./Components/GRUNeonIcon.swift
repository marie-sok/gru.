import SwiftUI

struct GRUNeonIcon: View {
    @AppStorage("gru.settings.appearance.neonGlow") private var neonGlow = true
    @AppStorage("gru.settings.accessibility.highContrast") private var highContrast = false

    let systemName: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 17
    var isActive: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .fill(GRUColors.card.opacity(0.94))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            GRUColors.accent.opacity(isActive && neonGlow ? 0.20 : 0.04),
                            GRUColors.card.opacity(0.18)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.54
                    )
                )

            Circle()
                .fill(GRUColors.accent.opacity(isActive ? 0.055 : 0.018))
                .padding(2)

            Circle()
                .stroke(
                    GRUColors.neonGradient,
                    lineWidth: highContrast ? 2.2 : (isActive && neonGlow ? 1.55 : 0.72)
                )
                .opacity(isActive ? 1 : (highContrast ? 0.55 : 0.24))

            Circle()
                .stroke(GRUColors.accent.opacity(isActive && neonGlow ? 0.20 : 0.04), lineWidth: 5)
                .blur(radius: 5)

            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(isActive ? GRUColors.accent : .secondary)
                .shadow(
                    color: GRUColors.accent.opacity(isActive && neonGlow ? 0.36 : 0),
                    radius: isActive && neonGlow ? 4 : 0
                )
        }
        .frame(width: size, height: size)
        .shadow(
            color: GRUColors.accent.opacity(isActive && neonGlow ? 0.20 : 0.02),
            radius: isActive && neonGlow ? 9 : 1
        )
        .shadow(
            color: GRUColors.accentSecondary.opacity(isActive && neonGlow ? 0.12 : 0),
            radius: isActive && neonGlow ? 15 : 0
        )
    }
}

struct GRUNeonIconButton: View {
    let systemName: String
    var accessibilityLabel: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 17
    var isActive: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GRUNeonIcon(
                systemName: systemName,
                size: size,
                iconSize: iconSize,
                isActive: isActive
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
