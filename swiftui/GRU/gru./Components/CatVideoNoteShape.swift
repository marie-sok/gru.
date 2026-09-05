import SwiftUI

/// Compact GRU cat-note silhouette: visually almost circular, with two soft
/// ear bumps integrated into the outline. No separate triangles are drawn.
struct CatVideoNoteShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard bounds.width > 0, bounds.height > 0 else { return Path() }

        let w = bounds.width
        let h = bounds.height
        let cx = bounds.midX

        let top = bounds.minY + h * 0.08
        let earBaseY = bounds.minY + h * 0.18
        let shoulderY = bounds.minY + h * 0.25
        let midY = bounds.minY + h * 0.53
        let bottom = bounds.maxY - h * 0.055

        var path = Path()
        path.move(to: CGPoint(x: cx, y: bottom))

        path.addCurve(
            to: CGPoint(x: bounds.minX + w * 0.055, y: midY),
            control1: CGPoint(x: bounds.minX + w * 0.24, y: bottom),
            control2: CGPoint(x: bounds.minX + w * 0.055, y: bounds.minY + h * 0.78)
        )

        path.addCurve(
            to: CGPoint(x: bounds.minX + w * 0.18, y: shoulderY),
            control1: CGPoint(x: bounds.minX + w * 0.045, y: bounds.minY + h * 0.38),
            control2: CGPoint(x: bounds.minX + w * 0.10, y: bounds.minY + h * 0.29)
        )

        path.addCurve(
            to: CGPoint(x: bounds.minX + w * 0.31, y: top),
            control1: CGPoint(x: bounds.minX + w * 0.215, y: bounds.minY + h * 0.19),
            control2: CGPoint(x: bounds.minX + w * 0.265, y: bounds.minY + h * 0.105)
        )

        path.addCurve(
            to: CGPoint(x: bounds.minX + w * 0.41, y: earBaseY),
            control1: CGPoint(x: bounds.minX + w * 0.345, y: bounds.minY + h * 0.095),
            control2: CGPoint(x: bounds.minX + w * 0.39, y: bounds.minY + h * 0.15)
        )

        path.addCurve(
            to: CGPoint(x: bounds.minX + w * 0.59, y: earBaseY),
            control1: CGPoint(x: bounds.minX + w * 0.46, y: bounds.minY + h * 0.145),
            control2: CGPoint(x: bounds.minX + w * 0.54, y: bounds.minY + h * 0.145)
        )

        path.addCurve(
            to: CGPoint(x: bounds.minX + w * 0.69, y: top),
            control1: CGPoint(x: bounds.minX + w * 0.61, y: bounds.minY + h * 0.15),
            control2: CGPoint(x: bounds.minX + w * 0.655, y: bounds.minY + h * 0.095)
        )

        path.addCurve(
            to: CGPoint(x: bounds.minX + w * 0.82, y: shoulderY),
            control1: CGPoint(x: bounds.minX + w * 0.735, y: bounds.minY + h * 0.105),
            control2: CGPoint(x: bounds.minX + w * 0.785, y: bounds.minY + h * 0.19)
        )

        path.addCurve(
            to: CGPoint(x: bounds.maxX - w * 0.055, y: midY),
            control1: CGPoint(x: bounds.maxX - w * 0.10, y: bounds.minY + h * 0.29),
            control2: CGPoint(x: bounds.maxX - w * 0.045, y: bounds.minY + h * 0.38)
        )

        path.addCurve(
            to: CGPoint(x: cx, y: bottom),
            control1: CGPoint(x: bounds.maxX - w * 0.055, y: bounds.minY + h * 0.78),
            control2: CGPoint(x: bounds.maxX - w * 0.24, y: bottom)
        )

        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

/// Deliberately minimal ear accents; the silhouette itself carries the cat
/// identity, so no inner triangle patches are rendered over the camera/video.
struct CatVideoNoteEarDetails: View {
    let width: CGFloat

    var body: some View {
        EmptyView()
            .frame(width: width, height: width)
            .allowsHitTesting(false)
    }
}
