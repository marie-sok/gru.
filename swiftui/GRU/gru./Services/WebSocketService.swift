import Foundation
import Observation

@MainActor
@Observable
final class WebSocketService {

    static let shared =
        WebSocketService()

    // MARK: - Connection State

    private(set) var isSocketOpened =
        false

    private(set) var isConnected =
        false

    private(set) var isReconnecting =
        false

    private(set) var lastError:
        String?

    // MARK: - Configuration

    private var socketURLString: String {
        GRUServerConfiguration.webSocketURL
    }

    // MARK: - Socket

    private var socketTask:
        URLSessionWebSocketTask?

    private var receiveTask:
        Task<Void, Never>?

    private var reconnectTask:
        Task<Void, Never>?

    private var token:
        String?

    private var shouldReconnect =
        true

    private var reconnectAttempt =
        0

    // MARK: - Message Listeners

    private var messageListeners:
        [
            String:
            [
                UUID:
                (ServerMessageDTO) -> Void
            ]
        ] = [:]

    // MARK: - Typing Listeners

    private var typingListeners:
        [
            String:
            [
                UUID:
                (TypingEventDTO) -> Void
            ]
        ] = [:]

    // MARK: - Desired Subscriptions

    private var desiredMessageSubscriptions:
        Set<String> = []

    private var desiredTypingSubscriptions:
        Set<String> = []

    /*
     Presence глобальный.

     Нам нужна только одна подписка
     на всё приложение.
     */

    private var wantsPresenceSubscription =
        true

    // MARK: - Active Subscriptions

    private var activeMessageSubscriptions:
        Set<String> = []

    private var activeTypingSubscriptions:
        Set<String> = []

    private var isPresenceSubscribed =
        false

    // MARK: - Init

    private init() {}

    // MARK: - Connect

    func connect(
        token: String
    ) {

        guard !token.isEmpty else {

            fail(
                "JWT token is empty"
            )

            return
        }

        self.token =
            token

        shouldReconnect =
            true

        wantsPresenceSubscription =
            true

        if isConnected {

            print(
                "ℹ️ WebSocket already connected"
            )

            subscribeToDesiredTopics()

            return
        }

        if socketTask != nil {

            print(
                "ℹ️ WebSocket connection already in progress"
            )

            return
        }

        reconnectTask?
            .cancel()

        reconnectTask =
            nil

        openSocket(
            token:
                token
        )
    }

    // MARK: - Open Socket

    private func openSocket(
        token: String
    ) {

        guard let url =
                URL(
                    string:
                        socketURLString
                )
        else {

            fail(
                "Invalid WebSocket URL"
            )

            return
        }

        print("")
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        if reconnectAttempt == 0 {

            print(
                "🔌 WebSocket connecting"
            )

        } else {

            print(
                "🔄 WebSocket reconnecting"
            )
        }

        print(
            "🌐",
            socketURLString
        )

        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        lastError =
            nil

        activeMessageSubscriptions
            .removeAll()

        activeTypingSubscriptions
            .removeAll()

        isPresenceSubscribed =
            false

        let request =
            URLRequest(
                url:
                    url,
                timeoutInterval:
                    15
            )

        let task =
            URLSession.shared
                .webSocketTask(
                    with:
                        request
                )

        socketTask =
            task

        isSocketOpened =
            true

        isConnected =
            false

        task.resume()

        startReceiving()

        sendConnectFrame(
            token:
                token
        )
    }

    // MARK: - Disconnect

    func disconnect() {

        shouldReconnect =
            false

        reconnectTask?
            .cancel()

        reconnectTask =
            nil

        receiveTask?
            .cancel()

        receiveTask =
            nil

        if isConnected {

            let frame =
                makeFrame(
                    command:
                        "DISCONNECT"
                )

            sendRaw(
                frame,
                label:
                    "DISCONNECT"
            )
        }

        socketTask?
            .cancel(
                with:
                    .normalClosure,
                reason:
                    nil
            )

        socketTask =
            nil

        isSocketOpened =
            false

        isConnected =
            false

        isReconnecting =
            false

        reconnectAttempt =
            0

        activeMessageSubscriptions
            .removeAll()

        activeTypingSubscriptions
            .removeAll()

        isPresenceSubscribed =
            false

        print(
            "🔌 WebSocket disconnected"
        )
    }

    // MARK: - Full Session Reset

