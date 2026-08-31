import SwiftUI

struct ReactionPickerView: View {

    let onSelect: (ReactionType) -> Void

    private let reactions = ReactionType.allCases

    var body: some View {

        HStack(spacing: 12) {

            // ReactionType conforms to Identifiable by its emoji
            ForEach(reactions) { reaction in Button {
                
                onSelect(reaction)

                } label: {

                Text(reaction.emoji)
                        .font(.system(size: 30))
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 8)
    }
}

#Preview {

    ReactionPickerView { _ in

    }
}
