//
//  RootView.swift
//  gru.
//
//  Created Marie Sok on 27.06.2026.
//

import SwiftUI

struct LegacyRootView: View {

    @State private var loggedIn = TokenStorage.shared.token != nil

    var body: some View {

        Group {

            if loggedIn {

                MainView()

            } else {

                LoginView {

                    withAnimation(.easeInOut(duration: 0.25)) {
                        loggedIn = true
                    }
                }
            }
        }
    }
}

#Preview {

    LegacyRootView()
}
