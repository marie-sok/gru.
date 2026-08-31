//
//  CatVideoBubbleShape.swift
//  gru
//
//  Created by Maria Morozova on 26.08.2026.
//


import SwiftUI

struct CatVideoBubbleShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)

        let earHeight = rect.height * 0.16
        let topOffset = earHeight * 0.55

        let bodyRect = CGRect(
            x: rect.minX,
            y: rect.minY + topOffset,
            width: rect.width,
            height: rect.height - topOffset
        )

        let radius = min(bodyRect.width, bodyRect.height) / 2
        let centerX = bodyRect.midX
        let topY = bodyRect.minY

        var path = Path()

        // Основной круг
        path.addEllipse(in: bodyRect)

        // Левое ухо
        let leftOuter = CGPoint(x: centerX - radius * 0.92, y: topY + earHeight * 0.92)
        let leftTip   = CGPoint(x: centerX - radius * 0.52, y: rect.minY)
        let leftInner = CGPoint(x: centerX - radius * 0.18, y: topY + earHeight * 1.02)

        var leftEar = Path()
        leftEar.move(to: leftOuter)
        leftEar.addQuadCurve(
            to: leftTip,
            control: CGPoint(
                x: centerX - radius * 0.80,
                y: rect.minY + earHeight * 0.15
            )
        )
        leftEar.addQuadCurve(
            to: leftInner,
            control: CGPoint(
                x: centerX - radius * 0.28,
                y: rect.minY + earHeight * 0.10
            )
        )
        leftEar.addQuadCurve(
            to: leftOuter,
            control: CGPoint(
                x: centerX - radius * 0.55,
                y: topY + earHeight * 0.55
            )
        )
        path.addPath(leftEar)

        // Правое ухо
        let rightOuter = CGPoint(x: centerX + radius * 0.92, y: topY + earHeight * 0.92)
        let rightTip   = CGPoint(x: centerX + radius * 0.52, y: rect.minY)
        let rightInner = CGPoint(x: centerX + radius * 0.18, y: topY + earHeight * 1.02)

        var rightEar = Path()
        rightEar.move(to: rightOuter)
        rightEar.addQuadCurve(
            to: rightTip,
            control: CGPoint(
                x: centerX + radius * 0.80,
                y: rect.minY + earHeight * 0.15
            )
        )
        rightEar.addQuadCurve(
            to: rightInner,
            control: CGPoint(
                x: centerX + radius * 0.28,
                y: rect.minY + earHeight * 0.10
            )
        )
        rightEar.addQuadCurve(
            to: rightOuter,
            control: CGPoint(
                x: centerX + radius * 0.55,
                y: topY + earHeight * 0.55
            )
        )
        path.addPath(rightEar)

        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}