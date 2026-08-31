//
//  NewChatViewModel.swift
//  gru.
//
//  Created by Maria Morozova on 06.07.2026.
//


import Foundation
import Combine

@MainActor
final class NewChatViewModel: ObservableObject {

    @Published var username = ""

    @Published var searchResults: [User] = []

    @Published var isLoading = false

    @Published var error: String?

    private let service = ChatService.shared

    // MARK: - Search

    func search() {

        let query = username
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {

            searchResults.removeAll()
            return
        }

        isLoading = true

        let users = service.chats
            .flatMap(\.users)
            .filter {

                $0.id != service.currentUser.id
            }

        searchResults = users.filter {

            $0.displayName
                .localizedCaseInsensitiveContains(query)

            ||

            $0.username
                .localizedCaseInsensitiveContains(query)
        }

        isLoading = false
    }

    // MARK: - Create

    func createChat() {

        let value = username
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else {

            error = "Введите имя пользователя"
            return
        }

        service.createChat(
            username: value
        )

        username = ""
        searchResults.removeAll()
    }

    func createChat(with user: User) {

        service.createChat(
            username: user.displayName
        )
    }

    // MARK: - Clear

    func clear() {

        username = ""
        searchResults.removeAll()
        error = nil
    }
}
