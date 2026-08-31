//
//  TypingIndicator.swift
//  gru.
//
//  Created by Maria Morozova on 06.07.2026.
//


import SwiftUI

struct TypingIndicator: View {

    @State private var animate = false

    var body: some View {

        HStack(spacing: 4) {

            dot(delay: 0)

            dot(delay: 0.2)

            dot(delay: 0.4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(GRUColors.card)
        .clipShape(Capsule())
        .onAppear {

            animate = true
        }
    }

    private func dot(delay: Double) -> some View {

        Circle()
            .fill(.secondary)
            .frame(width: 6, height: 6)
            .scaleEffect(animate ? 1 : 0.5)
            .animation(
                .easeInOut(duration: 0.6)
                    .repeatForever()
                    .delay(delay),
                value: animate
            )
    }
}

#Preview {

    TypingIndicator()
}