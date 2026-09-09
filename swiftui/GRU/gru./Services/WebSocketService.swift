import Foundation
import Observation

@MainActor
@Observable
final class WebSocketService {

    static let shared = WebSocketService()

    // MARK: - Public connection state

    private(set) var isSocketOpened = false
    private(set) var isConnected = false
    private(set) var isReconnecting = false
    private(set) var lastError: String?

    // MARK: - Transport

    private var socketURLString: String {
        GRUServerConfiguration.webSocketURL
    }

    private var socketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var token: String?
    private var shouldReconnect = true
    private var reconnectAttempt = 0

    // MARK: - Listeners

    private var messageListeners: [
        String: [UUID: (ServerMessageDTO) -> Void]
    ] = [:]

    private var typingListeners: [
        String: [UUID: (TypingEventDTO) -> Void]
    ] = [:]

    private var desiredMessageSubscriptions: Set<String> = []
    private var desiredTypingSubscriptions: Set<String> = []
    private var activeMessageSubscriptions: Set<String> = []
    private var activeTypingSubscriptions: Set<String> = []

    // Presence is a single per-user subscription. It is deliberately not a
    // global topic: online state is relationship metadata.
    private var wantsPresenceSubscription = true
    private var isPresenceSubscribed = false

    private init() {}

    // MARK: - Connect / disconnect

    func connect(token: String) {
        guard !token.isEmpty else {
            fail("JWT token is empty")
            return
        }

        self.token = token
        shouldReconnect = true
        wantsPresenceSubscription = true

        if isConnected {
            subscribeToDesiredTopics()
            return
        }

        guard socketTask == nil else {
            return
        }

        reconnectTask?.cancel()
        reconnectTask = nil
        openSocket(token: token)
    }

    func disconnect() {
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil

        if isConnected {
            sendRaw(
                makeFrame(command: "DISCONNECT"),
                label: "DISCONNECT"
            )
        }

        socketTask?.cancel(with: .normalClosure, reason: nil)
        socketTask = nil
        resetConnectionState()
        reconnectAttempt = 0

        #if DEBUG
        print("🔌 WebSocket disconnected")
        #endif
    }

    func resetSession() {
        disconnect()
        token = nil
        messageListeners.removeAll()
        typingListeners.removeAll()
        desiredMessageSubscriptions.removeAll()
        desiredTypingSubscriptions.removeAll()
        wantsPresenceSubscription = false
        activeMessageSubscriptions.removeAll()
        activeTypingSubscriptions.removeAll()
        isPresenceSubscribed = false
        lastError = nil

        #if DEBUG
        print("🧹 WebSocket session fully reset")
        #endif
    }

    private func openSocket(token: String) {
        guard let url = URL(string: socketURLString) else {
            fail("Invalid WebSocket URL")
            return
        }

        lastError = nil
        activeMessageSubscriptions.removeAll()
        activeTypingSubscriptions.removeAll()
        isPresenceSubscribed = false

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.webSocketTask(with: request)
        socketTask = task
        isSocketOpened = true
        isConnected = false
        task.resume()

        startReceiving()
        sendConnectFrame(token: token)

        #if DEBUG
        print(reconnectAttempt == 0 ? "🔌 WebSocket connecting" : "🔄 WebSocket reconnecting")
        print("🌐", socketURLString)
        #endif
    }

    private func resetConnectionState() {
        isSocketOpened = false
        isConnected = false
        isReconnecting = false
        activeMessageSubscriptions.removeAll()
        activeTypingSubscriptions.removeAll()
        isPresenceSubscribed = false
    }

    // MARK: - Chat listeners

    @discardableResult
    func addListener(
        chatID: String,
        handler: @escaping (ServerMessageDTO) -> Void
    ) -> UUID {
        let id = UUID()
        var handlers = messageListeners[chatID] ?? [:]
        handlers[id] = handler
        messageListeners[chatID] = handlers
        desiredMessageSubscriptions.insert(chatID)

        if isConnected {
            subscribeMessages(chatID: chatID)
        }
        return id
    }

    func removeListener(chatID: String, listenerID: UUID) {
        messageListeners[chatID]?[listenerID] = nil
        guard messageListeners[chatID]?.isEmpty == true else { return }

        messageListeners[chatID] = nil
        desiredMessageSubscriptions.remove(chatID)
        unsubscribeMessages(chatID: chatID)
    }

    // MARK: - Typing listeners

    @discardableResult
    func addTypingListener(
        chatID: String,
        handler: @escaping (TypingEventDTO) -> Void
    ) -> UUID {
        let id = UUID()
        var handlers = typingListeners[chatID] ?? [:]
        handlers[id] = handler
        typingListeners[chatID] = handlers
        desiredTypingSubscriptions.insert(chatID)

        if isConnected {
            subscribeTyping(chatID: chatID)
        }
        return id
    }

