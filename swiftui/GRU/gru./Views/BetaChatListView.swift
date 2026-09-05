import SwiftUI
import UIKit

@MainActor
struct BetaChatListView: View {
    private let onChatPresentationChanged: (Bool) -> Void

    @State private var service = ChatService.shared
    @State private var socket = WebSocketService.shared
    @State private var showingNewChat = false
    @State private var searchText = ""
    @State private var pendingDeleteChat: Chat?
    @State private var deletingChatServerID: String?
    @State private var realtimeListeners: [String: UUID] = [:]

    init(onChatPresentationChanged: @escaping (Bool) -> Void = { _ in }) {
        self.onChatPresentationChanged = onChatPresentationChanged
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GRUAppBackdrop()

                VStack(spacing: 6) {
                    searchField
                        .padding(.horizontal, 12)
                        .padding(.top, 5)

                    if service.chatLoadingError != nil || service.isUsingCachedChats {
                        compactConnectionNotice
                            .padding(.horizontal, 12)
                    }

                    content
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        GRUAgentView()
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(GRUColors.accent)
                            .frame(width: 36, height: 36)
                            .background(GRUColors.accent.opacity(0.09), in: Circle())
                    }
                    .accessibilityLabel("gru.bot")
                }

                ToolbarItem(placement: .principal) {
                    Text("gru.")
                        .font(.custom("AvenirNext-DemiBold", size: 24))
                        .tracking(-0.8)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    GRUNeonIconButton(
                        systemName: "envelope.fill",
                        accessibilityLabel: "Новый чат",
                        size: 36,
                        iconSize: 14
                    ) {
                        showingNewChat = true
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingNewChat, onDismiss: {
            Task {
                await service.loadChats()
                syncRealtimeSubscriptions()
                connectWebSocket()
            }
        }) {
            NewChatView()
        }
        .task {
            await loadData()
        }
        .onAppear {
            syncRealtimeSubscriptions()
            connectWebSocket()
        }
        .confirmationDialog(
            "Удалить чат целиком?",
            isPresented: Binding(
                get: { pendingDeleteChat != nil },
                set: { if !$0 { pendingDeleteChat = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Удалить чат у обоих", role: .destructive) {
                if let chat = pendingDeleteChat {
                    deleteChatEverywhere(chat)
                }
            }
            Button("Отмена", role: .cancel) {
                pendingDeleteChat = nil
            }
        } message: {
            Text("История и вложения будут удалены с сервера.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if !showsTestChat && filteredChats.isEmpty && !service.isLoadingChats {
            emptyState
        } else {
            List {
                if showsTestChat {
                    NavigationLink {
                        GRUBetaTestChatView()
                            .onAppear { onChatPresentationChanged(true) }
                            .onDisappear { onChatPresentationChanged(false) }
                    } label: {
                        testChatRow
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(
                        EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
                    )
                }

                if service.isLoadingChats && service.chats.isEmpty {
                    HStack(spacing: 9) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(GRUColors.accent)
                        Text("Синхронизирую реальные чаты…")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                ForEach(filteredChats) { chat in
                    NavigationLink {
                        ChatView(chat: chat)
                            .onAppear {
                                onChatPresentationChanged(true)
                            }
                            .onDisappear {
                                onChatPresentationChanged(false)
                            }
                    } label: {
                        ChatRow(chat: chat)
                            .opacity(deletingChatServerID == chat.serverID ? 0.42 : 1)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(
                        EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeleteChat = chat
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                        .disabled(deletingChatServerID != nil)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable {
                await service.loadChats()
                syncRealtimeSubscriptions()
                connectWebSocket()
            }
        }
    }

    private var testChatRow: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(GRUColors.accent.opacity(0.14))
                Image(systemName: "testtube.2")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GRUColors.accent)
            }
            .frame(width: 46, height: 46)
            .overlay {
                Circle()
                    .stroke(GRUColors.accent.opacity(0.28), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("gru. test lab")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("BETA")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(GRUColors.accent)
                        .padding(.horizontal, 6)
                        .frame(height: 17)
                        .background(GRUColors.accent.opacity(0.10), in: Capsule())
                }

                Text("Локальный тестовый чат • работает без backend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 62)
        .background(
            GRUColors.card.opacity(0.70),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(GRUColors.accent.opacity(0.13), lineWidth: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Поиск", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(GRUColors.card.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        }
    }

    private var compactConnectionNotice: some View {
        HStack(spacing: 7) {
            Image(systemName: socket.isConnected ? "checkmark.circle.fill" : "wifi.slash")
                .font(.system(size: 11, weight: .bold))
            Text(service.isUsingCachedChats ? "offline • показываю сохранённые чаты" : "backend недоступен • test lab работает")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(GRUColors.card.opacity(0.52), in: Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(GRUColors.accent)

            Text("Ничего не найдено")
                .font(.headline)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var showsTestChat: Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        return "gru. test lab тестовый чат beta local"
            .localizedCaseInsensitiveContains(query)
    }

    private var filteredChats: [Chat] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return service.chats }

        return service.chats.filter { chat in
            let usersMatch = chat.users.contains {
                $0.displayName.localizedCaseInsensitiveContains(query) ||
                $0.username.localizedCaseInsensitiveContains(query)
            }
            let titleMatch = chat.title?.localizedCaseInsensitiveContains(query) == true
            let messageMatch = chat.messages.last?.text.localizedCaseInsensitiveContains(query) == true
            return usersMatch || titleMatch || messageMatch
        }
    }

    private func loadData() async {
        await service.loadChats()
        syncRealtimeSubscriptions()
        connectWebSocket()
    }

    private func connectWebSocket() {
        guard let token = TokenStorage.shared.token, !token.isEmpty else { return }
        WebSocketService.shared.connect(token: token)
    }

    private func syncRealtimeSubscriptions() {
        let serverChatIDs = Set(service.chats.compactMap(\.serverID))

        for chatID in Array(realtimeListeners.keys) {
            guard !serverChatIDs.contains(chatID),
                  let listenerID = realtimeListeners[chatID] else { continue }

            WebSocketService.shared.removeListener(
                chatID: chatID,
                listenerID: listenerID
            )
            realtimeListeners[chatID] = nil
        }

        for chat in service.chats {
            guard let chatID = chat.serverID,
                  realtimeListeners[chatID] == nil else { continue }

            let listenerID = WebSocketService.shared.addListener(chatID: chatID) { message in
                handleRealtimeMessage(message)
            }
            realtimeListeners[chatID] = listenerID
        }
    }

    private func handleRealtimeMessage(_ message: ServerMessageDTO) {
        if message.text == "__GRU_CHAT_DELETED__" {
            if let chat = service.chats.first(where: { $0.serverID == message.chatId }) {
                service.deleteChat(chat.id)
                syncRealtimeSubscriptions()
            }
            return
        }

        markDeliveredIfNeeded(message)
    }

    private func markDeliveredIfNeeded(_ message: ServerMessageDTO) {
        guard let currentUserID = service.currentUser.serverID,
              message.receiverId == currentUserID,
              message.readAt == nil,
              message.deliveredAt == nil,
              let token = TokenStorage.shared.token,
              !token.isEmpty else {
            return
        }

        Task {
            do {
                _ = try await MessageAPIService.shared.markDelivered(
                    messageID: message.id,
                    token: token
                )
            } catch {
                print("❌ Mark delivered error:", error.localizedDescription)
            }
        }
    }

    private func deleteChatEverywhere(_ chat: Chat) {
        guard let serverID = chat.serverID,
              !serverID.isEmpty,
              let token = TokenStorage.shared.token,
              !token.isEmpty else {
            return
        }

        pendingDeleteChat = nil
        deletingChatServerID = serverID

        Task {
            defer { deletingChatServerID = nil }
            do {
                try await ChatAPIService.shared.deleteChat(
                    chatID: serverID,
                    token: token
                )
                service.deleteChat(chat.id)
                syncRealtimeSubscriptions()
            } catch {
                print("❌ Delete chat error:", error)
            }
        }
    }
}

private struct GRUBetaLocalMessage: Identifiable {
    enum Author {
        case me
        case lab
    }

    let id = UUID()
    let author: Author
    let text: String
    let createdAt: Date

    init(author: Author, text: String, createdAt: Date = Date()) {
        self.author = author
        self.text = text
        self.createdAt = createdAt
    }

    static var seed: [GRUBetaLocalMessage] {
        [
            GRUBetaLocalMessage(
                author: .lab,
                text: "Это локальный test lab. Он не зависит от backend — здесь можно проверять чат, ввод и анимацию тем."
            ),
            GRUBetaLocalMessage(
                author: .lab,
                text: "Нажми палитру сверху: каждые касание переключает следующую из 9 фирменных тем gru."
            )
        ]
    }
}

@MainActor
private struct GRUBetaTestChatView: View {
    @AppStorage(GRUTheme.selectionKey)
    private var themeRaw = GRUAppTheme.blackMoonCat.rawValue

    @State private var messages = GRUBetaLocalMessage.seed
    @State private var text = ""
    @FocusState private var inputFocused: Bool

    private var currentTheme: GRUAppTheme {
        let candidate = GRUAppTheme(rawValue: themeRaw) ?? .blackMoonCat
        return GRUThemePolicy.allowed.contains(candidate) ? candidate : .blackMoonCat
    }

    var body: some View {
        ZStack {
            GRUSignatureWallpaper(
                theme: currentTheme,
                intensity: 1.0,
                animated: true
            )
            .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            HStack(alignment: .bottom) {
                                if message.author == .me {
                                    Spacer(minLength: 54)
                                }

                                VStack(alignment: message.author == .me ? .trailing : .leading, spacing: 4) {
                                    Text(message.text)
                                        .font(.body)
                                        .foregroundStyle(GRUColors.text)
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 10)
                                        .background(
                                            message.author == .me
                                                ? currentTheme.accent.opacity(0.24)
                                                : GRUColors.card.opacity(0.90),
                                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        )
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(
                                                    message.author == .me
                                                        ? currentTheme.accent.opacity(0.30)
                                                        : Color.white.opacity(0.05),
                                                    lineWidth: 1
                                                )
                                        }

                                    Text(message.createdAt, style: .time)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }

                                if message.author == .lab {
                                    Spacer(minLength: 54)
                                }
                            }
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 16)
                }
                .onChange(of: messages.count) { _, _ in
                    guard let lastID = messages.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle("gru. test lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    cycleTheme()
                } label: {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(currentTheme.accent)
                }
                .accessibilityLabel("Следующая тема")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
    }

    private var composer: some View {
        HStack(spacing: 9) {
            TextField("Тестовое сообщение", text: $text, axis: .vertical)
                .focused($inputFocused)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    GRUColors.card.opacity(0.94),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .onSubmit { send() }

            Button {
                send()
            } label: {
                GRUNeonIcon(
                    systemName: "envelope.fill",
                    size: 42,
                    iconSize: 16,
                    isActive: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func send() {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        messages.append(
            GRUBetaLocalMessage(author: .me, text: clean)
        )
        text = ""
        inputFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            try? await Task.sleep(nanoseconds: 420_000_000)
            messages.append(
                GRUBetaLocalMessage(
                    author: .lab,
                    text: "Принято локально ✓  UI живой, backend для этого сообщения не использовался."
                )
            )
        }
    }

    private func cycleTheme() {
        let themes = GRUThemePolicy.allowed
        guard !themes.isEmpty else { return }
        let index = themes.firstIndex(of: currentTheme) ?? 0
        let next = themes[(index + 1) % themes.count]

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            themeRaw = next.rawValue
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
