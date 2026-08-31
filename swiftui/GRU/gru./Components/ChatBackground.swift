import SwiftUI

enum ChatBackgroundStyle: String, CaseIterable, Identifiable {
    case obsidian
    case neonGrid
    case violetFog
    case cyanOrbit
    case midnightPaws
    case aurora
    case graphitePulse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .obsidian: return "Obsidian"
        case .neonGrid: return "Neon Grid"
        case .violetFog: return "Violet Fog"
        case .cyanOrbit: return "Cyan Orbit"
        case .midnightPaws: return "Midnight Paws"
        case .aurora: return "GRU Aurora"
        case .graphitePulse: return "Graphite Pulse"
        }
    }

    var icon: String {
        switch self {
        case .obsidian: return "circle.lefthalf.filled"
        case .neonGrid: return "grid"
        case .violetFog: return "cloud.fog.fill"
        case .cyanOrbit: return "circle.dotted"
        case .midnightPaws: return "pawprint.fill"
        case .aurora: return "sparkles"
        case .graphitePulse: return "waveform.path.ecg"
        }
    }
}

struct ChatBackgroundView: View {
    let style: ChatBackgroundStyle

    var body: some View {
        ZStack {
            base
            decoration
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var base: some View {
        switch style {
        case .obsidian:
            LinearGradient(
                colors: [Color.black, GRUColors.background, Color.black.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neonGrid:
            LinearGradient(
                colors: [GRUColors.background, Color.black, GRUColors.accent.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .violetFog:
            LinearGradient(
                colors: [Color.black, Color.purple.opacity(0.24), GRUColors.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cyanOrbit:
            RadialGradient(
                colors: [GRUColors.accent.opacity(0.22), Color.black.opacity(0.96)],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 620
            )
        case .midnightPaws:
            LinearGradient(
                colors: [Color.black, GRUColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
        case .aurora:
            LinearGradient(
                colors: [Color.black, Color.purple.opacity(0.18), GRUColors.accent.opacity(0.18), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .graphitePulse:
            LinearGradient(
                colors: [Color.black.opacity(0.98), Color.gray.opacity(0.16), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var decoration: some View {
        switch style {
        case .obsidian:
            Circle()
                .fill(GRUColors.accent.opacity(0.08))
                .frame(width: 330, height: 330)
                .blur(radius: 70)
                .offset(x: 150, y: -260)

        case .neonGrid:
            Canvas { context, size in
                let step: CGFloat = 34
                var path = Path()
                stride(from: CGFloat.zero, through: size.width, by: step).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: CGFloat.zero, through: size.height, by: step).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(GRUColors.accent.opacity(0.075)), lineWidth: 0.7)
            }

        case .violetFog:
            ZStack {
                Circle().fill(Color.purple.opacity(0.16)).frame(width: 270, height: 270).blur(radius: 55).offset(x: -130, y: -220)
                Circle().fill(GRUColors.accent.opacity(0.12)).frame(width: 250, height: 250).blur(radius: 60).offset(x: 150, y: 270)
            }

        case .cyanOrbit:
            ZStack {
                Circle().stroke(GRUColors.accent.opacity(0.12), lineWidth: 1).frame(width: 340, height: 340).offset(x: 130, y: -230)
                Circle().stroke(GRUColors.accent.opacity(0.07), lineWidth: 1).frame(width: 245, height: 245).offset(x: 130, y: -230)
            }

        case .midnightPaws:
            VStack(spacing: 78) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 72) {
                        ForEach(0..<4, id: \.self) { column in
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(GRUColors.accent.opacity(0.055))
                                .rotationEffect(.degrees(Double((row + column) % 2 == 0 ? -12 : 12)))
                        }
                    }
                    .offset(x: row.isMultiple(of: 2) ? -30 : 20)
                }
            }
            .rotationEffect(.degrees(-8))

        case .aurora:
            ZStack {
                Capsule().fill(Color.purple.opacity(0.14)).frame(width: 430, height: 90).blur(radius: 38).rotationEffect(.degrees(-28)).offset(x: -90, y: -190)
                Capsule().fill(GRUColors.accent.opacity(0.13)).frame(width: 460, height: 92).blur(radius: 42).rotationEffect(.degrees(-28)).offset(x: 95, y: 150)
            }

        case .graphitePulse:
            Canvas { context, size in
                var path = Path()
                let mid = size.height * 0.44
                path.move(to: CGPoint(x: 0, y: mid))
                let points: [CGPoint] = [
                    .init(x: size.width * 0.18, y: mid),
                    .init(x: size.width * 0.25, y: mid - 24),
                    .init(x: size.width * 0.32, y: mid + 34),
                    .init(x: size.width * 0.39, y: mid - 52),
                    .init(x: size.width * 0.47, y: mid),
                    .init(x: size.width, y: mid)
                ]
                points.forEach { path.addLine(to: $0) }
                context.stroke(path, with: .color(GRUColors.accent.opacity(0.10)), lineWidth: 1.2)
            }
        }
    }
}

struct ChatBackgroundPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRawValue: String

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(ChatBackgroundStyle.allCases) { style in
                        Button {
                            selectedRawValue = style.rawValue
                            dismiss()
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                ChatBackgroundView(style: style)
                                    .frame(height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                                HStack(spacing: 8) {
                                    GRUNeonIcon(systemName: style.icon, size: 30, iconSize: 13)
                                    Text(style.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Spacer(minLength: 0)
                                    if selectedRawValue == style.rawValue {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(GRUColors.accent)
                                    }
                                }
                                .padding(10)
                                .background(.black.opacity(0.38))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(GRUColors.background)
            .navigationTitle("Фон чата")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
