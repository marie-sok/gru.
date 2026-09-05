import SwiftUI

private struct GRUAgentMessage: Identifiable, Codable {
    enum Author: String, Codable {
        case user
        case bot
    }

    let id: UUID
    let author: Author
    let text: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        author: Author,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.author = author
        self.text = text
        self.createdAt = createdAt
    }
}

private enum GRUAgentHistoryStore {
    static let key = "gru.bot.dialog.v4"
    private static let legacyKeys = [
        "gru.bot.dialog.v3",
        "gru.bot.history.v2",
        "gru.bot.dialog.v1"
    ]

    static func welcome() -> GRUAgentMessage {
        GRUAgentMessage(
            author: .bot,
            text: "Я gru.bot ✦ Можем просто поболтать, разобрать задачу или собрать план по шагам."
        )
    }

    static func load() -> [GRUAgentMessage] {
        let defaults = UserDefaults.standard

        if let current = decode(defaults.data(forKey: key)), !current.isEmpty {
            return current
        }

        for legacyKey in legacyKeys {
            if let legacy = decode(defaults.data(forKey: legacyKey)), !legacy.isEmpty {
                save(legacy)
                return legacy
            }
        }

        return [welcome()]
    }

    static func save(_ messages: [GRUAgentMessage]) {
        let limited = Array(messages.suffix(80))
        guard let data = try? JSONEncoder().encode(limited) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func decode(_ data: Data?) -> [GRUAgentMessage]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([GRUAgentMessage].self, from: data)
    }
}

@MainActor
struct GRUAgentView: View {
    @State private var messages = GRUAgentHistoryStore.load()
    @State private var text = ""
    @State private var isSending = false
    @State private var errorText: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.14)
            conversation
        }
        .background(GRUColors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .navigationTitle("gru.bot")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(GRUColors.accent.opacity(0.13))
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GRUColors.accent)
            }
            .frame(width: 38, height: 38)
            .overlay {
                Circle().stroke(GRUColors.accent.opacity(0.24), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("gru.bot")
                    .font(.headline)
                Text(isSending ? "думает…" : "AI • chat + planner")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button(role: .destructive) {
                    GRUAgentHistoryStore.clear()
                    messages = [GRUAgentHistoryStore.welcome()]
                    errorText = nil
                } label: {
                    Label("Очистить диалог", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(GRUColors.text)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    quickPrompts

                    ForEach(messages) { message in
                        HStack(alignment: .bottom, spacing: 8) {
                            if message.author == .user {
                                Spacer(minLength: 42)
                            }

                            VStack(alignment: message.author == .user ? .trailing : .leading, spacing: 4) {
                                Text(message.text)
                                    .font(.body)
                                    .foregroundStyle(GRUColors.text)
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 10)
                                    .background(
                                        message.author == .user
                                            ? GRUColors.accent.opacity(0.18)
                                            : GRUColors.card.opacity(0.92),
                                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    )

                                Text(message.createdAt, style: .time)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                            }

                            if message.author == .bot {
                                Spacer(minLength: 42)
                            }
                        }
                        .id(message.id)
                    }

                    if isSending {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(GRUColors.accent)
                            Text("gru.bot думает…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .onChange(of: messages.count) { _, _ in
                guard let lastID = messages.last?.id else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private var quickPrompts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                promptButton("Составь план", icon: "checklist")
                promptButton("Помоги подумать", icon: "brain.head.profile")
                promptButton("Просто поболтаем", icon: "bubble.left.and.bubble.right.fill")
            }
        }
        .padding(.bottom, 2)
    }

    private func promptButton(_ title: String, icon: String) -> some View {
        Button {
            text = title
            inputFocused = true
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(GRUColors.accent)
                .padding(.horizontal, 11)
                .frame(height: 31)
                .background(GRUColors.accent.opacity(0.08), in: Capsule())
                .overlay {
                    Capsule().stroke(GRUColors.accent.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var composer: some View {
        VStack(spacing: 5) {
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
            }

            HStack(spacing: 9) {
                TextField("Сообщение gru.bot", text: $text, axis: .vertical)
                    .focused($inputFocused)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(GRUColors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .onSubmit {
                        send()
                    }

                Button {
                    send()
                } label: {
                    GRUNeonIcon(
                        systemName: "arrow.up",
                        size: 40,
                        iconSize: 16,
                        isActive: canSend
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private func send() {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isSending else { return }

        let history = messages.suffix(30).map { message in
            GRUBotTurnDTO(
                role: message.author == .user ? "user" : "assistant",
                text: message.text
            )
        }

        messages.append(
            GRUAgentMessage(author: .user, text: clean)
        )
        GRUAgentHistoryStore.save(messages)

        text = ""
        inputFocused = false
        isSending = true
        errorText = nil

        Task {
            do {
                let response = try await GRUBotService.shared.ask(
                    text: clean,
                    history: history
                )

                messages.append(
                    GRUAgentMessage(author: .bot, text: response.reply)
                )
                GRUAgentHistoryStore.save(messages)
                isSending = false
            } catch {
                errorText = "gru.bot: \(error.localizedDescription)"
                isSending = false
            }
        }
    }
}

@MainActor
struct GRUAgentCard: View {
    var body: some View {
        NavigationLink {
            GRUAgentView()
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    Circle().fill(GRUColors.accent.opacity(0.12))
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(GRUColors.accent)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("gru.bot")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("поболтать • подумать • спланировать")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .frame(height: 56)
            .background(GRUColors.card.opacity(0.76), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
