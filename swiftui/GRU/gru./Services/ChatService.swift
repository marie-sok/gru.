import Foundation
import Observation

@MainActor
@Observable
final class ChatService {

    static let shared = ChatService()

    // MARK: - Current User

    var currentUser: User

    // MARK: - Chats

    var chats: [Chat] = []

    // MARK: - Loading State

    var isLoadingChats = false

    var chatLoadingError: String?

    var isUsingCachedChats = false

    var lastChatsSyncAt: Date?

    // MARK: - Presence

    var onlineUserIDs: Set<String> = []

    // MARK: - Unread

    var totalUnreadCount = 0

    // MARK: - Active Chat

    private(set)
    var activeChatServerID: String?

    // MARK: - Init

    private init() {

        currentUser = User(
            serverID:
                TokenStorage.shared.userID,
            username:
                "marie.sok",
            displayName:
                "Me",
            isOnline:
                false,
            avatarData:
                ProfileStorage.shared.avatarData
        )
    }

    // MARK: ========================================
    // MARK: LOAD CHATS
    // MARK: ========================================

    func loadChats() async {

        guard let token =
                TokenStorage.shared.token,
              !token.isEmpty
        else {

            resetChatStateForMissingSession(
                message:
                    "Сессия не найдена"
            )

            return
        }

        guard let serverUserID =
                TokenStorage.shared.userID,
              !serverUserID.isEmpty
        else {

            resetChatStateForMissingSession(
                message:
                    "Не найден ID пользователя"
            )

            return
        }

        currentUser.serverID =
            serverUserID

        if chats.isEmpty {

            let cachedChats =
                CacheStorage.shared.loadChats(
                    userID: serverUserID
                )

            if !cachedChats.isEmpty {
                chats = cachedChats
                isUsingCachedChats = true
                lastChatsSyncAt =
                    CacheStorage.shared.lastSyncDate(
                        userID: serverUserID
                    )

                updateCurrentUserInChats()
                recalculateTotalUnread()
            }
        }

        isLoadingChats =
            true

        chatLoadingError =
            nil

        defer {

            isLoadingChats =
                false
        }

        do {

            let serverChats =
                try await
                    ChatAPIService
                        .shared
                        .getChats(
                            token:
                                token
                        )

            chats =
                serverChats
                    .map {

                        makeLocalChat(
                            from:
                                $0
                        )
                    }
                    .sorted {

                        $0.lastActivity >
                            $1.lastActivity
                    }

            isUsingCachedChats = false

            CacheStorage.shared.saveChats(
                chats,
                userID: serverUserID
            )

            lastChatsSyncAt =
                CacheStorage.shared.lastSyncDate(
                    userID: serverUserID
                )

            print(
                "✅ GET /chats success"
            )

            print(
                "✅ Chats loaded:",
                chats.count
            )

            // Presence и unread накладываем
            // уже после загрузки серверных чатов.

            await loadPresence()

            await loadUnreadCounts()

        } catch {

            print(
                "❌ GET /chats failed:",
                error
            )

            chatLoadingError =
                error.localizedDescription

            isUsingCachedChats =
                !chats.isEmpty
        }
    }

    // MARK: ========================================
    // MARK: PRESENCE SNAPSHOT
    // MARK: ========================================

