import SwiftUI

@MainActor
struct ContactSharePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ContactsViewModel()

    let onSelect: (PhoneContact) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                GRUAppBackdrop()

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        GRUNeonIcon(systemName: "magnifyingglass", size: 34, iconSize: 14)
                        TextField("Найти контакт", text: $vm.searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(10)
                    .background(GRUColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 16)

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.filteredPhoneContacts) { contact in
                                Button {
                                    onSelect(contact)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle().fill(GRUColors.accent.opacity(0.10))
                                            Text(contact.initials.isEmpty ? "?" : contact.initials)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(GRUColors.accent)
                                        }
                                        .frame(width: 42, height: 42)
                                        .overlay {
                                            Circle().stroke(GRUColors.accent.opacity(0.22), lineWidth: 1)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(contact.displayName)
                                                .font(.body.weight(.semibold))
                                            Text(contact.primaryPhone ?? "")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()
                                        GRUNeonIcon(systemName: "paperplane.fill", size: 36, iconSize: 14)
                                    }
                                    .padding(12)
                                    .background(GRUColors.card.opacity(0.86))
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
                .padding(.top, 12)
            }
            .navigationTitle("Отправить контакт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .task {
            await vm.loadPhoneContacts()
        }
    }
}
