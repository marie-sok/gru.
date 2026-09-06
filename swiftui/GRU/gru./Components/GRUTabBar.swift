import SwiftUI
import UIKit

struct GRUTabBar: View {
    @Binding var selectedTab: AppTab

    @AppStorage(GRUTheme.selectionKey)
    private var themeRaw = GRUAppTheme.blackMoonCat.rawValue

    private var currentTheme: GRUAppTheme {
        GRUAppTheme(rawValue: themeRaw) ?? .blackMoonCat
    }

    var body: some View {
        HStack(spacing: 8) {
            tabItem(.contacts, image: "person.2.fill", label: "Люди")
            tabItem(.chats, image: "envelope.fill", label: "Чаты", usesEnvelope: true)
            tabItem(.settings, image: "slider.horizontal.3", label: "Настройки")
        }
        .padding(7)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(GRUColors.card.opacity(0.84))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(GRUColors.neonGradient, lineWidth: 1.15)
                        .opacity(0.78)
                }
                .shadow(color: currentTheme.accent.opacity(0.28), radius: 24, y: 9)
                .shadow(color: currentTheme.secondaryAccent.opacity(0.10), radius: 34, y: 12)
        )
        .overlay(alignment: .top) {
            Capsule()
                .fill(GRUColors.neonGradient)
                .frame(width: 62, height: 1.5)
                .blur(radius: 0.2)
                .opacity(0.72)
                .offset(y: 1)
        }
        .padding(.horizontal, 14)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: themeRaw)
    }

    private func tabItem(
        _ tab: AppTab,
        image: String,
        label: String,
        usesEnvelope: Bool = false
    ) -> some View {
        let active = selectedTab == tab

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: active ? 8 : 0) {
                ZStack {
                    if active {
                        Circle()
                            .fill(currentTheme.accent.opacity(0.12))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Circle()
                                    .stroke(GRUColors.neonGradient, lineWidth: 1.2)
                                    .opacity(0.76)
                            }
                            .shadow(color: currentTheme.accent.opacity(0.30), radius: 9)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.025))
                            .frame(width: 38, height: 38)
                    }

                    if usesEnvelope {
                        GRUEnvelope()
                            .stroke(
                                active ? currentTheme.accent : GRUColors.secondary,
                                style: StrokeStyle(lineWidth: 2, lineJoin: .round)
                            )
                            .frame(width: 22, height: 16)
                    } else {
                        Image(systemName: image)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(active ? currentTheme.accent : GRUColors.secondary)
                    }
                }
                .scaleEffect(active ? 1.04 : 1.0)

                if active {
                    Text(GRUL10n.text(label))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(GRUColors.text)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Capsule()
                    .fill(active ? currentTheme.accent.opacity(0.085) : .clear)
            )
            .overlay {
                if active {
                    Capsule()
                        .stroke(currentTheme.accent.opacity(0.20), lineWidth: 1)
                }
            }
            .overlay(alignment: .bottom) {
                if active {
                    Capsule()
                        .fill(GRUColors.neonGradient)
                        .frame(width: 18, height: 2)
                        .offset(y: 1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(GRUL10n.text(label))
    }
}

#Preview {
    GRUTabBar(selectedTab: .constant(.chats))
        .padding()
}
