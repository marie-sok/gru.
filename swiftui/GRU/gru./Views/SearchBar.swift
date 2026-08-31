
import SwiftUI

struct SearchBar: View {

    @Binding var text: String

    let resultsText: String

    let onSearch: () -> Void

    let onNext: () -> Void

    let onPrevious: () -> Void

    let onClose: () -> Void

    var body: some View {

        HStack(spacing: 10) {

            Image(systemName: "magnifyingglass")

            TextField(
                "Поиск",
                text: $text
            )
            .textFieldStyle(.plain)
            .onSubmit {

                onSearch()
            }

            Text(resultsText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {

                onPrevious()

            } label: {

                Image(systemName: "chevron.up")
            }

            Button {

                onNext()

            } label: {

                Image(systemName: "chevron.down")
            }

            Button {

                onClose()

            } label: {

                Image(systemName: "xmark")
            }
        }
        .padding(.horizontal)
        .padding(.vertical,10)
        .background(GRUColors.card)
    }
}

#Preview {

    SearchBar(
        text: .constant(""),
        resultsText: "0/0",
        onSearch: {},
        onNext: {},
        onPrevious: {},
        onClose: {}
    )
}
