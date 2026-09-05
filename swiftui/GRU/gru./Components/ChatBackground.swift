import SwiftUI

/// Only GRU signature backgrounds are exposed to the user. `obsidian` stays
/// as an internal fallback for chats created by older app versions.
enum ChatBackgroundStyle: String, CaseIterable, Identifiable {
    case obsidian
    case neonGrid
    case midnightPaws
    case aurora
    case envelopeBlueprint
    case neonCatCircuit

    static let gruThemes: [ChatBackgroundStyle] = [
        .neonGrid,
        .midnightPaws,
        .aurora,
        .envelopeBlueprint,
        .neonCatCircuit
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .obsidian: return "Obsidian Core"
        case .neonGrid: return "Neon Grid"
        case .midnightPaws: return "Midnight Paws"
        case .aurora: return "GRU Aurora"
        case .envelopeBlueprint: return "Envelope Blueprint"
        case .neonCatCircuit: return "Neon Cat Circuit"
        }
    }

    var icon: String {
        switch self {
        case .obsidian: return "circle.lefthalf.filled"
        case .neonGrid: return "grid"
        case .midnightPaws: return "pawprint.fill"
        case .aurora: return "sparkles"
        case .envelopeBlueprint: return "envelope.fill"
        case .neonCatCircuit: return "cat.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .obsidian: return "Базовый слой совместимости"
        case .neonGrid: return "Киберсетка с узлами и микросхемами"
        case .midnightPaws: return "Следы лап и тихие ночные созвездия"
        case .aurora: return "Северные ленты, звёзды и мягкий свет"
        case .envelopeBlueprint: return "Чертёж конвертов и линий доставки"
        case .neonCatCircuit: return "Кошачий контур, руны и электрические дорожки"
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
        case .midnightPaws:
            LinearGradient(
                colors: [Color.black, GRUColors.background, GRUColors.accentSecondary.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .aurora:
            LinearGradient(
                colors: [Color.black, Color.purple.opacity(0.18), GRUColors.accent.opacity(0.18), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .envelopeBlueprint:
            LinearGradient(
                colors: [Color.black, GRUColors.background, GRUColors.accentSecondary.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neonCatCircuit:
            RadialGradient(
                colors: [GRUColors.accent.opacity(0.22), GRUColors.background, Color.black.opacity(0.98)],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 620
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
                let step: CGFloat = 32
                var grid = Path()
                stride(from: CGFloat.zero, through: size.width, by: step).forEach { x in
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: CGFloat.zero, through: size.height, by: step).forEach { y in
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(GRUColors.accent.opacity(0.075)), lineWidth: 0.65)

                for index in 0..<14 {
                    let x = CGFloat((index * 59 + 17) % 100) / 100 * size.width
                    let y = CGFloat((index * 37 + 23) % 100) / 100 * size.height
                    var trace = Path()
                    trace.move(to: CGPoint(x: x, y: y))
                    trace.addLine(to: CGPoint(x: min(size.width, x + 18), y: y))
                    trace.addLine(to: CGPoint(x: min(size.width, x + 18), y: min(size.height, y + 12)))
                    context.stroke(trace, with: .color(GRUColors.accentSecondary.opacity(0.12)), lineWidth: 1)
                    context.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(GRUColors.accent.opacity(0.26)))
                }
            }

        case .midnightPaws:
            Canvas { context, size in
                for row in 0..<10 {
                    for column in 0..<6 {
                        let x = CGFloat(column) * 76 + CGFloat(row % 2) * 27 - 10
                        let y = CGFloat(row) * 82 - 9
                        let center = CGPoint(x: x, y: y)
                        let color = GRUColors.accent.opacity(0.055)
                        context.fill(Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 1, width: 14, height: 12)), with: .color(color))
                        for toe in 0..<3 {
                            let toeX = center.x - 12 + CGFloat(toe) * 12
                            let toeY = center.y - 12 - CGFloat((toe + row) % 2) * 2
                            context.fill(Path(ellipseIn: CGRect(x: toeX - 3, y: toeY - 3, width: 6, height: 7)), with: .color(color))
                        }
                    }
                }
            }
            .rotationEffect(.degrees(-8))

        case .aurora:
            ZStack {
                Capsule()
                    .fill(Color.purple.opacity(0.14))
                    .frame(width: 430, height: 90)
                    .blur(radius: 38)
                    .rotationEffect(.degrees(-28))
                    .offset(x: -90, y: -190)
                Capsule()
                    .fill(GRUColors.accent.opacity(0.13))
                    .frame(width: 460, height: 92)
                    .blur(radius: 42)
                    .rotationEffect(.degrees(-28))
                    .offset(x: 95, y: 150)
                Canvas { context, size in
                    for index in 0..<22 {
                        let x = CGFloat((index * 41 + 13) % 100) / 100 * size.width
                        let y = CGFloat((index * 67 + 7) % 100) / 100 * size.height
                        let radius = CGFloat(1 + index % 2)
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)), with: .color(GRUColors.accent.opacity(0.26)))
                    }
                }
            }

        case .envelopeBlueprint:
            Canvas { context, size in
                let width: CGFloat = 86
                let height: CGFloat = 54
                for row in 0..<9 {
                    for column in 0..<5 {
                        let x = CGFloat(column) * 112 + CGFloat(row % 2) * 30 - 15
                        let y = CGFloat(row) * 88 + 18
                        let rect = CGRect(x: x, y: y, width: width, height: height)
                        var envelope = Path()
                        envelope.addRoundedRect(in: rect, cornerSize: CGSize(width: 8, height: 8))
                        envelope.move(to: CGPoint(x: rect.minX + 5, y: rect.minY + 5))
                        envelope.addLine(to: CGPoint(x: rect.midX, y: rect.midY + 3))
                        envelope.addLine(to: CGPoint(x: rect.maxX - 5, y: rect.minY + 5))
                        envelope.move(to: CGPoint(x: rect.minX + 5, y: rect.maxY - 5))
                        envelope.addLine(to: CGPoint(x: rect.midX - 9, y: rect.midY + 5))
                        envelope.move(to: CGPoint(x: rect.maxX - 5, y: rect.maxY - 5))
                        envelope.addLine(to: CGPoint(x: rect.midX + 9, y: rect.midY + 5))
                        context.stroke(envelope, with: .color(GRUColors.accent.opacity(0.070)), lineWidth: 0.9)
                    }
                }
            }

        case .neonCatCircuit:
            ZStack {
                CatVideoNoteShape()
                    .stroke(GRUColors.accent.opacity(0.12), lineWidth: 2)
                    .frame(width: 250, height: 260)
                    .offset(x: 105, y: -185)
                Canvas { context, size in
                    for index in 0..<12 {
                        let y = CGFloat(index) * 62 + 18
                        var line = Path()
                        line.move(to: CGPoint(x: 0, y: y))
                        line.addLine(to: CGPoint(x: min(size.width, 34 + CGFloat(index % 4) * 30), y: y))
                        line.addLine(to: CGPoint(x: min(size.width, 34 + CGFloat(index % 4) * 30), y: y + 18))
                        context.stroke(line, with: .color(GRUColors.accentSecondary.opacity(0.12)), lineWidth: 0.9)
                    }
                }
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
                Button {
                    selectedRawValue = ChatBackgroundStyle.obsidian.rawValue
                    dismiss()
                } label: {
                    Label("Как в приложении", systemImage: selectedRawValue == ChatBackgroundStyle.obsidian.rawValue ? "checkmark.circle.fill" : "paintpalette")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(GRUThemePolicy.allowed) { style in
                        Button {
                            selectedRawValue = style.rawValue
                            dismiss()
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                GRUSignatureWallpaper(theme: style, intensity: 0.92, animated: false)
                                    .frame(height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                                HStack(spacing: 8) {
                                    GRUNeonIcon(systemName: style.icon, size: 30, iconSize: 13)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(style.title)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text(style.subtitle)
                                            .font(.system(size: 8, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.68))
                                            .lineLimit(1)
                                    }
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
