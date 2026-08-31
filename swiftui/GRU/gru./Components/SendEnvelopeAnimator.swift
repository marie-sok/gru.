//
//  SendEnvelopeAnimator.swift
//  gru.
//
//  Created by Maria Morozova on 03.07.2026.
//


import SwiftUI

struct SendEnvelopeAnimator: View {

    @Binding var trigger: Bool

    @State private var offset: CGFloat = 0
    @State private var scale: CGFloat = 1
    @State private var rotation: Double = 0

    var body: some View {

        GRUEnvelope()
            .stroke(
                GRUColors.accent,
                style: StrokeStyle(lineWidth: 2.2, lineJoin: .round)
            )
            .frame(width: 28, height: 20)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(x: offset)
            .onChange(of: trigger) { _, newValue in

                if newValue {
                    play()
                }
            }
    }

    private func play() {

        offset = 0
        scale = 1
        rotation = 0

        withAnimation(.easeIn(duration: 0.15)) {
            scale = 0.85
            rotation = -10
        }

        withAnimation(.easeInOut(duration: 0.45).delay(0.15)) {
            offset = 60
            scale = 0.6
            rotation = 20
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            reset()
        }
    }

    private func reset() {

        offset = 0
        scale = 1
        rotation = 0
        trigger = false
    }
}
