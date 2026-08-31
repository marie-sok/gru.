//
//  OnlineIndicator.swift
//  gru.
//
//  Created by Maria Morozova on 06.07.2026.
//


import SwiftUI

struct OnlineIndicator: View {

    var isOnline: Bool
    var size: CGFloat = 12

    var body: some View {

        Circle()
            .fill(isOnline ? .green : .gray.opacity(0.45))
            .frame(width: size, height: size)
            .overlay {

                Circle()
                    .stroke(.white, lineWidth: 2)
            }
    }
}

#Preview {

    VStack(spacing: 20) {

        OnlineIndicator(isOnline: true)

        OnlineIndicator(isOnline: false)
    }
}