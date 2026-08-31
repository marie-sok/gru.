import SwiftUI

/// Фирменная форма GRU для video note:
/// почти идеальный круг + небольшие кошачьи ушки сверху.
struct CatVideoNoteShape: InsettableShape {

    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(
            dx: insetAmount,
            dy: insetAmount
        )

        guard bounds.width > 0, bounds.height > 0 else {
            return Path()
        }

        // Основная часть остаётся круглой.
        // При bubble 220 x 238 круг получается примерно 220 x 220,
        // а верхняя зона используется под ушки.
        let diameter = min(
            bounds.width,
            bounds.height * 0.925
        )

        let radius = diameter / 2

        let headRect = CGRect(
            x: bounds.midX - radius,
            y: bounds.maxY - diameter,
            width: diameter,
            height: diameter
        )

        let cx = headRect.midX
        let cy = headRect.midY
        let r = radius

        func point(
            _ x: CGFloat,
            _ y: CGFloat
        ) -> CGPoint {
            CGPoint(
                x: cx + r * x,
                y: cy + r * y
            )
        }

        var path = Path()

        path.move(
            to: point(0.0, 1.0)
        )

        // Левая нижняя четверть круга.
        path.addCurve(
            to: point(-1.0, 0.0),
            control1: point(-0.56, 1.0),
            control2: point(-1.0, 0.56)
        )

        // Левая верхняя часть круглой головы.
        path.addCurve(
            to: point(-0.82, -0.56),
            control1: point(-1.0, -0.25),
            control2: point(-0.94, -0.43)
        )

        // Левое ухо.
        path.addCurve(
            to: CGPoint(
                x: cx - r * 0.56,
                y: bounds.minY + max(1, insetAmount)
            ),
            control1: point(-0.78, -0.71),
            control2: CGPoint(
                x: cx - r * 0.68,
                y: bounds.minY + r * 0.03
            )
        )

        path.addCurve(
            to: point(-0.28, -0.82),
            control1: CGPoint(
                x: cx - r * 0.43,
                y: bounds.minY + r * 0.02
            ),
            control2: point(-0.34, -0.74)
        )

        // Мягкий лоб между ушками.
        path.addCurve(
            to: point(0.28, -0.82),
            control1: point(-0.12, -0.93),
            control2: point(0.12, -0.93)
        )

        // Правое ухо.
        path.addCurve(
            to: CGPoint(
                x: cx + r * 0.56,
                y: bounds.minY + max(1, insetAmount)
            ),
            control1: point(0.34, -0.74),
            control2: CGPoint(
                x: cx + r * 0.43,
                y: bounds.minY + r * 0.02
            )
        )

        path.addCurve(
            to: point(0.82, -0.56),
            control1: CGPoint(
                x: cx + r * 0.68,
                y: bounds.minY + r * 0.03
            ),
            control2: point(0.78, -0.71)
        )

        // Правая верхняя часть.
        path.addCurve(
            to: point(1.0, 0.0),
            control1: point(0.94, -0.43),
            control2: point(1.0, -0.25)
        )

        // Правая нижняя четверть.
        path.addCurve(
            to: point(0.0, 1.0),
            control1: point(1.0, 0.56),
            control2: point(0.56, 1.0)
        )

        path.closeSubpath()

        return path
    }

    func inset(
        by amount: CGFloat
    ) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

/// High-contrast inner ear marks keep the GRU cat silhouette readable even
/// when the camera frame or a dark video makes the outer outline subtle.
struct CatVideoNoteEarDetails: View {
    let width: CGFloat

    var body: some View {
        HStack(spacing: width * 0.22) {
            ear
            ear
        }
        .frame(width: width * 0.58, height: width * 0.16)
        .offset(y: width * 0.035)
        .allowsHitTesting(false)
    }

    private var ear: some View {
        CatVideoNoteEarShape()
            .fill(GRUColors.accent.opacity(0.30))
            .overlay {
                CatVideoNoteEarShape()
                    .stroke(GRUColors.accent.opacity(0.78), lineWidth: 1.1)
            }
            .frame(width: width * 0.13, height: width * 0.11)
            .shadow(color: GRUColors.accent.opacity(0.55), radius: 4)
    }
}

private struct CatVideoNoteEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY * 0.82)
        )
        path.closeSubpath()
        return path
    }
}
