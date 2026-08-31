//
//  SidebarContactsView.swift
//  gru.
//
//  Created by Maria Morozova on 03.07.2026.
//


import SwiftUI

struct SidebarContactsView: View {

    @Binding var isOpen: Bool

    private let users = (1...20).map {
        User(
            username: "user\($0)",
            displayName: "User \($0)"
        )
    }

    private var currentUser: User {
        ChatService.shared.currentUser
    }

    var body: some View {

        ZStack(alignment: .leading) {

            if isOpen {

                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture {

                        withAnimation(.spring()) {

                            isOpen = false
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 0) {

                Text("Контакты")
                    .font(.largeTitle.bold())
                    .padding(.top, 70)
                    .padding(.horizontal, 24)

                ScrollView {

                    LazyVStack(spacing: 14) {

                        ForEach(users) { user in

                            ContactRow(
                                chat: Chat(
                                    users: [
                                        currentUser,
                                        user
                                    ]
                                )
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 25)
                }
            }
            .frame(width: 285)
            .frame(maxHeight: .infinity)
            .background(GRUColors.card)
            .offset(x: isOpen ? 0 : -300)
            .animation(.spring(response: 0.35,
                               dampingFraction: 0.82),
                       value: isOpen)
        }
    }
}
