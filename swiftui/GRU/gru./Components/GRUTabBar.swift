import SwiftUI
import UIKit

struct GRUTabBar: View {
    @Binding var selectedTab: AppTab

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
                        .fill(GRUColors.card.opacity(0.82))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(GRUColors.neonGradient, lineWidth: 1.15)
                        .opacity(0.72)
                }
                .shadow(color: GRUColors.accent.opacity(0.24), radius: 24, y: 9)
        )
        .padding(.horizontal, 14)
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
                    Circle()
                        .fill(active ? GRUColors.accent.opacity(0.16) : .clear)
                        .frame(width: 38, height: 38)

                    if usesEnvelope {
                        GRUEnvelope()
                            .stroke(
                                active ? GRUColors.accent : GRUColors.secondary,
                                style: StrokeStyle(lineWidth: 2, lineJoin: .round)
                            )
                            .frame(width: 22, height: 16)
                    } else {
                        Image(systemName: image)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(active ? GRUColors.accent : GRUColors.secondary)
                    }
                }

                if active {
                    Text(GRUL10n.text(label))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Capsule()
                    .fill(active ? GRUColors.accent.opacity(0.09) : .clear)
            )
            .overlay {
                if active {
                    Capsule()
                        .stroke(GRUColors.accent.opacity(0.22), lineWidth: 1)
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
