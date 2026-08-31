//
//  ProfileViewModel.swift
//  gru.
//
//  Created by Maria Morozova on 06.07.2026.
//


import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var user: User

    init() {

        self.user = ChatService.shared.currentUser
    }

    var initials: String {

        let words = user.displayName.split(separator: " ")

        if words.count >= 2 {

            return String(words[0].prefix(1))
                + String(words[1].prefix(1))
        }

        return String(user.displayName.prefix(1))
    }

    func updateDisplayName(
        _ value: String
    ) {
        user.displayName = value
    }

    func updateUsername(
        _ value: String
    ) {
        user.username = value
    }
}

