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
            guard selectedTab != tab else { return }
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(active ? GRUColors.accent.opacity(0.16) : Color.clear)
                        .frame(width: 34, height: 34)

                    if usesEnvelope {
                        GRUEnvelope()
                            .stroke(
                                active ? GRUColors.accent : GRUColors.secondary,
                                style: StrokeStyle(lineWidth: 2, lineJoin: .round)
                            )
                            .frame(width: 21, height: 15)
                    } else {
                        Image(systemName: image)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(active ? GRUColors.accent : GRUColors.secondary)
                    }
                }

                Text(GRUL10n.text(label))
                    .font(.system(size: 9.5, weight: active ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(active ? GRUColors.text : GRUColors.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(GRUL10n.text(label))
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

#Preview {
    GRUTabBar(selectedTab: .constant(.chats))
        .padding()
}