    func resetSession() {

        disconnect()

        token =
            nil

        messageListeners
            .removeAll()

        typingListeners
            .removeAll()

        desiredMessageSubscriptions
            .removeAll()

        desiredTypingSubscriptions
            .removeAll()

        wantsPresenceSubscription =
            false

        activeMessageSubscriptions
            .removeAll()

        activeTypingSubscriptions
            .removeAll()

        isPresenceSubscribed =
            false

        lastError =
            nil

        print(
            "🧹 WebSocket session fully reset"
        )
    }

    // MARK: - Message Listener

    @discardableResult
    func addListener(
        chatID: String,
        handler:
            @escaping
            (ServerMessageDTO) -> Void
    ) -> UUID {

        let listenerID =
            UUID()

        var handlers =
            messageListeners[
                chatID
            ] ?? [:]

        handlers[
            listenerID
        ] =
            handler

        messageListeners[
            chatID
        ] =
            handlers

        desiredMessageSubscriptions
            .insert(
                chatID
            )

        print(
            "➕ Message listener:",
            chatID
        )

        if isConnected {

            subscribeMessages(
                chatID:
                    chatID
            )
        }

        return listenerID
    }

    // MARK: - Remove Message Listener

    func removeListener(
        chatID: String,
        listenerID: UUID
    ) {

        messageListeners[
            chatID
        ]?[
            listenerID
        ] =
            nil

        guard
            messageListeners[
                chatID
            ]?.isEmpty == true
        else {

            return
        }

        messageListeners[
            chatID
        ] =
            nil

        desiredMessageSubscriptions
            .remove(
                chatID
            )

        unsubscribeMessages(
            chatID:
                chatID
        )
    }

    // MARK: - Typing Listener

    @discardableResult
    func addTypingListener(
        chatID: String,
        handler:
            @escaping
            (TypingEventDTO) -> Void
    ) -> UUID {

        let listenerID =
            UUID()

        var handlers =
            typingListeners[
                chatID
            ] ?? [:]

        handlers[
            listenerID
        ] =
            handler

        typingListeners[
            chatID
        ] =
            handlers

        desiredTypingSubscriptions
            .insert(
                chatID
            )

        print(
            "➕ Typing listener:",
            chatID
        )

        if isConnected {

            subscribeTyping(
                chatID:
                    chatID
            )
        }

        return listenerID
    }

    // MARK: - Remove Typing Listener

    func removeTypingListener(
        chatID: String,
        listenerID: UUID
    ) {

        typingListeners[
            chatID
        ]?[
            listenerID
        ] =
            nil

        guard
            typingListeners[
                chatID
            ]?.isEmpty == true
        else {

            return
        }

        typingListeners[
            chatID
        ] =
            nil

        desiredTypingSubscriptions
            .remove(
                chatID
            )

        unsubscribeTyping(
            chatID:
                chatID
        )
    }

    // MARK: - Send Typing

    func sendTyping(
        chatID: String,
        typing: Bool
    ) {

        guard isConnected else {

            print(
                "⚠️ Typing skipped: WebSocket offline"
            )

            return
        }

        guard let token,
              !token.isEmpty
        else {

            print(
                "❌ Typing skipped: JWT missing"
            )

            return
        }

        let payload =
            TypingSendDTO(
                chatId:
                    chatID,
                typing:
                    typing
            )

        guard let data =
                try? JSONEncoder()
                    .encode(
                        payload
                    ),
              let body =
                String(
                    data:
                        data,
                    encoding:
                        .utf8
                )
        else {

            print(
                "❌ Typing encode error"
            )

            return
        }

        let frame =
            makeFrame(
                command:
                    "SEND",
                headers: [
                    "destination":
                        "/app/typing",
                    "content-type":
                        "application/json",
                    "Authorization":
                        "Bearer \(token)"
                ],
                body:
                    body
            )

        sendRaw(
            frame,
            label:
                "TYPING \(typing)"
        )
    }

    // MARK: - CONNECT

    private func sendConnectFrame(
        token: String
    ) {

        let frame =
            makeFrame(
                command:
                    "CONNECT",
                headers: [
                    "accept-version":
                        "1.2",
                    "host":
                        GRUServerConfiguration.host,
                    "heart-beat":
                        "0,0",
                    "Authorization":
                        "Bearer \(token)"
                ]
            )

        print(
            "📤 STOMP CONNECT"
        )

        sendRaw(
            frame,
            label:
                "CONNECT"
        )
    }