    func loadPresence() async {

        guard let token =
                TokenStorage.shared.token,
              !token.isEmpty
        else {

            return
        }

        do {

            let ids =
                try await
                    PresenceAPIService
                        .shared
                        .getOnlineUserIDs(
                            token:
                                token
                        )

            onlineUserIDs =
                Set(
                    ids
                )

            refreshPresenceInChats()

            print("")

            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            print(
                "🟢 PRESENCE SNAPSHOT"
            )

            print(
                "👥 online users:",
                onlineUserIDs.count
            )

            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            print(
                "✅ GET /presence success"
            )

        } catch {

            print("")

            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            print(
                "❌ Presence snapshot error"
            )

            print(
                error.localizedDescription
            )

            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )
        }
    }

    // MARK: ========================================
    // MARK: REALTIME PRESENCE
    // MARK: ========================================

    func applyPresenceEvent(
        _ event:
            PresenceEventDTO
    ) {

        if event.online {

            onlineUserIDs.insert(
                event.userId
            )

        } else {

            onlineUserIDs.remove(
                event.userId
            )
        }

        setUserOnline(
            serverID:
                event.userId,
            online:
                event.online
        )

        print("")

        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        print(
            event.online
            ? "🟢 PRESENCE ONLINE"
            : "⚫️ PRESENCE OFFLINE"
        )

        print(
            "👤",
            event.userId
        )

        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
    }

    // MARK: - Set User Online

    private func setUserOnline(
        serverID:
            String,
        online:
            Bool
    ) {

        if currentUser.serverID ==
            serverID {

            currentUser.isOnline =
                online
        }

        for chatIndex
        in chats.indices {

            for userIndex
            in chats[
                chatIndex
            ]
            .users
            .indices {

                guard
                    chats[
                        chatIndex
                    ]
                    .users[
                        userIndex
                    ]
                    .serverID ==
                        serverID
                else {

                    continue
                }

                if serverID ==
                    currentUser.serverID {

                    chats[
                        chatIndex
                    ]
                    .users[
                        userIndex
                    ] =
                        currentUser

                } else {

                    chats[
                        chatIndex
                    ]
                    .users[
                        userIndex
                    ]
                    .isOnline =
                        online
                }
            }
        }
    }

    // MARK: - Refresh Presence

    private func refreshPresenceInChats() {

        if let currentServerID =
            currentUser.serverID {

            currentUser.isOnline =
                onlineUserIDs
                    .contains(
                        currentServerID
                    )

        } else {

            currentUser.isOnline =
                false
        }

        for chatIndex
        in chats.indices {

            for userIndex
            in chats[
                chatIndex
            ]
            .users
            .indices {

                guard let serverID =
                        chats[
                            chatIndex
                        ]
                        .users[
                            userIndex
                        ]
                        .serverID
                else {

                    continue
                }

                if serverID ==
                    currentUser.serverID {

                    chats[
                        chatIndex
                    ]
                    .users[
                        userIndex
                    ] =
                        currentUser

                } else {

                    chats[
                        chatIndex
                    ]
                    .users[
                        userIndex
                    ]
                    .isOnline =
                        onlineUserIDs
                            .contains(
                                serverID
                            )
                }
            }
        }
    }

    // MARK: ========================================
    // MARK: UNREAD SNAPSHOT
    // MARK: ========================================

    func loadUnreadCounts() async {

        guard let token =
                TokenStorage.shared.token,
              !token.isEmpty
        else {

            return
        }

        do {

            let snapshot =
                try await
                    UnreadAPIService
                        .shared
                        .getUnreadCounts(
                            token:
                                token
                        )

            for chatIndex
            in chats.indices {

                guard let serverID =
                        chats[
                            chatIndex
                        ]
                        .serverID
                else {

                    chats[
                        chatIndex
                    ]
                    .unreadCount =
                        0

                    continue
                }

                let serverCount =
                    max(
                        0,
                        snapshot
                            .chats[
                                serverID
                            ]
                        ?? 0
                    )

                /*
                 Открытый чат локально
                 не должен показывать badge,
                 даже если snapshot успел
                 прийти раньше markRead.
                 */

                if activeChatServerID ==
                    serverID {

                    chats[
                        chatIndex
                    ]
                    .unreadCount =
                        0

                } else {

                    chats[
                        chatIndex
                    ]
                    .unreadCount =
                        serverCount
                }
            }

            recalculateTotalUnread()

            print("")

            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            print(
                "✅ UNREAD SNAPSHOT"
            )

            print(
                "💬 chats:",
                snapshot.chats.count
            )

            print(
                "🔴 total:",
                totalUnreadCount
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
                "❌ Unread snapshot error"
            )

            print(
                error.localizedDescription
            )

            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )
        }
    }

    // MARK: - Unread Count

    func unreadCount(
        forServerID serverID:
            String
    ) -> Int {

        guard let index =
                chatIndex(
                    forServerID:
                        serverID
                )
        else {

            return 0
        }

        return chats[
            index
        ]
        .unreadCount
    }

    // MARK: - Clear Unread

    func clearUnread(
        forServerID serverID:
            String
    ) {

        guard let index =
                chatIndex(
                    forServerID:
                        serverID
                )
        else {

            return
        }

        let unread =
            chats[
                index
            ]
            .unreadCount

        guard unread > 0
        else {

            return
        }

        chats[
            index
        ]
        .unreadCount =
            0

        totalUnreadCount =
            max(
                0,
                totalUnreadCount -
                    unread
            )

        print("")

        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        print(
            "✅ UNREAD CLEARED"
        )

        print(
            "💬 chat:",
            serverID
        )

        print(
            "🔴 removed:",
            unread
        )

        print(
            "🔢 total:",
            totalUnreadCount
        )

        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
    }

    // MARK: - Recalculate Total Unread

    private func recalculateTotalUnread() {

        totalUnreadCount =
            chats.reduce(
                0
            ) {
                partialResult,
                chat in

                partialResult +
                    max(
                        0,
                        chat.unreadCount
                    )
            }
    }

    // MARK: ========================================
    // MARK: ACTIVE CHAT
    // MARK: ========================================

    /*
     String? оставляем специально.

     Поэтому работают оба варианта:

     setActiveChat(serverID: chatID)
     setActiveChat(serverID: nil)
     */

    func setActiveChat(
        serverID:
            String?
    ) {

        guard let serverID,
              !serverID.isEmpty
        else {

            activeChatServerID =
                nil

            return
        }

        activeChatServerID =
            serverID

        clearUnread(
            forServerID:
                serverID
        )

        print("")

        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        print(
            "👁 ACTIVE CHAT"
        )

        print(
            "💬",
            serverID
        )

        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
    }

    // MARK: - Clear Active Chat

    func clearActiveChat(
        serverID:
            String
    ) {

        /*
         Защита от race:
         disappearing старого ChatView
         не должен закрыть уже открытый
         новый чат.
         */

        guard activeChatServerID ==
                serverID
        else {

            return
        }

        activeChatServerID =
            nil

        print("")

        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        print(
            "👁 ACTIVE CHAT CLEARED"
        )

        print(
            "💬",
            serverID
        )

        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
    }

    // MARK: ========================================
    // MARK: REALTIME MESSAGE
    // MARK: ========================================

    func applyRealtimeMessage(
        _ serverMessage:
            ServerMessageDTO
    ) {

        guard let chatIndex =
                chatIndex(
                    forServerID:
                        serverMessage
                            .chatId
                )
        else {

            /*
             Если чат появился на другом
             устройстве и его ещё нет
             в локальном списке —
             обновляем список с сервера.
             */

            Task {

                await loadChats()
            }

            return
        }

        let currentServerID =
            currentUser.serverID

        let isIncoming =
            serverMessage
                .senderId !=
                    currentServerID

        let isForCurrentUser =
            serverMessage
                .receiverId ==
                    currentServerID

        let isChatOpen =
            activeChatServerID ==
                serverMessage.chatId

        if serverMessage.deletedAt != nil {
            chats[chatIndex].messages.removeAll { $0.serverID == serverMessage.id }
            chats[chatIndex].updatedAt = Date()
            sortChats()
            return
        }

        if let reply =
            serverMessage.replyTo {

            print("")

            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            print(
                "↩️ REALTIME REPLY"
            )

            print(
                "🆔 reply messageId:",
                reply.messageId
            )

            print(
                "💬 reply text:",
                reply.text
            )

            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )
        }

        // MARK: Existing Server Message

        /*
         Backend повторно рассылает
         один и тот же Message после:

         send
         delivered
         read

         Поэтому сначала ищем
         по serverID.
         */

        if let messageIndex =
            chats[
                chatIndex
            ]
            .messages
            .firstIndex(
                where: {

                    $0.serverID ==
                        serverMessage.id
                }
            ) {

            updateServerConfirmedMessage(
                chatIndex:
                    chatIndex,
                messageIndex:
                    messageIndex,
                serverMessage:
                    serverMessage
            )

            sortChats()

            return
        }

        // MARK: Reconcile Optimistic Outgoing

        /*
         Иногда HTTP POST уже создал
         локальное optimistic сообщение,
         а STOMP приходит почти одновременно.

         Не создаём второй bubble.
         */

        if let optimisticIndex =
            optimisticMessageIndex(
                in:
                    chats[
                        chatIndex
                    ],
                for:
                    serverMessage
            ) {

            updateServerConfirmedMessage(
                chatIndex:
                    chatIndex,
                messageIndex:
                    optimisticIndex,
                serverMessage:
                    serverMessage
            )

            sortChats()

            return
        }

        // MARK: New Local Message

        let resolvedReply =
            realtimeReplyMessage(
                in:
                    chats[
                        chatIndex
                    ],
                from:
                    serverMessage.replyTo
            )

        let localMessage =
            Message(
                serverID:
                    serverMessage.id,
                senderID:
                    localSenderID(
                        in:
                            chats[
                                chatIndex
                            ],
                        serverID:
                            serverMessage
                                .senderId
                    ),
                text:
                    serverMessage.text,
                sentAt:
                    serverMessage
                        .createdAt,
                status:
                    serverMessage.messageStatus,
                deliveredAt:
                    serverMessage.deliveredAt,
                readAt:
                    serverMessage.readAt,
                reaction:
                    serverMessage.reaction,
                replyTo:
                    resolvedReply,
                attachment:
                    serverMessage.attachment
            )

        chats[
            chatIndex
        ]
        .messages
        .append(
            localMessage
        )

        chats[
            chatIndex
        ]
        .updatedAt =
            serverMessage
                .createdAt

        // MARK: Realtime Unread +1

        /*
         Считаем только ПЕРВЫЙ
         серверный frame сообщения.

         После markDelivered backend
         отправит тот же message снова,
         но уже с deliveredAt != nil.

         После markRead —
         readAt != nil.

         Они не должны давать +1.
         */

        if isIncoming,
           isForCurrentUser,
           !isChatOpen,
           serverMessage.deletedAt == nil,
           serverMessage.deliveredAt == nil,
           serverMessage.readAt == nil {

            chats[
                chatIndex
            ]
            .unreadCount +=
                1

            totalUnreadCount +=
                1

            print("")

            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            print(
                "🔴 REALTIME UNREAD +1"
            )

            print(
                "💬 chat:",
                serverMessage.chatId
            )

            print(
                "🆔 message:",
                serverMessage.id
            )

            print(
                "🔢 chat unread:",
                chats[
                    chatIndex
                ]
                .unreadCount
            )

            print(
                "🔢 total:",
                totalUnreadCount
            )

            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )
        }

        /*
         На всякий случай:
         если сообщение пришло
         в открытый чат — локальный
         badge там не оставляем.
         */

        if isChatOpen {

            clearUnread(
                forServerID:
                    serverMessage.chatId
            )
        }

        // Новое сообщение поднимает чат наверх.

        sortChats()
    }

    // MARK: - Update Server Confirmed Message

    private func updateServerConfirmedMessage(
        chatIndex:
            Int,
        messageIndex:
            Int,
        serverMessage:
            ServerMessageDTO
    ) {

        let resolvedReply =
            realtimeReplyMessage(
                in:
                    chats[
                        chatIndex
                    ],
                from:
                    serverMessage.replyTo
            )

        chats[
            chatIndex
        ]
        .messages[
            messageIndex
        ]
        .serverID =
            serverMessage.id

        chats[
            chatIndex
        ]
        .messages[
            messageIndex
        ]
        .text =
            serverMessage.text

        chats[
            chatIndex
        ]
        .messages[
            messageIndex
        ]
        .sentAt =
            serverMessage.createdAt

        /*
         В текущем MessageStatus
         уже гарантированно используются:

         .sending
         .sent
         .failed

         Поэтому server-confirmed
         состояние держим как .sent.
         */

        chats[
            chatIndex
        ]
        .messages[
            messageIndex
        ]
        .status =
            serverMessage.messageStatus

        chats[
            chatIndex
        ]
        .messages[
            messageIndex
        ]
        .deliveredAt =
            serverMessage.deliveredAt

        chats[
            chatIndex
        ]
        .messages[
            messageIndex
        ]
        .readAt =
            serverMessage.readAt

        chats[
            chatIndex
        ]
        .messages[
            messageIndex
        ]
        .reaction =
            serverMessage.reaction

        let previousLocalPath =
            chats[
                chatIndex
            ]
            .messages[
                messageIndex
            ]
            .attachment?
            .localPath

        let previousFileName =
            chats[
                chatIndex
            ]
            .messages[
                messageIndex
            ]
            .attachment?
            .fileName

        if var serverAttachment =
            serverMessage.attachment {

            if serverAttachment.localPath == nil,
               serverAttachment.fileName ==
                previousFileName {

                serverAttachment.localPath =
                    previousLocalPath
            }

            chats[
                chatIndex
            ]
            .messages[
                messageIndex
            ]
            .attachment =
                serverAttachment

        } else {

            chats[
                chatIndex
            ]
            .messages[
                messageIndex
            ]
            .attachment =
                nil
        }

        chats[
            chatIndex
        ]
        .messages[
            messageIndex
        ]
        .replyTo =
            resolvedReply

        if serverMessage.createdAt >
            chats[
                chatIndex
            ]
            .updatedAt {

            chats[
                chatIndex
            ]
            .updatedAt =
                serverMessage.createdAt
        }
    }

    // MARK: - Find Optimistic Message

    private func optimisticMessageIndex(
        in chat:
            Chat,
        for serverMessage:
            ServerMessageDTO
    ) -> Int? {

        guard
            serverMessage.senderId ==
                currentUser.serverID
        else {

            return nil
        }

        return chat
            .messages
            .indices
            .reversed()
            .first {
                index in

                let message =
                    chat.messages[
                        index
                    ]

                guard
                    message.serverID ==
                        nil,
                    message.senderID ==
                        currentUser.id,
                    message.text ==
                        serverMessage.text,
                    message.replyTo?.serverID ==
                        serverMessage.replyTo?.messageId,
                    attachmentsMatch(
                        local:
                            message.attachment,
                        server:
                            serverMessage.attachment
                    )
                else {

                    return false
                }

                let delta =
                    abs(
                        message
                            .sentAt
                            .timeIntervalSince(
                                serverMessage
                                    .createdAt
                            )
                    )

                return delta < 30
            }
    }

    // MARK: - Attachment Match

    private func attachmentsMatch(
        local: Attachment?,
        server: Attachment?
    ) -> Bool {

        switch (
            local,
            server
        ) {

        case (
            nil,
            nil
        ):

            return true

        case let (
            local?,
            server?
        ):

            return
                local.type ==
                    server.type &&
                local.fileName ==
                    server.fileName

        default:

            return false
        }
    }

    // MARK: - Resolve Realtime Reply

    private func realtimeReplyMessage(
        in chat:
            Chat,
        from reply:
            ServerReplyReferenceDTO?
    ) -> Message? {

        guard let reply
        else {

            return nil
        }

        if let originalMessage =
            chat.messages.first(
                where: {

                    $0.serverID ==
                        reply.messageId
                }
            ) {

            return originalMessage
        }

        return Message(
            serverID:
                reply.messageId,
            senderID:
                localSenderID(
                    in:
                        chat,
                    serverID:
                        reply.senderId
                ),
            text:
                reply.text,
            sentAt:
                .distantPast,
            status:
                .sent,
            reaction:
                nil,
            replyTo:
                nil,
            attachment:
                nil
        )
    }

    // MARK: - Resolve Local Sender

    private func localSenderID(
        in chat:
            Chat,
        serverID:
            String
    ) -> UUID {

        if let user =
            chat.users.first(
                where: {

                    $0.serverID ==
                        serverID
                }
            ) {

            return user.id
        }

        if currentUser.serverID ==
            serverID {

            return currentUser.id
        }

        /*
         Fallback для direct chat,
         если serverID пользователя
         ещё не успел сопоставиться.
         */

        if let otherUser =
            chat.users.first(
                where: {

                    $0.id !=
                        currentUser.id
                }
            ) {

            return otherUser.id
        }

        return currentUser.id
    }

    // MARK: ========================================
    // MARK: CREATE SERVER CHAT
    // MARK: ========================================

    @discardableResult
    func createServerChat(
        with user:
            UserSearchDTO
    ) async throws -> Chat {

        guard let token =
                TokenStorage.shared.token,
              !token.isEmpty
        else {

            throw
                ChatServiceError
                    .notAuthenticated
        }

        if user.id ==
            currentUser.serverID {

            throw
                ChatServiceError
                    .cannotChatWithYourself
        }

        // MARK: Existing Direct Chat

        if let existing =
            chats.first(
                where: {
                    chat in

                    !chat.isGroup
                    &&
                    chat.users.contains {

                        $0.serverID ==
                            user.id
                    }
                }
            ) {

            return existing
        }

        // MARK: Create

        let serverChat =
            try await
                ChatAPIService
                    .shared
                    .createChat(
                        userID:
                            user.id,
                        token:
                            token
                    )

        let localChat =
            makeLocalChat(
                from:
                    serverChat
            )

        if let existingIndex =
            chats.firstIndex(
                where: {

                    $0.serverID ==
                        localChat.serverID
                }
            ) {

            chats[
                existingIndex
            ] =
                localChat

        } else {

            chats.insert(
                localChat,
                at:
                    0
            )
        }

        sortChats()

        print(
            "✅ Chat created:",
            serverChat.id
        )

        return localChat
    }

    // MARK: ========================================
    // MARK: CONVERT SERVER CHAT
    // MARK: ========================================

    private func makeLocalChat(
        from serverChat:
            ServerChatDTO
    ) -> Chat {

        let existingChat =
            chats.first {

                $0.serverID ==
                    serverChat.id
            }

        let users =
            serverChat
                .participants
                .map {
                    participant in

                    makeLocalUser(
                        from:
                            participant,
                        existingChat:
                            existingChat
                    )
                }

        let date =
            serverChat.createdAt
            ?? existingChat?.createdAt
            ?? Date()

        return Chat(
            id:
                existingChat?.id
                ?? UUID(),
            serverID:
                serverChat.id,
            users:
                users,
            messages:
                existingChat?.messages
                ?? [],
            title:
                existingChat?.title,
            avatar:
                existingChat?.avatar,
            isGroup:
                users.count > 2,
            unreadCount:
                existingChat?
                    .unreadCount
                ?? 0,
            isPinned:
                existingChat?
                    .isPinned
                ?? false,
            isMuted:
                existingChat?
                    .isMuted
                ?? false,
            isArchived:
                existingChat?
                    .isArchived
                ?? false,
            draft:
                existingChat?.draft
                ?? "",
            createdAt:
                date,
            updatedAt:
                existingChat?
                    .updatedAt
                ?? date
        )
    }

    // MARK: ========================================
    // MARK: CONVERT USER
    // MARK: ========================================

    private func makeLocalUser(
        from participant:
            ServerChatParticipantDTO,
        existingChat:
            Chat?
    ) -> User {

        let nickname =
            participant
                .nickname
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let name =
            nickname.isEmpty
            ? "User"
            : nickname

        // MARK: Current User

        if participant.id ==
            currentUser.serverID {

            currentUser.username =
                ProfileStorage.shared.username

            currentUser.displayName =
                name

            currentUser.isOnline =
                onlineUserIDs
                    .contains(
                        participant.id
                    )

            return currentUser
        }

        // MARK: Existing Local User

        if var existingUser =
            existingChat?
                .users
                .first(
                    where: {

                        $0.serverID ==
                            participant.id
                    }
                ) {

            existingUser.username =
                name

            existingUser.displayName =
                name

            existingUser.isOnline =
                onlineUserIDs
                    .contains(
                        participant.id
                    )

            return existingUser
        }

        // MARK: New User

        return User(
            serverID:
                participant.id,
            username:
                name,
            displayName:
                name,
            isOnline:
                onlineUserIDs
                    .contains(
                        participant.id
                    )
        )
    }

    // MARK: ========================================
    // MARK: AUTH USER
    // MARK: ========================================

    func applyAuthenticatedUser(
        serverID:
            String,
        username:
            String? = nil,
        displayName:
            String? = nil
    ) {

        currentUser.serverID =
            serverID

        currentUser.isOnline =
            onlineUserIDs
                .contains(
                    serverID
                )

        currentUser.username =
            ProfileStorage.shared.username

        currentUser.avatarData =
            ProfileStorage.shared.avatarData

        if let displayName {

            let value =
                displayName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            if !value.isEmpty {

                currentUser.displayName =
                    value
            }
        }

        updateCurrentUserInChats()
    }

    // MARK: - Restore Session

    func restoreSession() {

        guard let serverID =
                TokenStorage.shared.userID,
              !serverID.isEmpty
        else {

            return
        }

        currentUser.serverID =
            serverID

        currentUser.username =
            ProfileStorage.shared.username

        currentUser.avatarData =
            ProfileStorage.shared.avatarData

        currentUser.isOnline =
            onlineUserIDs
                .contains(
                    serverID
                )

        updateCurrentUserInChats()
    }

    // MARK: - Update Current User

    private func updateCurrentUserInChats() {

        guard let serverID =
                currentUser.serverID
        else {

            return
        }

        for chatIndex
        in chats.indices {

            guard let userIndex =
                    chats[
                        chatIndex
                    ]
                    .users
                    .firstIndex(
                        where: {

                            $0.serverID ==
                                serverID
                        }
                    )
            else {

                continue
            }

            chats[
                chatIndex
            ]
            .users[
                userIndex
            ] =
                currentUser
        }
    }

    // MARK: ========================================
    // MARK: LOGOUT / RESET
    // MARK: ========================================

    func clearAuthenticatedUser() {

        currentUser.serverID =
            nil

        currentUser.username =
            "me"

        currentUser.displayName =
            "Me"

        currentUser.isOnline =
            false

        currentUser.avatarData =
            nil

        chats.removeAll()

        onlineUserIDs.removeAll()

        totalUnreadCount =
            0

        activeChatServerID =
            nil

        isLoadingChats =
            false

        chatLoadingError =
            nil

        isUsingCachedChats =
            false

        lastChatsSyncAt =
            nil
    }

    // MARK: - Missing Session Reset

    private func resetChatStateForMissingSession(
        message:
            String
    ) {

        chats.removeAll()

        onlineUserIDs.removeAll()

        totalUnreadCount =
            0

        activeChatServerID =
            nil

        chatLoadingError =
            message
    }

    // MARK: ========================================
    // MARK: CHAT INDEX
    // MARK: ========================================

    func chatIndex(
        for id:
            UUID
    ) -> Int? {

        chats.firstIndex {

            $0.id ==
                id
        }
    }

    func chatIndex(
        forServerID serverID:
            String
    ) -> Int? {

        chats.firstIndex {

            $0.serverID ==
                serverID
        }
    }

    // MARK: ========================================
    // MARK: UPDATE CHAT
    // MARK: ========================================

    func update(
        _ chat:
            Chat
    ) {

        guard let index =
                chatIndex(
                    for:
                        chat.id
                )
        else {

            return
        }

        /*
         ВАЖНО:

         ChatViewModel может держать
         более старую копию Chat.

         Поэтому его service.update(chat)
         не должен вернуть старое
         unreadCount назад после того,
         как ChatService уже очистил badge.
         */

        let preservedUnread =
            chats[
                index
            ]
            .unreadCount

        var updatedChat =
            chat

        updatedChat.unreadCount =
            preservedUnread

        /*
         То же самое для presence:
         старый ChatView не должен
         вернуть пользователя в Offline.
         */

        applyPresence(
            to:
                &updatedChat
        )

        chats[
            index
        ] =
            updatedChat

        sortChats()
    }

    // MARK: - Apply Presence To Chat

    private func applyPresence(
        to chat:
            inout Chat
    ) {

        for userIndex
        in chat.users.indices {

            guard let serverID =
                    chat
                        .users[
                            userIndex
                        ]
                        .serverID
            else {

                continue
            }

            if serverID ==
                currentUser.serverID {

                chat.users[
                    userIndex
                ] =
                    currentUser

            } else {

                chat.users[
                    userIndex
                ]
                .isOnline =
                    onlineUserIDs
                        .contains(
                            serverID
                        )
            }
        }
    }

    // MARK: ========================================
    // MARK: ADD CHAT
    // MARK: ========================================

    func addChat(
        _ chat:
            Chat
    ) {

        if let serverID =
            chat.serverID,
           chats.contains(
            where: {

                $0.serverID ==
                    serverID
            }
           ) {

            return
        }

        guard
            !chats.contains(
                where: {

                    $0.id ==
                        chat.id
                }
            )
        else {

            return
        }

        var chatToAdd =
            chat

        applyPresence(
            to:
                &chatToAdd
        )

        chats.insert(
            chatToAdd,
            at:
                0
        )

        sortChats()
    }

    // MARK: ========================================
    // MARK: DELETE CHAT
    // MARK: ========================================

    func deleteChat(
        _ chatID:
            UUID
    ) {

        guard let index =
                chatIndex(
                    for:
                        chatID
                )
        else {

            return
        }

        let removedUnread =
            chats[
                index
            ]
            .unreadCount

        let removedServerID =
            chats[
                index
            ]
            .serverID

        chats.remove(
            at:
                index
        )

        totalUnreadCount =
            max(
                0,
                totalUnreadCount -
                    removedUnread
            )

        if activeChatServerID ==
            removedServerID {

            activeChatServerID =
                nil
        }
    }

    // MARK: ========================================
    // MARK: LEGACY LOCAL CREATE
    // MARK: ========================================

    /*
     Оставляем временно,
     если старый код всё ещё
     вызывает createChat(username:).
     */

    func createChat(
        username:
            String
    ) {

        let name =
            username
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !name.isEmpty
        else {

            return
        }

        let user =
            User(
                username:
                    name.lowercased(),
                displayName:
                    name,
                isOnline:
                    false
            )

        let chat =
            Chat(
                users: [
                    currentUser,
                    user
                ],
                messages: []
            )

        addChat(
            chat
        )
    }

    // MARK: ========================================
    // MARK: ADD MESSAGE
    // MARK: ========================================

    func addMessage(
        _ message:
            Message,
        to chatID:
            UUID
    ) {

        guard let index =
                chatIndex(
                    for:
                        chatID
                )
        else {

            return
        }

        guard
            !chats[
                index
            ]
            .messages
            .contains(
                where: {

                    $0.id ==
                        message.id
                }
            )
        else {

            return
        }

        chats[
            index
        ]
        .messages
        .append(
            message
        )

        chats[
            index
        ]
        .updatedAt =
            message.sentAt

        sortChats()
    }

    // MARK: ========================================
    // MARK: REMOVE MESSAGE
    // MARK: ========================================

    func removeMessage(
        _ messageID:
            UUID,
        from chatID:
            UUID
    ) {

        guard let index =
                chatIndex(
                    for:
                        chatID
                )
        else {

            return
        }

        chats[
            index
        ]
        .messages
        .removeAll {

            $0.id ==
                messageID
        }

        chats[
            index
        ]
        .updatedAt =
            Date()

        sortChats()
    }

    // MARK: ========================================
    // MARK: REPLACE MESSAGES
    // MARK: ========================================

    func replaceMessages(
        _ messages:
            [Message],
        in chatID:
            UUID
    ) {

        guard let index =
                chatIndex(
                    for:
                        chatID
                )
        else {

            return
        }

        chats[
            index
        ]
        .messages =
            messages

        if let last =
            messages.last {

            chats[
                index
            ]
            .updatedAt =
                last.sentAt
        }

        sortChats()
    }

    // MARK: ========================================
    // MARK: SERVER ID
    // MARK: ========================================

    func setServerID(
        _ serverID:
            String,
        for chatID:
            UUID
    ) {

        guard let index =
                chatIndex(
                    for:
                        chatID
                )
        else {

            return
        }

        chats[
            index
        ]
        .serverID =
            serverID
    }

    // MARK: ========================================
    // MARK: SORT
    // MARK: ========================================

    private func sortChats() {

        chats.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.lastActivity > rhs.lastActivity
        }

        CacheStorage.shared.saveChats(
            chats
        )
    }
}

// MARK: ========================================
// MARK: ERRORS
// MARK: ========================================

enum ChatServiceError:
    LocalizedError {

    case notAuthenticated

    case cannotChatWithYourself

    var errorDescription:
        String? {

        switch self {

        case .notAuthenticated:

            return
                "Необходимо войти в аккаунт"

        case .cannotChatWithYourself:

            return
                "Нельзя создать чат с собой"
        }
    }
}
