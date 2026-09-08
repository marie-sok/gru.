import Foundation

struct E2EEKeyDTO: Codable {
    let userId: String
    let keyAgreementPublicKey: String
    let signingPublicKey: String
    let updatedAt: Date?

    var identity: GRUE2EEPublicIdentity {
        GRUE2EEPublicIdentity(
            keyAgreementPublicKey: keyAgreementPublicKey,
            signingPublicKey: signingPublicKey
        )
    }
}

final class E2EEAPIService {

    static let shared = E2EEAPIService()

    private init() {}

    func publishIdentity(token: String) async throws -> E2EEKeyDTO {
        let identity = try GRUE2EE.shared.publicIdentity()
        struct Request: Codable {
            let keyAgreementPublicKey: String
            let signingPublicKey: String
        }

        let body = try JSONCoding.encoder.encode(
            Request(
                keyAgreementPublicKey: identity.keyAgreementPublicKey,
                signingPublicKey: identity.signingPublicKey
            )
        )

        let data = try await APIClient.shared.request(
            path: "/e2ee/keys/me",
            method: "PUT",
            token: token,
            body: body
        )
        return try JSONCoding.decoder.decode(E2EEKeyDTO.self, from: data)
    }

    func identity(for userID: String, token: String) async throws -> E2EEKeyDTO {
        let data = try await APIClient.shared.request(
            path: "/e2ee/keys/\(userID)",
            method: "GET",
            token: token
        )
        return try JSONCoding.decoder.decode(E2EEKeyDTO.self, from: data)
    }

    /// Default production path for a direct-chat text message.
    /// Sender/receiver ids are resolved from the authenticated session and
    /// server chat membership so old callers cannot accidentally bypass E2EE.
    func sendEncryptedText(
        chatID: String,
        plaintext: String,
        replyToMessageID: String? = nil,
        clientMessageID: String = UUID().uuidString.lowercased(),
        token: String
    ) async throws -> ServerMessageDTO {
        guard let senderID = TokenStorage.shared.userID,
              !senderID.isEmpty else {
            throw E2EEAPIError.missingCurrentUser
        }

        let chatsData = try await APIClient.shared.request(
            path: "/chats",
            method: "GET",
            token: token
        )
        let chats = try JSONCoding.decoder.decode([ServerChatDTO].self, from: chatsData)
        guard let chat = chats.first(where: { $0.id == chatID }) else {
            throw E2EEAPIError.chatNotFound
        }

        let receivers = chat.participants
            .map(\.id)
            .filter { !$0.isEmpty && $0 != senderID }
        guard receivers.count == 1 else {
            throw E2EEAPIError.directChatRequired
        }

        return try await sendEncryptedText(
            chatID: chatID,
            senderID: senderID,
            receiverID: receivers[0],
            plaintext: plaintext,
            replyToMessageID: replyToMessageID,
            clientMessageID: clientMessageID,
            token: token
        )
    }

    func sendEncryptedText(
        chatID: String,
        senderID: String,
        receiverID: String,
        plaintext: String,
        replyToMessageID: String? = nil,
        clientMessageID: String = UUID().uuidString.lowercased(),
        token: String
    ) async throws -> ServerMessageDTO {
        // Make sure this installation's public identity exists server-side.
        // Publishing identical keys is idempotent; a conflicting identity is
        // intentionally fail-closed and requires the signed rotation flow.
        _ = try await publishIdentity(token: token)

        let recipient = try await identity(for: receiverID, token: token)

        switch GRUE2EE.shared.trustState(for: receiverID, identity: recipient.identity) {
        case .keyChanged:
            throw E2EEAPIError.recipientKeyChanged
        case .firstSeen:
            // Trust On First Use: pin the first successfully fetched identity.
            // Any later substitution is blocked until explicitly re-verified.
            try GRUE2EE.shared.trust(identity: recipient.identity, for: receiverID)
        case .trusted:
            break
        }

        let envelope = try GRUE2EE.shared.encrypt(
            plaintext: plaintext,
            chatID: chatID,
            senderID: senderID,
            receiverID: receiverID,
            receiverIdentity: recipient.identity,
            clientMessageID: clientMessageID
        )

        // Persist our own readable copy before the request. The server receives
        // only ciphertext; this protected local copy lets the sender reconstruct
        // its own bubbles after a relaunch on this device.
        try GRUE2EESentMessageStore.shared.save(
            plaintext: plaintext,
            clientMessageID: envelope.clientMessageId
        )

        struct Request: Codable {
            let chatId: String
            let clientMessageId: String
            let encryptedPayload: String
            let encryptionVersion: String
            let senderEphemeralPublicKey: String
            let signature: String
            let senderKeyFingerprint: String
            let replyToMessageId: String?
        }

        let body = try JSONCoding.encoder.encode(
            Request(
                chatId: chatID,
                clientMessageId: envelope.clientMessageId,
                encryptedPayload: envelope.encryptedPayload,
                encryptionVersion: envelope.version,
                senderEphemeralPublicKey: envelope.senderEphemeralPublicKey,
                signature: envelope.signature,
                senderKeyFingerprint: envelope.senderKeyFingerprint,
                replyToMessageId: replyToMessageID
            )
        )

        let data = try await APIClient.shared.request(
            path: "/messages/e2ee",
            method: "POST",
            token: token,
            body: body
        )
        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: data)
    }

    func decrypt(
        message: ServerMessageDTO,
        currentUserID: String,
        token: String
    ) async throws -> String {
        guard let envelope = message.e2eeEnvelope else {
            return message.text
        }

        if message.senderId == currentUserID,
           let own = GRUE2EESentMessageStore.shared.plaintext(
                for: envelope.clientMessageId
           ) {
            return own
        }

        let sender = try await identity(for: message.senderId, token: token)
        let trustState = GRUE2EE.shared.trustState(for: message.senderId, identity: sender.identity)
        if case .keyChanged = trustState {
            throw E2EEAPIError.senderKeyChanged
        }

        let plaintext = try GRUE2EE.shared.decrypt(
            envelope: envelope,
            chatID: message.chatId,
            senderID: message.senderId,
            receiverID: currentUserID,
            senderIdentity: sender.identity
        )

        if case .firstSeen = trustState {
            try GRUE2EE.shared.trust(identity: sender.identity, for: message.senderId)
        }

        guard GRUE2EEReplayGuard.shared.accept(
            clientMessageID: envelope.clientMessageId,
            serverMessageID: message.id
        ) else {
            throw E2EEAPIError.replayedEnvelope
        }

        return plaintext
    }
}