    // MARK: - Restore All Subscriptions

    private func subscribeToDesiredTopics() {

        // Presence

        if wantsPresenceSubscription {

            subscribePresence()
        }

        // Messages

        for chatID
        in desiredMessageSubscriptions {

            subscribeMessages(
                chatID:
                    chatID
            )
        }

        // Typing

        for chatID
        in desiredTypingSubscriptions {

            subscribeTyping(
                chatID:
                    chatID
            )
        }
    }

    // MARK: - Subscribe Presence

    private func subscribePresence() {

        guard isConnected else {

            return
        }

        guard
            !isPresenceSubscribed
        else {

            return
        }

        guard let token,
              !token.isEmpty
        else {

            return
        }

        let destination =
            "/topic/presence"

        let frame =
            makeFrame(
                command:
                    "SUBSCRIBE",
                headers: [
                    "id":
                        "presence-global",
                    "destination":
                        destination,
                    "ack":
                        "auto",
                    "Authorization":
                        "Bearer \(token)"
                ]
            )

        isPresenceSubscribed =
            true

        sendRaw(
            frame,
            label:
                "SUBSCRIBE \(destination)"
        )

        print(
            "🟢 PRESENCE SUBSCRIBE:",
            destination
        )
    }

    // MARK: - Subscribe Messages

    private func subscribeMessages(
        chatID: String
    ) {

        guard isConnected else {

            return
        }

        guard let token,
              !token.isEmpty
        else {

            return
        }

        guard
            !activeMessageSubscriptions
                .contains(
                    chatID
                )
        else {

            return
        }

        let destination =
            "/topic/chat/\(chatID)"

        let frame =
            makeFrame(
                command:
                    "SUBSCRIBE",
                headers: [
                    "id":
                        "message-\(chatID)",
                    "destination":
                        destination,
                    "ack":
                        "auto",
                    "Authorization":
                        "Bearer \(token)"
                ]
            )

        activeMessageSubscriptions
            .insert(
                chatID
            )

        sendRaw(
            frame,
            label:
                "SUBSCRIBE \(destination)"
        )

        print(
            "📡 MESSAGE SUBSCRIBE:",
            destination
        )
    }

    // MARK: - Subscribe Typing

    private func subscribeTyping(
        chatID: String
    ) {

        guard isConnected else {

            return
        }

        guard let token,
              !token.isEmpty
        else {

            return
        }

        guard
            !activeTypingSubscriptions
                .contains(
                    chatID
                )
        else {

            return
        }

        let destination =
            "/topic/chat/\(chatID)/typing"

        let frame =
            makeFrame(
                command:
                    "SUBSCRIBE",
                headers: [
                    "id":
                        "typing-\(chatID)",
                    "destination":
                        destination,
                    "ack":
                        "auto",
                    "Authorization":
                        "Bearer \(token)"
                ]
            )

        activeTypingSubscriptions
            .insert(
                chatID
            )

        sendRaw(
            frame,
            label:
                "SUBSCRIBE \(destination)"
        )

        print(
            "⌨️ TYPING SUBSCRIBE:",
            destination
        )
    }

    // MARK: - Unsubscribe Messages

    private func unsubscribeMessages(
        chatID: String
    ) {

        guard
            activeMessageSubscriptions
                .contains(
                    chatID
                )
        else {

            return
        }

        let frame =
            makeFrame(
                command:
                    "UNSUBSCRIBE",
                headers: [
                    "id":
                        "message-\(chatID)"
                ]
            )

        activeMessageSubscriptions
            .remove(
                chatID
            )

        sendRaw(
            frame,
            label:
                "UNSUBSCRIBE message \(chatID)"
        )
    }

    // MARK: - Unsubscribe Typing

    private func unsubscribeTyping(
        chatID: String
    ) {

        guard
            activeTypingSubscriptions
                .contains(
                    chatID
                )
        else {

            return
        }

        let frame =
            makeFrame(
                command:
                    "UNSUBSCRIBE",
                headers: [
                    "id":
                        "typing-\(chatID)"
                ]
            )

        activeTypingSubscriptions
            .remove(
                chatID
            )

        sendRaw(
            frame,
            label:
                "UNSUBSCRIBE typing \(chatID)"
        )
    }

    // MARK: - Receive

