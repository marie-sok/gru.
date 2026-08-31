import SwiftUI

struct VoiceWaveform: View {
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
                        : Double(index) / Double(display.count - 1) <= progress

                    Capsule()
                        .fill(played ? GRUColors.accent : Color.primary.opacity(0.18))
                        .frame(width: barWidth, height: 8 + CGFloat(sample) * 30)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func normalizedSamples(width: CGFloat) -> [Double] {
        let maxBars = max(12, Int(width / (barWidth + spacing)))
        let source = samples.isEmpty ? Self.placeholder : samples
        if source.count <= maxBars {
            return source.map { max(0.05, min(1, $0)) }
        }
        let stride = Double(source.count) / Double(maxBars)
        return (0..<maxBars).map { index in
            let sourceIndex = min(source.count - 1, Int(Double(index) * stride))
            return max(0.05, min(1, source[sourceIndex]))
        }
    }

    private static let placeholder: [Double] = [
        0.18, 0.34, 0.56, 0.28, 0.73, 0.45, 0.22, 0.64,
        0.84, 0.38, 0.52, 0.29, 0.67, 0.91, 0.48, 0.33,
        0.74, 0.41, 0.58, 0.25, 0.62, 0.78, 0.36, 0.55
    ]
}
