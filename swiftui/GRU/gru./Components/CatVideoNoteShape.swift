import SwiftUI

/// Single continuous cat silhouette used by GRU video notes.
/// The ears are part of the same curved path as the face: no separate
/// triangular masks or filled triangle overlays are used.
struct CatVideoNoteShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height

        let topY = height * 0.085
        let cheekY = height * 0.515
        let bottomY = height * 0.945

        let leftX = width * 0.055
        let rightX = width * 0.945

        let leftEarOuter = CGPoint(x: width * 0.16, y: height * 0.22)
        let leftEarTip = CGPoint(x: width * 0.28, y: topY)
        let leftEarInner = CGPoint(x: width * 0.40, y: height * 0.185)

        let rightEarInner = CGPoint(x: width * 0.60, y: height * 0.185)
        let rightEarTip = CGPoint(x: width * 0.72, y: topY)
        let rightEarOuter = CGPoint(x: width * 0.84, y: height * 0.22)

        var path = Path()
        path.move(to: CGPoint(x: width * 0.50, y: bottomY))

        path.addCurve(
            to: CGPoint(x: leftX, y: cheekY),
            control1: CGPoint(x: width * 0.23, y: bottomY),
            control2: CGPoint(x: leftX, y: height * 0.76)
        )

        path.addCurve(
            to: leftEarOuter,
            control1: CGPoint(x: leftX, y: height * 0.36),
            control2: CGPoint(x: width * 0.09, y: height * 0.25)
        )

        path.addCurve(
            to: leftEarTip,
            control1: CGPoint(x: width * 0.20, y: height * 0.18),
            control2: CGPoint(x: width * 0.245, y: height * 0.11)
        )

        path.addCurve(
            to: leftEarInner,
            control1: CGPoint(x: width * 0.305, y: height * 0.105),
            control2: CGPoint(x: width * 0.35, y: height * 0.155)
        )

        path.addCurve(
            to: rightEarInner,
            control1: CGPoint(x: width * 0.455, y: height * 0.155),
            control2: CGPoint(x: width * 0.545, y: height * 0.155)
        )

        path.addCurve(
            to: rightEarTip,
            control1: CGPoint(x: width * 0.65, y: height * 0.155),
            control2: CGPoint(x: width * 0.695, y: height * 0.105)
        )

        path.addCurve(
            to: rightEarOuter,
            control1: CGPoint(x: width * 0.755, y: height * 0.11),
            control2: CGPoint(x: width * 0.80, y: height * 0.18)
        )

        path.addCurve(
            to: CGPoint(x: rightX, y: cheekY),
            control1: CGPoint(x: width * 0.91, y: height * 0.25),
            control2: CGPoint(x: rightX, y: height * 0.36)
        )

        path.addCurve(
            to: CGPoint(x: width * 0.50, y: bottomY),
            control1: CGPoint(x: rightX, y: height * 0.76),
            control2: CGPoint(x: width * 0.77, y: bottomY)
        )

        path.closeSubpath()
        return path
    }
}

/// Soft inner-ear accents. They are open Bezier strokes rather than
/// triangles, so camera/video-note UI never shows geometric triangle patches.
struct CatVideoNoteEarDetails: View {
    let width: CGFloat

    var body: some View {
        ZStack {
            CatVideoNoteInnerEarShape(side: .left)
                .stroke(
                    GRUColors.accentSecondary.opacity(0.42),
                    style: StrokeStyle(lineWidth: max(1, width * 0.007), lineCap: .round)
                )

            CatVideoNoteInnerEarShape(side: .right)
                .stroke(
                    GRUColors.accentSecondary.opacity(0.42),
                    style: StrokeStyle(lineWidth: max(1, width * 0.007), lineCap: .round)
                )
        }
        .frame(width: width, height: width * 1.02)
        .allowsHitTesting(false)
    }
}

private struct CatVideoNoteInnerEarShape: Shape {
    enum Side {
        case left
        case right
    }

    let side: Side

    func path(in rect: CGRect) -> Path {
        let mirrored: (CGFloat) -> CGFloat = { x in
            side == .left ? x : 1 - x
        }

        var path = Path()
        path.move(
            to: CGPoint(
                x: rect.width * mirrored(0.205),
                y: rect.height * 0.205
            )
        )
        path.addQuadCurve(
            to: CGPoint(
                x: rect.width * mirrored(0.345),
                y: rect.height * 0.202
            ),
            control: CGPoint(
                x: rect.width * mirrored(0.275),
                y: rect.height * 0.115
            )
        )
        return path
    }
}
