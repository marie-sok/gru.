//
//  AvatarView.swift
//  gru.
//
//  Created by Maria Morozova on 25.07.2026.
//


import SwiftUI

struct AvatarView: View {

    @AppStorage("showStatus")
    private var showStatus = true

    let user: User
    var size: CGFloat = 52

    var body: some View {

        ZStack(alignment: .bottomTrailing) {

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue,
                            Color.purple
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(.white)

            if showStatus && user.isOnline {

                Circle()
                    .fill(.green)
                    .frame(width: size * 0.22, height: size * 0.22)
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 2)
                    )
            }
        }
    }

    private var initials: String {

        let words = user.displayName.split(separator: " ")

        if words.count >= 2 {

            return "\(words[0].first!)\(words[1].first!)"
        }

        return String(user.displayName.prefix(1))
    }
}

#Preview {

    AvatarView(
        user: User(
            username: "alex",
            displayName: "Alex Brown",
            isOnline: true
        )
    )
}
