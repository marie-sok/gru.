
import SwiftUI
import UIKit

private enum GRUChatFilter: String, CaseIterable, Identifiable {
    case all = "Все"
    case unread = "Новые"
    case online = "Онлайн"

    var id: String { rawValue }
}

@MainActor
struct ChatListView: View {

    private let onChatPresentationChanged: (Bool) -> Void

    init(onChatPresentationChanged: @escaping (Bool) -> Void = { _ in }) {
        self.onChatPresentationChanged = onChatPresentationChanged
    }

    // MARK: - Services

    @State
    private var service = ChatService.shared

    @State
    private var socket = WebSocketService.shared
    @State
    private var network = NetworkMonitor.shared

    // MARK: - New Chat

    @State
    private var showingNewChat = false

    // MARK: - V8 Pulse / Filters

    @State private var searchText = ""
    @State private var chatFilter: GRUChatFilter = .all
    @State private var pendingDeleteChat: Chat?
    @State private var deletingChatServerID: String?
    @AppStorage(GRUTheme.selectionKey) private var themeRaw = GRUAppTheme.obsidian.rawValue

    // MARK: - Realtime

    @State
    private var realtimeListeners:
        [String: UUID] = [:]

    // MARK: - Body

    var body: some View {

        NavigationStack {

            ZStack {

                GRUAppBackdrop()

                content
            }
            .toolbar {

                // MARK: Logo

                ToolbarItem(
                    placement: .principal
                ) {

                    Text("gru")
                        .font(
                            .custom(
                                "AvenirNext-DemiBold",
                                size: 25
                            )
                        )
                        .tracking(-0.7)
                }

                // MARK: New Chat

                ToolbarItem(
                    placement: .topBarTrailing
                ) {

                    GRUNeonIconButton(
                        systemName: "envelope.fill",
                        accessibilityLabel: "Новый чат",
                        size: 38,
                        iconSize: 15
                    ) {
                        showingNewChat = true
                    }
                }
            }
            .navigationBarTitleDisplayMode(
                .inline
            )
        }

        // MARK: New Chat Sheet

        .sheet(
            isPresented:
                $showingNewChat,
            onDismiss: {

                Task {

                    await service.loadChats()

                    syncRealtimeSubscriptions()

                    connectWebSocket()
                }
            }
        ) {

            NewChatView()
        }

        // MARK: Initial Load

        .task {
            await loadData()
        }
        .confirmationDialog(
            "Удалить чат целиком?",
            isPresented: Binding(
                get: { pendingDeleteChat != nil },
                set: { visible in if !visible { pendingDeleteChat = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Удалить чат у обоих", role: .destructive) {
                if let chat = pendingDeleteChat {
                    deleteChatEverywhere(chat)
                }
            }
            Button("Отмена", role: .cancel) { pendingDeleteChat = nil }
        } message: {
            Text("История и вложения будут удалены с сервера без служебных сообщений.")
        }
    }

    // MARK: - Delete Chat

    private func deleteChatEverywhere(_ chat: Chat) {
        guard let serverID = chat.serverID, !serverID.isEmpty,
              let token = TokenStorage.shared.token, !token.isEmpty else {
            return
        }

        pendingDeleteChat = nil
        deletingChatServerID = serverID

        Task {
            defer { deletingChatServerID = nil }
            do {
                try await ChatAPIService.shared.deleteChat(chatID: serverID, token: token)
                service.deleteChat(chat.id)
                syncRealtimeSubscriptions()
            } catch {
                print("❌ Delete chat error:", error)
            }
        }
    }

    // MARK: - Initial Load

    private func loadData() async {

        await service.loadChats()


        syncRealtimeSubscriptions()

  

        connectWebSocket()
    }

    // MARK: - WebSocket Connect

    private func connectWebSocket() {

        guard let token =
                TokenStorage.shared.token
        else {

            print("")
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )
            print(
                "❌ WebSocket: JWT token not found"
            )
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            return
        }

        WebSocketService.shared.connect(
            token: token
        )
    }

    // MARK: - Synchronize Realtime Subscriptions

    private func syncRealtimeSubscriptions() {

        let serverChatIDs =
            Set(
                service.chats.compactMap {
                    $0.serverID
                }
            )

        // MARK: Remove obsolete listeners

        let oldChatIDs =
            Array(
                realtimeListeners.keys
            )

        for chatID in oldChatIDs {

            guard
                !serverChatIDs.contains(
                    chatID
                ),
                let listenerID =
                    realtimeListeners[
                        chatID
                    ]
            else {

                continue
            }

            WebSocketService.shared
                .removeListener(
                    chatID: chatID,
                    listenerID: listenerID
                )

            realtimeListeners[
                chatID
            ] = nil

            print(
                "🧹 Realtime listener removed:",
                chatID
            )
        }

        // MARK: Add new listeners

        for chat in service.chats {

            guard let chatID =
                    chat.serverID
            else {

                continue
            }

            guard
                realtimeListeners[
                    chatID
                ] == nil
            else {

                continue
            }

            let listenerID =
                WebSocketService.shared
                    .addListener(
                        chatID: chatID
                    ) { message in

                        handleRealtimeMessage(
                            message
                        )
                    }

            realtimeListeners[
                chatID
            ] = listenerID

            print(
                "➕ Global realtime listener:",
                chatID
            )
        }
    }

    // MARK: - Global Realtime Message

    private func handleRealtimeMessage(
        _ message: ServerMessageDTO
    ) {

        print("")
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
        print(
            "🔥 CHAT LIST REALTIME MESSAGE"
        )
        print(
            "💬 chatId:",
            message.chatId
        )
        print(
            "🆔 messageId:",
            message.id
        )
        print(
            "👤 senderId:",
            message.senderId
        )
        print(
            "🎯 receiverId:",
            message.receiverId ?? "nil"
        )
        print(
            "💬 text:",
            message.text
        )
        print(
            "📬 deliveredAt:",
            message.deliveredAt
                .map {
                    String(
                        describing: $0
                    )
                }
                ?? "nil"
        )
        print(
            "👀 readAt:",
            message.readAt
                .map {
                    String(
                        describing: $0
                    )
                }
                ?? "nil"
        )
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        if message.text == "__GRU_CHAT_DELETED__" {
            if let chat = service.chats.first(where: { $0.serverID == message.chatId }) {
                service.deleteChat(chat.id)
                syncRealtimeSubscriptions()
            }
            return
        }

        /*
         Если это сообщение пришло НАМ
         и сервер ещё не считает его
         доставленным — отмечаем delivered.
         */

        markDeliveredIfNeeded(
            message
        )
    }

    // MARK: - Mark Delivered

    private func markDeliveredIfNeeded(
        _ message: ServerMessageDTO
    ) {

        guard let currentUserID =
                service.currentUser.serverID
        else {

            return
        }

        /*
         Не отмечаем delivered
         для собственных исходящих.
         */

        guard
            message.receiverId ==
                currentUserID
        else {

            return
        }

        /*
         Уже прочитанное сообщение
         автоматически является
         и доставленным.
         */

        guard
            message.readAt == nil
        else {

            return
        }

        /*
         Если deliveredAt уже есть,
         второй POST не нужен.

         Это также предотвращает цикл:
         POST delivered
         → WebSocket broadcast
         → POST delivered
         → ...
         */

        guard
            message.deliveredAt == nil
        else {

            return
        }

        guard let token =
                TokenStorage.shared.token
        else {

            return
        }

        Task {

            do {

                let updatedMessage =
                    try await MessageAPIService.shared
                        .markDelivered(
                            messageID:
                                message.id,
                            token:
                                token
                        )

                print("")
                print(
                    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                )
                print(
                    "📬 MESSAGE DELIVERED"
                )
                print(
                    "🆔",
                    updatedMessage.id
                )
                print(
                    "💬",
                    updatedMessage.text
                )
                print(
                    "📬 deliveredAt:",
                    updatedMessage
                        .deliveredAt
                        .map {
                            String(
                                describing: $0
                            )
                        }
                        ?? "nil"
                )
                print(
                    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                )

            } catch {

                print("")
                print(
                    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                )
                print(
                    "❌ Mark delivered error"
                )
                print(
                    error.localizedDescription
                )
                print(
                    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                )
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {

        if service.isLoadingChats &&
            service.chats.isEmpty {

            loadingView

        } else if
            let error =
                service.chatLoadingError,
            service.chats.isEmpty {

            errorView(
                message: error
            )

        } else if
            service.chats.isEmpty {

            emptyView

        } else {

            VStack(spacing: 10) {
                gruPulse
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                if !network.isConnected || service.chatLoadingError != nil || service.isUsingCachedChats {
                    connectionBanner
                        .padding(.horizontal, 14)
                }

                chatList
            }
        }
    }

    // MARK: - Connection Banner

    private var connectionBanner: some View {

        let isOffline = !network.isConnected

        HStack(
            spacing: 11
        ) {

            GRUNeonIcon(
                systemName: isOffline ? "wifi.slash" : "wifi.exclamationmark",
                size: 34,
                iconSize: 13,
                isActive: false
            )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text(
                    isOffline
                        ? "Ожидание сети..."
                        : (service.isUsingCachedChats
                            ? "Показан сохранённый список"
                            : "Backend временно недоступен")
                )
                .font(
                    .caption.weight(.semibold)
                )

                Text(
                    isOffline
                        ? "Поиск подключения к интернету"
                        : connectionSubtitle
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(1)
            }

            Spacer()

            Button {

                Task {
                    await service.loadChats()
                    syncRealtimeSubscriptions()
                    connectWebSocket()
                }

            } label: {

                Image(
                    systemName: "arrow.clockwise"
                )
                .font(
                    .system(
                        size: 13,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    GRUColors.accent
                )
                .frame(
                    width: 34,
                    height: 34
                )
                .background(
                    GRUColors.accent.opacity(0.10)
                )
                .clipShape(
                    Circle()
                )
                .overlay {
                    Circle()
                        .stroke(
                            GRUColors.accent.opacity(0.32),
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(
                .plain
            )
            .accessibilityLabel(
                "Повторить подключение"
            )
        }
        .padding(
            .horizontal,
            14
        )
        .padding(
            .vertical,
            10
        )
        .background(
            GRUColors.card.opacity(0.94)
        )
        .overlay(
            alignment: .bottom
        ) {
            Rectangle()
                .fill(
                    GRUColors.accent.opacity(0.16)
                )
                .frame(
                    height: 1
                )
        }
    }

    private var connectionSubtitle: String {

        if let date = service.lastChatsSyncAt {
            return "Синхронизация: \(date.formatted(date: .omitted, time: .shortened)) • \(GRUServerConfiguration.host)"
        }

        if let socketError = socket.lastError,
           !socketError.isEmpty {
            return socketError
        }

        return GRUServerConfiguration.httpBaseURL
    }

    // MARK: - V11 GRU Pulse

    private var gruPulse: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(GRUColors.accent.opacity(0.13))
                        .frame(width: 44, height: 44)

                    Image(systemName: socket.isConnected ? "bolt.horizontal.circle.fill" : "bolt.slash.circle.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(socket.isConnected ? GRUColors.accent : .secondary)
                }
                .overlay {
                    Circle().stroke(
                        socket.isConnected ? GRUColors.accent.opacity(0.30) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
                }
                .shadow(color: socket.isConnected ? GRUColors.accent.opacity(0.24) : .clear, radius: 12)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("GRU PULSE")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .tracking(0.9)

                        Text("V12 RELEASE")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.78))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(GRUColors.accent, in: Capsule())
                    }

                    Text(socket.isConnected ? "Realtime подключён • \(GRUServerConfiguration.host)" : "Realtime переподключается • \(GRUServerConfiguration.host)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                pulseMetric(value: unreadTotal, label: "новых")
                pulseMetric(value: onlineTotal, label: "online")
            }

            HStack(spacing: 8) {
                Label(currentTheme.title, systemImage: currentTheme.icon)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(GRUColors.accent)
                    .lineLimit(1)

                Spacer()

                Text(currentTheme.subtitle)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Поиск чатов", text: $searchText)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

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
            .padding(.horizontal, 13)
            .frame(height: 40)
            .background(Color.white.opacity(0.045), in: Capsule())
            .overlay { Capsule().stroke(Color.white.opacity(0.065), lineWidth: 1) }

            HStack(spacing: 7) {
                ForEach(GRUChatFilter.allCases) { filter in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
                            chatFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(chatFilter == filter ? Color.black.opacity(0.78) : .secondary)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(
                                chatFilter == filter ? GRUColors.accent : Color.white.opacity(0.045),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    showingNewChat = true
                } label: {
                    Label("Новый", systemImage: "plus")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(GRUColors.accent)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(GRUColors.accent.opacity(0.09), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(GRUColors.card.opacity(0.84))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(GRUColors.neonGradient, lineWidth: 1)
                .opacity(0.46)
        }
        .shadow(color: GRUColors.accent.opacity(0.10), radius: 18, y: 8)
    }

    private var currentTheme: GRUAppTheme {
        GRUAppTheme(rawValue: themeRaw) ?? .obsidian
    }

    private func pulseMetric(value: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(value > 0 ? GRUColors.accent : .secondary)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 34)
    }

    private var unreadTotal: Int {
        service.chats.reduce(0) { $0 + $1.unreadCount }
    }

    private var onlineTotal: Int {
        let currentID = service.currentUser.id
        return service.chats.filter { chat in
            chat.users.contains { $0.id != currentID && $0.isOnline }
        }.count
    }

    private var filteredChats: [Chat] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentID = service.currentUser.id

        return service.chats.filter { chat in
            let passesFilter: Bool
            switch chatFilter {
            case .all:
                passesFilter = true
            case .unread:
                passesFilter = chat.unreadCount > 0
            case .online:
                passesFilter = chat.users.contains { $0.id != currentID && $0.isOnline }
            }

            guard passesFilter else { return false }
            guard !query.isEmpty else { return true }

            let userMatch = chat.users.contains {
                $0.displayName.localizedCaseInsensitiveContains(query) ||
                $0.username.localizedCaseInsensitiveContains(query)
            }
            let titleMatch = chat.title?.localizedCaseInsensitiveContains(query) == true
            let messageMatch = chat.messages.last?.text.localizedCaseInsensitiveContains(query) == true
            return userMatch || titleMatch || messageMatch
        }
    }

    // MARK: - Chat List

    private var chatList: some View {
        Group {
            if filteredChats.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: chatFilter == .unread ? "checkmark.circle.fill" : "magnifyingglass")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(GRUColors.accent)
                    Text(chatFilter == .unread ? "Всё прочитано" : "Ничего не найдено")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Смени фильтр или запрос")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredChats) { chat in
                        NavigationLink {
                            ChatView(chat: chat)
                                .onAppear { onChatPresentationChanged(true) }
                                .onDisappear { onChatPresentationChanged(false) }
                        } label: {
                            ChatRow(chat: chat)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14))
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                var updated = chat
                                updated.isPinned.toggle()
                                service.update(updated)
                            } label: {
                                Label(chat.isPinned ? "Открепить" : "Закрепить", systemImage: chat.isPinned ? "pin.slash" : "pin")
                            }

                            Button {
                                var updated = chat
                                updated.isMuted.toggle()
                                service.update(updated)
                            } label: {
                                Label(chat.isMuted ? "Включить звук" : "Без звука", systemImage: chat.isMuted ? "speaker.wave.2" : "speaker.slash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteChat = chat
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                            .disabled(deletingChatServerID == chat.serverID)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .refreshable {
                    await service.loadChats()
                    syncRealtimeSubscriptions()
                    connectWebSocket()
                }
            }
        }
    }

    // MARK: - Empty

    private var emptyView: some View {

        VStack(
            spacing: 18
        ) {

            Spacer()

            GRUEnvelope()
                .stroke(
                    GRUColors.accent,
                    style:
                        StrokeStyle(
                            lineWidth: 1.6,
                            lineCap: .round,
                            lineJoin: .round
                        )
                )
                .frame(
                    width: 38,
                    height: 27
                )
                .opacity(
                    0.8
                )

            VStack(
                spacing: 6
            ) {

                Text(
                    "Пока тихо"
                )
                .font(
                    .system(
                        size: 21,
                        weight: .semibold,
                        design: .rounded
                    )
                )

                Text(
                    "Начни первую переписку"
                )
                .font(
                    .system(
                        size: 14,
                        weight: .regular,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Button {

                showingNewChat = true

            } label: {

                HStack(
                    spacing: 8
                ) {

                    GRUNeonIcon(
                        systemName: "envelope.fill",
                        size: 30,
                        iconSize: 12
                    )

                    Text(
                        "Новый чат"
                    )
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                }
                .foregroundStyle(
                    GRUColors.accent
                )
                .padding(
                    .horizontal,
                    18
                )
                .frame(
                    height: 44
                )
                .background(
                    GRUColors.card
                )
                .clipShape(
                    Capsule()
                )
            }
            .buttonStyle(
                .plain
            )

            Spacer()
        }
        .padding(
            .horizontal,
            24
        )
    }

    // MARK: - Loading

    private var loadingView: some View {

        VStack(
            spacing: 12
        ) {

            ProgressView()

            Text(
                "Загрузка…"
            )
            .font(
                .system(
                    size: 14,
                    design: .rounded
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    // MARK: - Error

    private func errorView(
        message: String
    ) -> some View {

        VStack(
            spacing: 14
        ) {

            Spacer()

            Image(
                systemName:
                    "wifi.exclamationmark"
            )
            .font(
                .system(
                    size: 29,
                    weight: .light
                )
            )

            Text(
                "Не удалось загрузить чаты"
            )
            .font(
                .system(
                    size: 18,
                    weight: .semibold,
                    design: .rounded
                )
            )

            Text(
                message
            )
            .font(
                .system(
                    size: 13,
                    design: .rounded
                )
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )

            Button(
                "Повторить"
            ) {

                Task {

                    await service.loadChats()

                    syncRealtimeSubscriptions()

                    connectWebSocket()
                }
            }
            .buttonStyle(
                .bordered
            )

            Spacer()
        }
        .padding(
            .horizontal,
            30
        )
    }
}

// MARK: - Preview

#Preview {

    ChatListView()
}
