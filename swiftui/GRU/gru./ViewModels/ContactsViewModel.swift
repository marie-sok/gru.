//
//  ContactsViewModel.swift
//  gru.
//
//  Created by Maria Morozova on 06.07.2026.
//

import Combine
import Contacts
import Foundation

struct PhoneContact: Identifiable, Hashable {
    let id: String
    let displayName: String
    let primaryPhone: String?

    var initials: String {
        let words = displayName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1)) + String(words[1].prefix(1))
        }
        return String(displayName.prefix(1))
    }
}

enum ContactsAccessState: Equatable {
    case unknown
    case loading
    case denied
    case granted
}

@MainActor
final class ContactsViewModel: ObservableObject {
    @Published var phoneContacts: [PhoneContact] = []
    @Published var searchText = ""
    @Published var accessState: ContactsAccessState = .unknown

    var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var filteredPhoneContacts: [PhoneContact] {
        let query = normalizedSearch
        guard !query.isEmpty else {
            return phoneContacts
        }

        let digitsQuery = query.filter { $0.isNumber }

        return phoneContacts.filter { contact in
            contact.displayName.localizedCaseInsensitiveContains(query)
                || (contact.primaryPhone?.localizedCaseInsensitiveContains(query) ?? false)
                || (!digitsQuery.isEmpty && normalizedPhoneNumber(contact.primaryPhone).contains(digitsQuery))
        }
    }

    func loadPhoneContacts() async {
        if accessState == .loading {
            return
        }

        accessState = .loading

        let granted = await requestContactsAccess()
        guard granted else {
            phoneContacts = []
            accessState = .denied
            return
        }

        do {
            phoneContacts = try await Task.detached(priority: .userInitiated) {
                try Self.fetchPhoneContacts()
            }.value
            accessState = .granted
        } catch {
            phoneContacts = []
            accessState = .granted
            print("❌ Phone contacts load error:", error)
        }
    }

    private func requestContactsAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private nonisolated static func fetchPhoneContacts() throws -> [PhoneContact] {
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        var contacts: [PhoneContact] = []

        try store.enumerateContacts(with: request) { contact, _ in
            guard let number = contact.phoneNumbers.first?.value.stringValue, !number.isEmpty else {
                return
            }

            let nameParts = [contact.givenName, contact.familyName]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let displayName = nameParts.isEmpty ? number : nameParts.joined(separator: " ")

            contacts.append(
                PhoneContact(
                    id: contact.identifier,
                    displayName: displayName,
                    primaryPhone: number
                )
            )
        }

        return contacts.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func normalizedPhoneNumber(_ value: String?) -> String {
        guard let value else { return "" }
        return value.filter { $0.isNumber }
    }
}