    func removeTypingListener(chatID: String, listenerID: UUID) {
        typingListeners[chatID]?[listenerID] = nil
        guard typingListeners[chatID]?.isEmpty == true else { return }

        typingListeners[chatID] = nil
        desiredTypingSubscriptions.remove(chatID)
        unsubscribeTyping(chatID: chatID)
    }

    func sendTyping(chatID: String, typing: Bool) {
        guard isConnected else { return }
        guard let token, !token.isEmpty else { return }

        let payload = TypingSendDTO(chatId: chatID, typing: typing)
        guard let data = try? JSONEncoder().encode(payload),
              let body = String(data: data, encoding: .utf8) else {
            return
        }

        sendRaw(
            makeFrame(
                command: "SEND",
                headers: [
                    "destination": "/app/typing",
                    "content-type": "application/json",
                    "Authorization": "Bearer \(token)"
                ],
                body: body
            ),
            label: "TYPING \(typing)"
        )
    }

    // MARK: - STOMP connect / subscriptions

    private func sendConnectFrame(token: String) {
        sendRaw(
            makeFrame(
                command: "CONNECT",
                headers: [
                    "accept-version": "1.2",
                    "host": GRUServerConfiguration.host,
                    "heart-beat": "0,0",
                    "Authorization": "Bearer \(token)"
                ]
            ),
            label: "CONNECT"
        )
    }

    private func subscribeToDesiredTopics() {
        if wantsPresenceSubscription {
            subscribePresence()
        }

        for chatID in desiredMessageSubscriptions {
            subscribeMessages(chatID: chatID)
        }

        for chatID in desiredTypingSubscriptions {
            subscribeTyping(chatID: chatID)
        }
    }

    private func subscribePresence() {
        guard isConnected, !isPresenceSubscribed else { return }
        guard let token, !token.isEmpty else { return }

        let destination = "/user/queue/presence"
        let frame = makeFrame(
            command: "SUBSCRIBE",
            headers: [
                "id": "presence-private",
                "destination": destination,
                "ack": "auto",
                "Authorization": "Bearer \(token)"
            ]
        )

        isPresenceSubscribed = true
        sendRaw(frame, label: "SUBSCRIBE \(destination)")

        #if DEBUG
        print("🟢 PRIVATE PRESENCE SUBSCRIBE:", destination)
        #endif
    }

    private func subscribeMessages(chatID: String) {
        guard isConnected,
              !activeMessageSubscriptions.contains(chatID),
              let token,
              !token.isEmpty else {
            return
        }

        let destination = "/topic/chat/\(chatID)"
        let frame = makeFrame(
            command: "SUBSCRIBE",
            headers: [
                "id": "message-\(chatID)",
                "destination": destination,
                "ack": "auto",
                "Authorization": "Bearer \(token)"
            ]
        )

        activeMessageSubscriptions.insert(chatID)
        sendRaw(frame, label: "SUBSCRIBE \(destination)")
    }

    private func subscribeTyping(chatID: String) {
        guard isConnected,
              !activeTypingSubscriptions.contains(chatID),
              let token,
              !token.isEmpty else {
            return
        }

        let destination = "/topic/chat/\(chatID)/typing"
        let frame = makeFrame(
            command: "SUBSCRIBE",
            headers: [
                "id": "typing-\(chatID)",
                "destination": destination,
                "ack": "auto",
                "Authorization": "Bearer \(token)"
            ]
        )

        activeTypingSubscriptions.insert(chatID)
        sendRaw(frame, label: "SUBSCRIBE \(destination)")
    }

    private func unsubscribeMessages(chatID: String) {
        guard activeMessageSubscriptions.contains(chatID) else { return }
        activeMessageSubscriptions.remove(chatID)
        sendRaw(
            makeFrame(
                command: "UNSUBSCRIBE",
                headers: ["id": "message-\(chatID)"]
            ),
            label: "UNSUBSCRIBE message \(chatID)"
        )
    }

    private func unsubscribeTyping(chatID: String) {
        guard activeTypingSubscriptions.contains(chatID) else { return }
        activeTypingSubscriptions.remove(chatID)
        sendRaw(
            makeFrame(
                command: "UNSUBSCRIBE",
                headers: ["id": "typing-\(chatID)"]
            ),
            label: "UNSUBSCRIBE typing \(chatID)"
        )
    }

    // MARK: - Receive loop

    private func startReceiving() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                guard let socket = self.socketTask else { return }

