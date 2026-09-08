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
                            .background(
                                GRUColors.accent.opacity(0.09),
                                in: Circle()
                            )
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
                        accessibilityLabel: GRUL10n.text("Новый чат"),
                        size: 36,
                        iconSize: 14
                    ) {
                        showingNewChat = true
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(
            isPresented: $showingNewChat,
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
        .task {
            await loadData()
        }
        .onAppear {
            syncRealtimeSubscriptions()
            connectWebSocket()
        }
        .confirmationDialog(
            GRUL10n.text("Удалить чат целиком?"),
            isPresented: Binding(
                get: { pendingDeleteChat != nil },
                set: {
                    if !$0 {
                        pendingDeleteChat = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(
                GRUL10n.text("Удалить чат у обоих"),
                role: .destructive
            ) {
                if let chat = pendingDeleteChat {
                    deleteChatEverywhere(chat)
                }
            }

            Button(GRUL10n.text("Отмена"), role: .cancel) {
                pendingDeleteChat = nil
            }
        } message: {
            Text(
                GRUL10n.text(
                    "История и вложения будут удалены с сервера."
                )
            )
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
                            .onAppear {
                                onChatPresentationChanged(true)
                            }
                            .onDisappear {
                                onChatPresentationChanged(false)
                            }
                    } label: {
                        testChatRow
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(
                        EdgeInsets(
                            top: 4,
                            leading: 10,
                            bottom: 4,
                            trailing: 10
                        )
                    )
                }

                if service.isLoadingChats && service.chats.isEmpty {
                    HStack(spacing: 9) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(GRUColors.accent)

                        Text(
                            GRUL10n.text(
                                "Синхронизирую реальные чаты…"
                            )
                        )
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
                            .opacity(
                                deletingChatServerID == chat.serverID
                                    ? 0.42
                                    : 1
                            )
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(
                        EdgeInsets(
                            top: 4,
                            leading: 10,
                            bottom: 4,
                            trailing: 10
                        )
                    )
                    .swipeActions(
                        edge: .trailing,
                        allowsFullSwipe: false
                    ) {
                        Button(role: .destructive) {
                            pendingDeleteChat = chat
                        } label: {
                            Label(
                                GRUL10n.text("Удалить"),
                                systemImage: "trash"
                            )
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
                        .font(
                            .system(
                                size: 15,
                                weight: .bold,
                                design: .rounded
                            )
                        )

                    Text("RC")
                        .font(
                            .system(
                                size: 8,
                                weight: .black,
                                design: .rounded
                            )
                        )
                        .tracking(0.8)
                        .foregroundStyle(GRUColors.accent)
                        .padding(.horizontal, 6)
                        .frame(height: 17)
                        .background(
                            GRUColors.accent.opacity(0.10),
                            in: Capsule()
                        )
                }

                Text(
                    GRUL10n.text(
                        "Полный локальный чат: voice • кото-кружки • actions"
                    )
                )
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

            TextField(
                GRUL10n.text("Поиск"),
                text: $searchText
            )
            .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(GRUL10n.text("Очистить поиск"))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            GRUColors.card.opacity(0.78),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        }
    }

    private var compactConnectionNotice: some View {
        HStack(spacing: 7) {
            Image(
                systemName: socket.isConnected
                    ? "checkmark.circle.fill"
                    : "wifi.slash"
            )
            .font(.system(size: 11, weight: .bold))

            Text(
                GRUL10n.text(
                    service.isUsingCachedChats
                        ? "offline • показываю сохранённые чаты"
                        : "backend недоступен • test lab полностью работает локально"
                )
            )
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .lineLimit(1)

            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            GRUColors.card.opacity(0.52),
            in: Capsule()
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(GRUColors.accent)

            Text(GRUL10n.text("Ничего не найдено"))
                .font(.headline)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var showsTestChat: Bool {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return true
        }

        return "gru. test lab тестовый чат rc local voice кото кружок"
            .localizedCaseInsensitiveContains(query)
    }

    private var filteredChats: [Chat] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return service.chats
        }

        return service.chats.filter { chat in
            let usersMatch = chat.users.contains {
                $0.displayName.localizedCaseInsensitiveContains(query) ||
                $0.username.localizedCaseInsensitiveContains(query)
            }

            let titleMatch =
                chat.title?.localizedCaseInsensitiveContains(query) == true

            let messageMatch =
                chat.messages.last?.text
                    .localizedCaseInsensitiveContains(query) == true

            return usersMatch || titleMatch || messageMatch
        }
    }

    private func loadData() async {
        await service.loadChats()
        syncRealtimeSubscriptions()
        connectWebSocket()
    }

    private func connectWebSocket() {
        guard let token = TokenStorage.shared.token,
              !token.isEmpty else {
            return
        }

        WebSocketService.shared.connect(token: token)
    }

    private func syncRealtimeSubscriptions() {
        let serverChatIDs = Set(service.chats.compactMap(\.serverID))

        for chatID in Array(realtimeListeners.keys) {
            guard !serverChatIDs.contains(chatID),
                  let listenerID = realtimeListeners[chatID] else {
                continue
            }

            WebSocketService.shared.removeListener(
                chatID: chatID,
                listenerID: listenerID
            )
            realtimeListeners[chatID] = nil
        }

        for chat in service.chats {
            guard let chatID = chat.serverID,
                  realtimeListeners[chatID] == nil else {
                continue
            }

            let listenerID = WebSocketService.shared.addListener(
                chatID: chatID
            ) { message in
                handleRealtimeMessage(message)
            }

            realtimeListeners[chatID] = listenerID
        }
    }

    private func handleRealtimeMessage(_ message: ServerMessageDTO) {
        if message.text == "__GRU_CHAT_DELETED__" {
            if let chat = service.chats.first(
                where: { $0.serverID == message.chatId }
            ) {
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
                print(
                    "❌ Mark delivered error:",
                    error.localizedDescription
                )
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
            defer {
                deletingChatServerID = nil
            }

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
