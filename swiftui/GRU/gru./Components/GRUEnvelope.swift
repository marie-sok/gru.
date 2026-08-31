//
//  GRUEnvelope.swift
//  gru.
//
//  Marie Sok on 03.07.2026.
//


import SwiftUI

struct GRUEnvelope: Shape {

    func path(in rect: CGRect) -> Path {

        var path = Path()

        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: 0, y: h * 0.18))
        path.addLine(to: CGPoint(x: w, y: h * 0.18))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()

        path.move(to: CGPoint(x: 0, y: h * 0.18))
        path.addLine(to: CGPoint(x: w / 2, y: h * 0.60))
        path.addLine(to: CGPoint(x: w, y: h * 0.18))

        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w / 2, y: h * 0.55))
        path.addLine(to: CGPoint(x: w, y: h))

        return path
    }
}
