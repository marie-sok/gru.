import SwiftUI

struct VoiceWaveform: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let samples: [Double]
    var progress: Double = 1
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            let display = normalizedSamples(width: geometry.size.width)

            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(display.enumerated()), id: \.offset) { index, sample in
                    let played = display.count <= 1
                        ? true
                        : Double(index) / Double(display.count - 1) <= clampedProgress

                    Capsule()
                        .fill(
                            played
                                ? GRUColors.accent
                                : Color.primary.opacity(0.16)
                        )
                        .frame(
                            width: barWidth,
                            height: barHeight(
                                sample: sample,
                                played: played
                            )
                        )
                        .opacity(played ? 1 : 0.74)
                        .shadow(
                            color: played
                                ? GRUColors.accent.opacity(0.32)
                                : .clear,
                            radius: played ? 3.5 : 0
                        )
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .center
            )
            .overlay(alignment: .bottomLeading) {
                Capsule()
                    .fill(GRUColors.accent.opacity(0.12))
                    .frame(
                        width: max(
                            4,
                            geometry.size.width * clampedProgress
                        ),
                        height: 1
                    )
                    .offset(y: 2)
            }
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: 0.16),
                value: clampedProgress
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GRUL10n.text("Форма голосового сообщения"))
        .accessibilityValue(
            GRUL10n.format(
                "%d процентов",
                Int((clampedProgress * 100).rounded())
            )
        )
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private func barHeight(
        sample: Double,
        played: Bool
    ) -> CGFloat {
        let normalized = max(0.05, min(1, sample))
        let base = 8 + CGFloat(normalized) * 30
        return played ? base : max(7, base * 0.82)
    }

    private func normalizedSamples(width: CGFloat) -> [Double] {
        let maxBars = max(12, Int(width / (barWidth + spacing)))
        let source = samples.isEmpty ? Self.placeholder : samples

        if source.count <= maxBars {
            return source.map { max(0.05, min(1, $0)) }
        }

        let stride = Double(source.count) / Double(maxBars)

        return (0..<maxBars).map { index in
            let sourceIndex = min(
                source.count - 1,
                Int(Double(index) * stride)
            )

            return max(
                0.05,
                min(1, source[sourceIndex])
            )
        }
    }

    private static let placeholder: [Double] = [
        0.18, 0.34, 0.56, 0.28, 0.73, 0.45, 0.22, 0.64,
        0.84, 0.38, 0.52, 0.29, 0.67, 0.91, 0.48, 0.33,
        0.74, 0.41, 0.58, 0.25, 0.62, 0.78, 0.36, 0.55
    ]
}
