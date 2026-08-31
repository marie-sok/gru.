//
//  GRUSendButton.swift
//  gru
//
//  Created by Maria Morozova on 24.08.2026.
//


import SwiftUI

struct GRUSendButton: View {

    let isEnabled: Bool
    let action: () -> Void

    @State
    private var isPressed = false

    var body: some View {

        Button {

            guard isEnabled else {
                return
            }

            withAnimation(
                .spring(
                    response: 0.22,
                    dampingFraction: 0.65
                )
            ) {
                isPressed = true
            }

            action()

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.18
            ) {

                withAnimation(
                    .spring(
                        response: 0.25,
                        dampingFraction: 0.75
                    )
                ) {
                    isPressed = false
                }
            }

        } label: {

            Image(
                systemName: "envelope"
            )
            .font(
                .system(
                    size: 23,
                    weight: .medium
                )
            )
            .foregroundStyle(
                isEnabled
                ? Color.primary
                : Color.secondary.opacity(0.4)
            )
            .frame(
                width: 42,
                height: 42
            )
            .scaleEffect(
                isPressed ? 0.88 : 1
            )
            .rotationEffect(
                .degrees(
                    isPressed ? -4 : 0
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(
            "Отправить сообщение"
        )
    }
}

#Preview {

    HStack(spacing: 30) {

        GRUSendButton(
            isEnabled: true
        ) {}

        GRUSendButton(
            isEnabled: false
        ) {}
    }
    .padding()
}