    private func startReceiving() {

        receiveTask?
            .cancel()

        receiveTask =
            Task {
                [weak self] in

                guard let self else {

                    return
                }

                print(
                    "👂 WebSocket receive loop started"
                )

                while !Task.isCancelled {

                    guard let socket =
                            self.socketTask
                    else {

                        return
                    }

                    do {

                        let message =
                            try await socket
                                .receive()

                        switch message {

                        case .string(
                            let text
                        ):

                            self.processIncoming(
                                text
                            )

                        case .data(
                            let data
                        ):

                            guard let text =
                                    String(
                                        data:
                                            data,
                                        encoding:
                                            .utf8
                                    )
                            else {

                                continue
                            }

                            self.processIncoming(
                                text
                            )

                        @unknown default:

                            break
                        }

                    } catch {

                        if Task.isCancelled {

                            return
                        }

                        self.handleSocketFailure(
                            error
                        )

                        return
                    }
                }
            }
    }

    // MARK: - Socket Failure

    private func handleSocketFailure(
        _ error: Error
    ) {

        guard
            socketTask != nil ||
            isConnected ||
            isSocketOpened
        else {

            return
        }

        print("")
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
        print(
            "❌ WebSocket connection lost"
        )
        print(
            error.localizedDescription
        )
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        lastError =
            error.localizedDescription

        isSocketOpened =
            false

        isConnected =
            false

        receiveTask?
            .cancel()

        receiveTask =
            nil

        socketTask?
            .cancel()

        socketTask =
            nil

        activeMessageSubscriptions
            .removeAll()

        activeTypingSubscriptions
            .removeAll()

        isPresenceSubscribed =
            false

        scheduleReconnect()
    }

    // MARK: - Reconnect

    private func scheduleReconnect() {

        guard
            shouldReconnect,
            let token,
            !token.isEmpty
        else {

            return
        }

        guard
            reconnectTask == nil
        else {

            return
        }

        reconnectAttempt +=
            1

        let delay: UInt64

        switch reconnectAttempt {

        case 1:

            delay = 1

        case 2:

            delay = 2

        case 3:

            delay = 4

        default:

            delay = 8
        }

        isReconnecting =
            true

        print(
            "🔄 WebSocket reconnect in \(delay)s"
        )

        reconnectTask =
            Task {
                [weak self] in

                do {

                    try await Task.sleep(
                        nanoseconds:
                            delay *
                            1_000_000_000
                    )

                } catch {

                    return
                }

                guard let self else {

                    return
                }

                self.reconnectTask =
                    nil

                guard
                    self.shouldReconnect,
                    self.socketTask == nil
                else {

                    return
                }

                self.openSocket(
                    token:
                        token
                )
            }
    }

    // MARK: - Process Incoming

    private func processIncoming(
        _ rawPayload: String
    ) {

        // STOMP heartbeat

        if
            rawPayload == "\n" ||
            rawPayload == "\r\n"
        {

            return
        }

        let frames =
            rawPayload.components(
                separatedBy:
                    "\u{0000}"
            )

        for rawFrame
        in frames {

            let frame =
                rawFrame
                    .trimmingCharacters(
                        in:
                            .newlines
                    )

            guard
                !frame.isEmpty
            else {

                continue
            }

            processSTOMPFrame(
                frame
            )
        }
    }

    // MARK: - Process STOMP

    private func processSTOMPFrame(
        _ frame: String
    ) {

        let command =
            frame
                .components(
                    separatedBy:
                        "\n"
                )
                .first?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        switch command {

        case "CONNECTED":

            handleConnected()

        case "MESSAGE":

            handleMessageFrame(
                frame
            )

        case "ERROR":

            handleSTOMPError(
                frame
            )

        case "RECEIPT":

            print(
                "✅ STOMP RECEIPT"
            )

        default:

            if !command.isEmpty {

                print(
                    "⚠️ Unknown STOMP frame:",
                    command
                )
            }
        }
    }

    // MARK: - Connected

    private func handleConnected() {

        reconnectTask?
            .cancel()

        reconnectTask =
            nil

        reconnectAttempt =
            0

        isReconnecting =
            false

        isConnected =
            true

        isSocketOpened =
            true

        lastError =
            nil

        activeMessageSubscriptions
            .removeAll()

        activeTypingSubscriptions
            .removeAll()

        isPresenceSubscribed =
            false

        print("")
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
        print(
            "✅ WebSocket STOMP connected"
        )
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        subscribeToDesiredTopics()

        /*
         После STOMP CONNECTED пользователь
         уже зарегистрирован backend как online.

         Обновляем snapshot, чтобы клиент
         получил актуальный список всех online.
         */

        Task {

            await ChatService.shared
                .loadPresence()
        }
    }

