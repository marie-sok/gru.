
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

    // MARK: - Search and filters

    @State private var searchText = ""
    @State private var chatFilter: GRUChatFilter = .all
    @State private var pendingDeleteChat: Chat?
    @State private var deletingChatServerID: String?

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

        if service.isLoadingChats && service.chats.isEmpty {
            loadingView
        } else {
            VStack(spacing: 10) {
                chatControls
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                GRUBotCard()
                    .padding(.horizontal, 14)

                if !network.isConnected || service.chatLoadingError != nil || service.isUsingCachedChats {
                    connectionBanner
                        .padding(.horizontal, 14)
                }

                if let error = service.chatLoadingError, service.chats.isEmpty {
                    errorView(message: error)
                } else if service.chats.isEmpty {
                    emptyView
                } else {
                    chatList
                }
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
                        : service.isUsingCachedChats
                        ? "Показан сохранённый список"
                        : "Backend временно недоступен"
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

    // MARK: - Chat controls

    private var chatControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                GRUNeonIcon(
                    systemName: socket.isConnected ? "bolt.horizontal.fill" : "bolt.slash.fill",
                    size: 44,
                    iconSize: 18,
                    isActive: socket.isConnected
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("GRU CHATS")
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

                metric(value: unreadTotal, label: "новых")
                metric(value: onlineTotal, label: "online")
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

    private func metric(value: Int, label: String) -> some View {
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

// MARK: - GRU Bot

/// A deterministic built-in assistant for the beta. It is deliberately a
/// local agent until the production backend exposes an AI endpoint.
enum GRUBotIdentity {
    static let user = User(
        id: UUID(uuidString: "B0B0B0B0-0000-4000-8000-000000000001") ?? UUID(),
        username: "gru.bot",
        displayName: "GRU Bot",
        isOnline: true,
        isBot: true
    )
}

struct GRUBotCard: View {
    var body: some View {
        NavigationLink {
            GRUBotView()
        } label: {
            HStack(spacing: 12) {
                AvatarView(user: GRUBotIdentity.user, size: 48)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text("GRU Bot")
                            .font(.system(size: 16, weight: .black, design: .rounded))

                        Text("AI")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.82))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(GRUColors.accent, in: Capsule())
                    }

                    Text("AI agent внутри GRU")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GRUColors.accent)
            }
            .padding(13)
            .background(GRUColors.card.opacity(0.90), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(GRUColors.neonGradient, lineWidth: 1.1)
                    .opacity(0.65)
            }
            .shadow(color: GRUColors.accent.opacity(0.16), radius: 16, y: 7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Открыть GRU Bot")
    }
}

@MainActor
struct GRUBotView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [GRUBotMessage] = [
        GRUBotMessage(
            role: .bot,
            text: "Привет. Я GRU Bot — встроенный AI agent. Помогу найти функцию, выбрать тему и разобраться с перепиской."
        )
    ]
    @State private var input = ""
    @State private var isThinking = false
    @FocusState private var inputFocused: Bool

    private let quickPrompts = ["Что умеет GRU?", "Как выбрать тему?", "Где мои контакты?"]

    var body: some View {
        ZStack {
            GRUAppBackdrop()

            VStack(spacing: 0) {
                botHeader

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                messageRow(message).id(message.id)
                            }

                            if isThinking {
                                thinkingRow.id("thinking")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .onChange(of: messages.count) { _, _ in scrollToLast(proxy) }
                    .onChange(of: isThinking) { _, _ in scrollToLast(proxy) }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .navigationBarBackButtonHidden(true)
    }

    private var botHeader: some View {
        HStack(spacing: 11) {
            Button { dismiss() } label: {
                GRUNeonIcon(systemName: "chevron.left", size: 38, iconSize: 14)
            }
            .buttonStyle(.plain)

            AvatarView(user: GRUBotIdentity.user, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("GRU Bot").font(.headline)
                Text("AI agent • beta")
                    .font(.caption)
                    .foregroundStyle(GRUColors.accent)
            }

            Spacer()
            GRUNeonIcon(systemName: "sparkles", size: 36, iconSize: 14)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if messages.count == 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickPrompts, id: \.self) { prompt in
                            Button(prompt) { send(prompt) }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(GRUColors.accent)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(GRUColors.accent.opacity(0.10), in: Capsule())
                                .overlay { Capsule().stroke(GRUColors.accent.opacity(0.20), lineWidth: 1) }
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }

            HStack(spacing: 9) {
                TextField("Спросить GRU Bot", text: $input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { send(input) }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(GRUColors.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 19, style: .continuous))

                Button { send(input) } label: {
                    GRUNeonIcon(systemName: "arrow.up", size: 42, iconSize: 17, isActive: canSend)
                }
                .buttonStyle(.plain)
                .disabled(!canSend || isThinking)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial)
        }
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func messageRow(_ message: GRUBotMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .bot {
                AvatarView(user: GRUBotIdentity.user, size: 28)
            } else {
                Spacer(minLength: 32)
            }

            Text(message.text)
                .font(.body)
                .foregroundStyle(message.role == .bot ? GRUColors.text : Color.black.opacity(0.86))
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(message.role == .bot ? GRUColors.card.opacity(0.94) : GRUColors.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    if message.role == .bot {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(GRUColors.accent.opacity(0.16), lineWidth: 1)
                    }
                }

            if message.role == .user {
                Spacer(minLength: 32)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .bot ? .leading : .trailing)
    }

    private var thinkingRow: some View {
        HStack(spacing: 8) {
            AvatarView(user: GRUBotIdentity.user, size: 28)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(GRUColors.accent).frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(GRUColors.card.opacity(0.94), in: Capsule())
            Spacer()
        }
    }

    private func send(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }

        messages.append(GRUBotMessage(role: .user, text: text))
        input = ""
        inputFocused = false
        isThinking = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            messages.append(GRUBotMessage(role: .bot, text: GRUBotAgent.answer(for: text)))
            isThinking = false
        }
    }

    private func scrollToLast(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.20)) {
            if isThinking {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let id = messages.last?.id {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }
}

private enum GRUBotMessageRole { case bot, user }

private struct GRUBotMessage: Identifiable {
    let id = UUID()
    let role: GRUBotMessageRole
    let text: String
}

private enum GRUBotAgent {
    static func answer(for text: String) -> String {
        let query = text.lowercased()

        if query.contains("тема") || query.contains("оформ") || query.contains("фон") {
            return "Открой Настройки → Оформление. Там оставлены только фирменные темы GRU с детальными рисунками; тема меняется сразу."
        }
        if query.contains("контакт") || query.contains("люд") {
            return "Вкладка «Люди» показывает пользователей GRU и телефонную книгу. Доступ к контактам iPhone запрашивается только при открытии раздела."
        }
        if query.contains("видео") || query.contains("круж") || query.contains("голос") {
            return "Видео выбирается из медиатеки или камеры. Лапка в поле ввода: двойной тап переключает голос/кружок, удержание записывает."
        }
        if query.contains("звон") {
            return "В beta GRU нет аудио- и видеозвонков — только голосовые, видео и видео-кружки внутри чата."
        }
        if query.contains("удал") {
            return "Зажми сообщение или выбери несколько: доступно удаление только у себя, а для своих сообщений — у себя и собеседника."
        }
        if query.contains("помощ") || query.contains("умеет") || query.contains("help") {
            return "Я подсказываю по чатам, темам, профилю, контактам, медиа и настройкам. Напиши вопрос обычными словами."
        }
        return "Принял. Я beta-агент GRU: могу подсказать путь в приложении или объяснить, как работает нужная функция."
    }
}

#Preview {
    ChatListView()
}