                do {
                    let message = try await socket.receive()
                    switch message {
                    case .string(let text):
                        self.processIncoming(text)
                    case .data(let data):
                        guard let text = String(data: data, encoding: .utf8) else { continue }
                        self.processIncoming(text)
                    @unknown default:
                        break
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    self.handleSocketFailure(error)
                    return
                }
            }
        }
    }

    private func processIncoming(_ rawPayload: String) {
        if rawPayload == "\n" || rawPayload == "\r\n" {
            return
        }

        for rawFrame in rawPayload.components(separatedBy: "\u{0000}") {
            let frame = rawFrame.trimmingCharacters(in: .newlines)
            guard !frame.isEmpty else { continue }
            processSTOMPFrame(frame)
        }
    }

    private func processSTOMPFrame(_ frame: String) {
        let normalized = frame.replacingOccurrences(of: "\r\n", with: "\n")
        let command = normalized
            .components(separatedBy: "\n")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        switch command {
        case "CONNECTED":
            handleConnected()
        case "MESSAGE":
            handleMessageFrame(normalized)
        case "ERROR":
            handleSTOMPError(normalized)
        case "RECEIPT":
            break
        default:
            #if DEBUG
            if !command.isEmpty {
                print("⚠️ Unknown STOMP frame:", command)
            }
            #endif
        }
    }

    private func handleConnected() {
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempt = 0
        isReconnecting = false
        isConnected = true
        isSocketOpened = true
        lastError = nil
        activeMessageSubscriptions.removeAll()
        activeTypingSubscriptions.removeAll()
        isPresenceSubscribed = false

        subscribeToDesiredTopics()

        // REST gives the initial authorized snapshot; the private STOMP queue
        // carries only subsequent changes from users the backend says we may see.
        Task {
            await ChatService.shared.loadPresence()
        }
    }

    // MARK: - MESSAGE dispatch

    private func handleMessageFrame(_ frame: String) {
        let parsed = parseSTOMPFrame(frame)
        guard let destination = parsed.headers["destination"] else { return }

        if destination == "/user/queue/presence"
            || destination.hasSuffix("/queue/presence") {
            handlePresenceMessage(
                destination: destination,
                body: parsed.body
            )
            return
        }

        if destination.hasSuffix("/typing") {
            handleTypingMessage(
                destination: destination,
                body: parsed.body
            )
            return
        }

        handleChatMessage(
            destination: destination,
            body: parsed.body
        )
    }

    private func handlePresenceMessage(destination: String, body: String) {
        guard let data = body.data(using: .utf8) else { return }

        do {
            let event = try JSONCoding.decoder.decode(
                PresenceEventDTO.self,
                from: data
            )
            ChatService.shared.applyPresenceEvent(event)

            #if DEBUG
            print("🟢 PRIVATE PRESENCE:", event.userId, event.online)
            #endif
        } catch {
            #if DEBUG
            print("❌ Presence decode error:", error.localizedDescription)
            #endif
        }
    }

    private func handleChatMessage(destination: String, body: String) {
        guard let data = body.data(using: .utf8) else { return }

        do {
            let message = try JSONCoding.decoder.decode(
                ServerMessageDTO.self,
                from: data
            )
            dispatchChatMessage(message, destination: destination)
        } catch {
            #if DEBUG
            print("❌ WebSocket message decode error:", error.localizedDescription)
            #endif
        }
    }

    private func dispatchChatMessage(
        _ message: ServerMessageDTO,
        destination: String
    ) {
        guard message.e2eeEnvelope != nil || message.e2eeEnvelopeV2 != nil else {
            deliverChatMessage(message)
            return
        }

        guard let token,
              !token.isEmpty,
              let currentUserID = TokenStorage.shared.userID,
              !currentUserID.isEmpty else {
            deliverChatMessage(
                message.replacingText("🔒 Не удалось расшифровать сообщение")
            )
            return
        }

        Task { [weak self] in
            guard let self else { return }

            do {
                let plaintext = try await E2EEAPIService.shared.decrypt(
                    message: message,
                    currentUserID: currentUserID,
                    token: token
                )

                let resolved: ServerMessageDTO
                if GRUE2EEMediaKeyStore.isMediaKeyPayload(plaintext) {
                    if let remoteURL = message.attachment?.remoteURL,
                       !remoteURL.isEmpty {
                        GRUE2EEMediaKeyStore.shared.register(
                            keyPayload: plaintext,
                            remoteURL: remoteURL
                        )
                    }
                    resolved = message.replacingText("")
                } else {
                    resolved = message.replacingText(plaintext)
                }

                self.deliverChatMessage(resolved)
            } catch E2EEAPIError.replayedEnvelope {
                // Reconnect/broker redelivery of an already accepted exact pair.
                return
            } catch {
                #if DEBUG
                print(
                    "❌ E2EE realtime decrypt failed:",
                    message.id,
                    error.localizedDescription
                )
                #endif
                self.deliverChatMessage(
                    message.replacingText("🔒 Не удалось расшифровать сообщение")
                )
            }
        }
    }

    private func deliverChatMessage(_ message: ServerMessageDTO) {
        guard let registeredHandlers = messageListeners[message.chatId] else {
            return
        }

        for handler in Array(registeredHandlers.values) {
            handler(message)
        }
    }

    private func handleTypingMessage(destination: String, body: String) {
        guard let data = body.data(using: .utf8) else { return }

        do {
            let event = try JSONCoding.decoder.decode(
                TypingEventDTO.self,
                from: data
            )
            guard let registeredHandlers = typingListeners[event.chatId] else {
                return
            }
            for handler in Array(registeredHandlers.values) {
                handler(event)
            }
        } catch {
            #if DEBUG
            print("❌ Typing decode error:", error.localizedDescription)
            #endif
        }
    }

    // MARK: - Failures / reconnect

    private func handleSocketFailure(_ error: Error) {
        guard socketTask != nil || isConnected || isSocketOpened else { return }

        lastError = error.localizedDescription
        receiveTask?.cancel()
        receiveTask = nil
        socketTask?.cancel()
        socketTask = nil
        resetConnectionState()
        scheduleReconnect()
    }

    private func handleSTOMPError(_ frame: String) {
        #if DEBUG
        print("❌ STOMP ERROR")
        print(sanitize(frame))
        #endif

        lastError = sanitize(frame)
        receiveTask?.cancel()
        receiveTask = nil
        socketTask?.cancel()
        socketTask = nil
        resetConnectionState()
        validateSessionBeforeReconnect()
    }

    private func validateSessionBeforeReconnect() {
        guard shouldReconnect,
              let token,
              !token.isEmpty else {
            return
        }

        let tokenBeingValidated = token

        Task { [weak self] in
            guard let self else { return }

            do {
                _ = try await ChatAPIService.shared.getChats(
                    token: tokenBeingValidated
                )

                guard self.shouldReconnect,
                      self.token == tokenBeingValidated else {
                    return
                }
                self.scheduleReconnect()
            } catch {
                guard self.shouldReconnect,
                      self.token == tokenBeingValidated,
                      TokenStorage.shared.token != nil else {
                    return
                }
                self.scheduleReconnect()
            }
        }
    }

    private func scheduleReconnect() {
        guard shouldReconnect,
              let token,
              !token.isEmpty,
              reconnectTask == nil else {
            return
        }

        reconnectAttempt += 1
        let delay: UInt64
        switch reconnectAttempt {
        case 1: delay = 1
        case 2: delay = 2
        case 3: delay = 4
        default: delay = 8
        }

        isReconnecting = true

        reconnectTask = Task { [weak self] in
            do {
                try await Task.sleep(
                    nanoseconds: delay * 1_000_000_000
                )
            } catch {
                return
            }

            guard let self else { return }
            self.reconnectTask = nil

            guard self.shouldReconnect,
                  self.socketTask == nil,
                  self.token == token else {
                return
            }

            self.openSocket(token: token)
        }
    }

    // MARK: - Frame IO

    private func sendRaw(_ frame: String, label: String) {
        guard let socket = socketTask else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await socket.send(.string(frame))
                #if DEBUG
                print("✅ STOMP \(label) sent")
                #endif
            } catch {
                self.handleSocketFailure(error)
            }
        }
    }

    private func makeFrame(
        command: String,
        headers: [String: String] = [:],
        body: String? = nil
    ) -> String {
        var frame = command + "\n"
        for key in headers.keys.sorted() {
            guard let value = headers[key] else { continue }
            frame += "\(key):\(value)\n"
        }
        frame += "\n"
        if let body {
            frame += body
        }
        frame += "\u{0000}"
        return frame
    }

    private func parseSTOMPFrame(
        _ frame: String
    ) -> (command: String, headers: [String: String], body: String) {
        let normalized = frame.replacingOccurrences(of: "\r\n", with: "\n")
        guard let separator = normalized.range(of: "\n\n") else {
            return (normalized, [:], "")
        }

        let headerPart = String(normalized[..<separator.lowerBound])
        let body = String(normalized[separator.upperBound...])
        var lines = headerPart.components(separatedBy: "\n")
        let command = lines.isEmpty ? "" : lines.removeFirst()
        var headers: [String: String] = [:]

        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon])
            let valueStart = line.index(after: colon)
            headers[key] = String(line[valueStart...])
        }

        return (command, headers, body)
    }

    private func sanitize(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{0000}", with: "")
    }

    private func fail(_ message: String) {
        lastError = message
        isConnected = false
        isSocketOpened = false

        #if DEBUG
        print("❌ WebSocket:", message)
        #endif
    }
}

private struct TypingSendDTO: Codable {
    let chatId: String
    let typing: Bool
}