    // MARK: - MESSAGE Dispatcher

    private func handleMessageFrame(
        _ frame: String
    ) {

        let parsed =
            parseSTOMPFrame(
                frame
            )

        guard let destination =
                parsed.headers[
                    "destination"
                ]
        else {

            print(
                "⚠️ STOMP MESSAGE without destination"
            )

            return
        }

        // MARK: Presence

        if destination ==
            "/topic/presence" {

            handlePresenceMessage(
                destination:
                    destination,
                body:
                    parsed.body
            )

            return
        }

        // MARK: Typing

        if destination.hasSuffix(
            "/typing"
        ) {

            handleTypingMessage(
                destination:
                    destination,
                body:
                    parsed.body
            )

            return
        }

        // MARK: Chat Message

        handleChatMessage(
            destination:
                destination,
            body:
                parsed.body
        )
    }

    // MARK: - Presence Message

    private func handlePresenceMessage(
        destination: String,
        body: String
    ) {

        guard let data =
                body.data(
                    using:
                        .utf8
                )
        else {

            return
        }

        do {

            let event =
                try JSONCoding.decoder
                    .decode(
                        PresenceEventDTO.self,
                        from:
                            data
                    )

            print("")
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )
            print(
                "🟢 REALTIME PRESENCE"
            )
            print(
                "📡",
                destination
            )
            print(
                "👤",
                event.userId
            )
            print(
                "🌐 online:",
                event.online
            )
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            ChatService.shared
                .applyPresenceEvent(
                    event
                )

        } catch {

            print("")
            print(
                "❌ Presence decode error"
            )
            print(
                error
            )
            print(
                "📥 BODY:"
            )
            print(
                body
            )
        }
    }

    // MARK: - Chat Message

    private func handleChatMessage(
        destination: String,
        body: String
    ) {

        guard let data =
                body.data(
                    using:
                        .utf8
                )
        else {

            return
        }

        do {

            let message =
                try JSONCoding.decoder
                    .decode(
                        ServerMessageDTO.self,
                        from:
                            data
                    )

            print("")
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )
            print(
                "💬 REALTIME MESSAGE"
            )
            print(
                "📡",
                destination
            )
            print(
                "🆔",
                message.id
            )
            print(
                "💬",
                message.text
            )
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            guard let handlers =
                    messageListeners[
                        message.chatId
                    ]?.values
            else {

                return
            }

            for handler
            in handlers {

                handler(
                    message
                )
            }

        } catch {

            print("")
            print(
                "❌ WebSocket message decode error"
            )
            print(
                error
            )
            print(
                "📥 BODY:"
            )
            print(
                body
            )
        }
    }

    // MARK: - Typing Message

    private func handleTypingMessage(
        destination: String,
        body: String
    ) {

        guard let data =
                body.data(
                    using:
                        .utf8
                )
        else {

            return
        }

        do {

            let event =
                try JSONCoding.decoder
                    .decode(
                        TypingEventDTO.self,
                        from:
                            data
                    )

            print("")
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )
            print(
                "⌨️ REALTIME TYPING"
            )
            print(
                "📡",
                destination
            )
            print(
                "👤",
                event.userId
            )
            print(
                "⌨️ typing:",
                event.typing
            )
            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            guard let handlers =
                    typingListeners[
                        event.chatId
                    ]?.values
            else {

                return
            }

            for handler
            in handlers {

                handler(
                    event
                )
            }

        } catch {

            print("")
            print(
                "❌ Typing decode error"
            )
            print(
                error
            )
            print(
                "📥 BODY:"
            )
            print(
                body
            )
        }
    }

    // MARK: - STOMP Error

    private func handleSTOMPError(
        _ frame: String
    ) {

        print("")
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
        print(
            "❌ STOMP ERROR"
        )
        print(
            sanitize(
                frame
            )
        )
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        lastError =
            frame

        isConnected =
            false

        isSocketOpened =
            false

        receiveTask?
            .cancel()

        receiveTask =
            nil

        socketTask?
            .cancel()

        socketTask =
            nil

        activeMessageSubscriptions
            .removeAll()

        activeTypingSubscriptions
            .removeAll()

        isPresenceSubscribed =
            false

        validateSessionBeforeReconnect()
    }

    // MARK: - Session Probe After STOMP ERROR

    private func validateSessionBeforeReconnect() {

        guard
            shouldReconnect,
            let token,
            !token.isEmpty
        else {

            return
        }

        let tokenBeingValidated =
            token

        print(
            "🔐 Validating session before STOMP reconnect"
        )

        Task {
            [weak self] in

            guard let self else {
                return
            }

            do {

                _ =
                    try await
                        ChatAPIService.shared
                        .getChats(
                            token:
                                tokenBeingValidated
                        )

                guard
                    self.shouldReconnect,
                    self.token ==
                        tokenBeingValidated
                else {

                    return
                }

                print(
                    "✅ Session valid — STOMP reconnect allowed"
                )

                self.scheduleReconnect()

            } catch {

                /*
                 APIClient clears the session
                 when /chats returns 401 or the
                 Spring auth 403 "Access Denied".
                 */
                guard
                    self.shouldReconnect,
                    self.token ==
                        tokenBeingValidated,
                    TokenStorage.shared.token != nil
                else {

                    print(
                        "🔐 STOMP reconnect stopped: session invalid"
                    )

                    return
                }

                /*
                 A temporary network/server error
                 must not destroy a valid session.
                 Keep ordinary reconnect enabled.
                 */
                print(
                    "⚠️ Session probe inconclusive:",
                    error.localizedDescription
                )

                self.scheduleReconnect()
            }
        }
    }

    // MARK: - Send Raw

    private func sendRaw(
        _ frame: String,
        label: String
    ) {

        guard let socket =
                socketTask
        else {

            print(
                "❌ \(label) not sent: socket is nil"
            )

            return
        }

        Task {
            [weak self] in

            guard let self else {

                return
            }

            do {

                try await socket.send(
                    .string(
                        frame
                    )
                )

                print(
                    "✅ STOMP \(label) sent"
                )

            } catch {

                print(
                    "❌ STOMP \(label) send error:",
                    error.localizedDescription
                )

                self.handleSocketFailure(
                    error
                )
            }
        }
    }

    // MARK: - STOMP Frame Builder

    private func makeFrame(
        command: String,
        headers:
            [String: String] = [:],
        body: String? = nil
    ) -> String {

        var frame =
            command + "\n"

        for key
        in headers.keys.sorted() {

            guard let value =
                    headers[
                        key
                    ]
            else {

                continue
            }

            frame +=
                "\(key):\(value)\n"
        }

        frame +=
            "\n"

        if let body {

            frame +=
                body
        }

        frame +=
            "\u{0000}"

        return frame
    }

    // MARK: - STOMP Parser

    private func parseSTOMPFrame(
        _ frame: String
    ) -> (
        command: String,
        headers: [String: String],
        body: String
    ) {

        guard let separator =
                frame.range(
                    of:
                        "\n\n"
                )
        else {

            return (
                frame,
                [:],
                ""
            )
        }

        let headerPart =
            String(
                frame[
                    ..<separator.lowerBound
                ]
            )

        let body =
            String(
                frame[
                    separator.upperBound...
                ]
            )

        var lines =
            headerPart.components(
                separatedBy:
                    "\n"
            )

        let command =
            lines.isEmpty
            ? ""
            : lines.removeFirst()

        var headers:
            [String: String] = [:]

        for line
        in lines {

            guard let colon =
                    line.firstIndex(
                        of:
                            ":"
                    )
            else {

                continue
            }

            let key =
                String(
                    line[
                        ..<colon
                    ]
                )

            let valueStart =
                line.index(
                    after:
                        colon
                )

            let value =
                String(
                    line[
                        valueStart...
                    ]
                )

            headers[
                key
            ] =
                value
        }

        return (
            command,
            headers,
            body
        )
    }

    // MARK: - Sanitize

    private func sanitize(
        _ text: String
    ) -> String {

        text.replacingOccurrences(
            of:
                "\u{0000}",
            with:
                ""
        )
    }

    // MARK: - Fail

    private func fail(
        _ message: String
    ) {

        lastError =
            message

        isConnected =
            false

        isSocketOpened =
            false

        print("")
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
        print(
            "❌ WebSocket:",
            message
        )
        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
    }
}

// MARK: - Typing Send DTO

private struct TypingSendDTO:
    Codable {

    let chatId:
        String

    let typing:
        Bool
}