enum E2EEAPIError: LocalizedError {
    case recipientKeyChanged
    case senderKeyChanged
    case replayedEnvelope
    case senderCopyUnavailable
    case missingCurrentUser
    case chatNotFound
    case directChatRequired

    var errorDescription: String? {
        switch self {
        case .recipientKeyChanged:
            return "Ключ собеседника изменился. Отправка заблокирована до повторной проверки."
        case .senderKeyChanged:
            return "Ключ отправителя изменился. Сообщение не расшифровано."
        case .replayedEnvelope:
            return "Обнаружен повтор защищённого сообщения."
        case .senderCopyUnavailable:
            return "Локальная копия отправленного защищённого сообщения недоступна."
        case .missingCurrentUser:
            return "Не найден ID текущего пользователя."
        case .chatNotFound:
            return "Чат не найден на сервере."
        case .directChatRequired:
            return "E2EE v1 поддерживает только личные чаты."
        }
    }
}

/// Protected sender-side plaintext cache. This never leaves the device and is
/// encrypted with the app's Keychain-backed data-protection key before writing.
final class GRUE2EESentMessageStore {

    static let shared = GRUE2EESentMessageStore()

    private struct State: Codable {
        var entries: [String: Entry]
    }

    private struct Entry: Codable {
        let plaintext: String
        let createdAt: Date
    }

    private let queue = DispatchQueue(label: "sok.com.gru.e2ee.sent-copy")
    private let fileName = "gru-e2ee-sent-copy-v1.bin"
    private let maxEntries = 5_000
    private var state: State

    private init() {
        state = Self.loadState(fileName: fileName) ?? State(entries: [:])
    }

    func save(plaintext: String, clientMessageID: String) throws {
        try queue.sync {
            state.entries[clientMessageID] = Entry(
                plaintext: plaintext,
                createdAt: Date()
            )
            pruneIfNeeded()
            try persist()
        }
    }

    func plaintext(for clientMessageID: String) -> String? {
        queue.sync {
            state.entries[clientMessageID]?.plaintext
        }
    }

    func clear() {
        queue.sync {
            state = State(entries: [:])
            try? FileManager.default.removeItem(at: Self.fileURL(fileName: fileName))
        }
    }

    private func pruneIfNeeded() {
        guard state.entries.count > maxEntries else { return }
        let overflow = state.entries.count - maxEntries
        let oldest = state.entries
            .sorted { $0.value.createdAt < $1.value.createdAt }
            .prefix(overflow)
        for item in oldest {
            state.entries.removeValue(forKey: item.key)
        }
    }

    private func persist() throws {
        let plaintext = try JSONEncoder().encode(state)
        let encrypted = try GRUDataProtection.shared.seal(plaintext)
        let url = Self.fileURL(fileName: fileName)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encrypted.write(to: url, options: [.atomic, .completeFileProtection])
    }

    private static func loadState(fileName: String) -> State? {
        let url = fileURL(fileName: fileName)
        guard let stored = try? Data(contentsOf: url),
              let plaintext = try? GRUDataProtection.shared.open(stored),
              let state = try? JSONDecoder().decode(State.self, from: plaintext)
        else {
            return nil
        }
        return state
    }

    private static func fileURL(fileName: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("gru-security", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
