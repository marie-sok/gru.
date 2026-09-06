import SwiftUI
import UIKit

@MainActor
struct GRUThemeStudioView: View {
    @AppStorage(GRUTheme.selectionKey)
    private var themeRaw = GRUAppTheme.blackMoonCat.rawValue

    @AppStorage(GRUAppearanceSettings.dynamicBackgroundKey)
    private var dynamicBackground = true

    @AppStorage(GRUAppearanceSettings.animationIntensityKey)
    private var animationIntensity = GRUAppearanceSettings.defaultAnimationIntensity

    private var selectedTheme: GRUAppTheme {
        let theme = GRUAppTheme(rawValue: themeRaw) ?? .blackMoonCat
        return GRUThemePolicy.allowed.contains(theme) ? theme : .blackMoonCat
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                livePreview
                motionControls
                themeRail
                chromePreview
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
        }
        .background(GRUAppBackdrop())
        .navigationTitle("Theme Studio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !GRUThemePolicy.allowed.contains(selectedTheme) {
                themeRaw = GRUAppTheme.blackMoonCat.rawValue
            }
            animationIntensity = GRUAppearanceSettings.clampedIntensity(animationIntensity)
        }
    }
}

private extension GRUThemeStudioView {
    var livePreview: some View {
        ZStack(alignment: .bottom) {
            GRUSignatureWallpaper(
                theme: selectedTheme,
                intensity: 1,
                animated: dynamicBackground
            )

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 12) {
                HStack {
                    Label("LIVE", systemImage: dynamicBackground ? "waveform.path.ecg" : "pause.fill")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(selectedTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())

                    Spacer()

                    Text("\(Int(animationIntensity * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                }

                HStack(spacing: 9) {
                    Circle()
                        .fill(selectedTheme.accent.opacity(0.18))
                        .frame(width: 38, height: 38)
                        .overlay {
                            Image(systemName: selectedTheme.icon)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(selectedTheme.accent)
                        }
                        .overlay {
                            Circle()
                                .stroke(selectedTheme.accent.opacity(0.45), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(studioTitle(selectedTheme))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("полноэкранная тема gru.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    Spacer()
                }

                VStack(spacing: 7) {
                    HStack {
                        previewBubble("это выглядит живее ✦", outgoing: false)
                        Spacer(minLength: 58)
                    }

                    HStack {
                        Spacer(minLength: 58)
                        previewBubble("и акцент теперь один на весь UI", outgoing: true)
                    }
                }
            }
            .padding(14)
        }
        .frame(height: 330)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(selectedTheme.accent.opacity(0.36), lineWidth: 1.2)
        }
        .shadow(color: selectedTheme.accent.opacity(0.24), radius: 24, y: 12)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: themeRaw)
    }

    var motionControls: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Движение темы")
                        .font(.headline)
                    Text(dynamicBackground ? "микро-анимация активна" : "фон остаётся статичным")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $dynamicBackground)
                    .labelsHidden()
                    .tint(selectedTheme.accent)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Спокойно")
                    Spacer()
                    Text("Интенсивность \(Int(animationIntensity * 100))%")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("Живо")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Slider(value: $animationIntensity, in: 0...1, step: 0.05)
                    .tint(selectedTheme.accent)
                    .disabled(!dynamicBackground)
            }

            HStack(spacing: 10) {
                presetButton("Soft", value: 0.35)
                presetButton("GRU", value: GRUAppearanceSettings.defaultAnimationIntensity)
                presetButton("Max", value: 1.0)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(selectedTheme.accent.opacity(0.18), lineWidth: 1)
        }
    }

    var themeRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Коллекция")
                    .font(.headline)
                Spacer()
                Text("\(GRUThemePolicy.allowed.count) тем")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 11) {
                    ForEach(GRUThemePolicy.allowed) { theme in
                        themeCard(theme)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    var chromePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Акцент интерфейса")
                .font(.headline)

            HStack(spacing: 10) {
                chromeChip(icon: "person.2.fill", title: "Люди", active: false)
                chromeChip(icon: "envelope.fill", title: "Чаты", active: true)
                chromeChip(icon: "slider.horizontal.3", title: "Настройки", active: false)
            }

            Text("Tab bar, кнопки, статусы, chat header и исходящие сообщения используют accent выбранной темы.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(GRUColors.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(selectedTheme.accent.opacity(0.16), lineWidth: 1)
        }
    }

    func previewBubble(_ text: String, outgoing: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                outgoing
                    ? selectedTheme.accent.opacity(0.28)
                    : selectedTheme.card.opacity(0.90),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        outgoing ? selectedTheme.accent.opacity(0.42) : Color.white.opacity(0.07),
                        lineWidth: 0.8
                    )
            }
    }

    func presetButton(_ title: String, value: Double) -> some View {
        let isSelected = abs(animationIntensity - value) < 0.03

        return Button {
            animationIntensity = value
            dynamicBackground = true
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    isSelected ? selectedTheme.accent.opacity(0.17) : Color.white.opacity(0.045),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? selectedTheme.accent.opacity(0.50) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    func themeCard(_ theme: GRUAppTheme) -> some View {
        let active = theme == selectedTheme

        return Button {
            themeRaw = theme.rawValue
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                GRUSignatureWallpaper(theme: theme, intensity: 0.86, animated: false)
                    .frame(width: 116, height: 164)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                active ? theme.accent : theme.accent.opacity(0.18),
                                lineWidth: active ? 2 : 1
                            )
                    }

                Text(studioTitle(theme))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(GRUColors.text)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 6, height: 6)
                    Text(active ? "выбрана" : "тап для выбора")
                        .font(.caption2)
                        .foregroundStyle(active ? theme.accent : .secondary)
                }
            }
            .frame(width: 116, alignment: .leading)
        }
        .buttonStyle(.plain)
        .scaleEffect(active ? 1.0 : 0.97)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: active)
    }

    func chromeChip(icon: String, title: String, active: Bool) -> some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(active ? selectedTheme.accent.opacity(0.18) : Color.white.opacity(0.04))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(active ? selectedTheme.accent : .secondary)
            }
            .overlay {
                Circle()
                    .stroke(active ? selectedTheme.accent.opacity(0.48) : Color.white.opacity(0.05), lineWidth: 1)
            }
            .shadow(color: active ? selectedTheme.accent.opacity(0.26) : .clear, radius: 9)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(active ? GRUColors.text : .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    func studioTitle(_ theme: GRUAppTheme) -> String {
        switch theme {
        case .blackMoonCat: return "Black Moon Cat"
        case .neonCatDemon: return "Neon Demon Cat"
        case .bloodDragon: return "Fold-Eared Cat Dragon"
        case .forestWitch: return "Forest Witch"
        case .cyberMidnight: return "Cyber Midnight"
        case .ultravioletUnicorn: return "Ultraviolet Caticorn"
        case .powderPrincess: return "Powder Princess"
        case .greenAcidMonster: return "Green Acid Monster"
        case .ironKnight: return "Iron Knight"
        default: return theme.title
        }
    }
}
