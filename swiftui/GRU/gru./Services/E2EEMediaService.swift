import CryptoKit
import Foundation

final class E2EEMediaService {

    static let shared = E2EEMediaService()
    static let mediaKeyPrefix = "gru-media-key-v1:"

    private static let maximumMediaBytes = 96 * 1024 * 1024
    private static let maximumMediaMegabytes = 96

    private init() {}

    func send(
        chatID: String,
        data: Data,
        type: AttachmentType,
        fileName: String,
        mimeType: String,
        width: Double? = nil,
        height: Double? = nil,
        duration: Double? = nil,
        waveform: [Double]? = nil,
        replyToMessageID: String? = nil,
        token: String
    ) async throws -> ServerMessageDTO {
        guard !data.isEmpty else {
            throw E2EEMediaError.emptyMedia
        }
        guard data.count <= Self.maximumMediaBytes else {
            throw E2EEMediaError.mediaTooLarge(
                maximumMegabytes: Self.maximumMediaMegabytes
            )
        }
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
        let receiverID = receivers[0]

        _ = try await E2EEAPIService.shared.publishIdentity(token: token)
        let recipient = try await E2EEAPIService.shared.identity(
            for: receiverID,
            token: token
        )

        switch GRUE2EE.shared.trustState(for: receiverID, identity: recipient.identity) {
        case .keyChanged:
            throw E2EEAPIError.recipientKeyChanged
        case .firstSeen:
            try GRUE2EE.shared.trust(identity: recipient.identity, for: receiverID)
        case .trusted:
            break
        }

        let mediaKey = SymmetricKey(size: .bits256)
        let encryptedFile = try ChaChaPoly.seal(data, using: mediaKey).combined
        let rawKey = mediaKey.withUnsafeBytes { Data($0) }
        let keyPayload = Self.mediaKeyPrefix + rawKey.base64EncodedString()
        let clientMessageID = UUID().uuidString.lowercased()

        let envelope = try GRUE2EEV2.shared.encrypt(
            plaintext: keyPayload,
            chatID: chatID,
            senderID: senderID,
            receiverID: receiverID,
            receiverIdentity: recipient.identity,
            clientMessageID: clientMessageID
        )

        try GRUE2EESentMessageStore.shared.save(
            plaintext: keyPayload,
            userID: senderID,
            clientMessageID: envelope.clientMessageId
        )

        var fields: [String: String] = [
            "chatId": chatID,
            "type": type.rawValue,
            "fileName": fileName,
            "mimeType": mimeType,
            "clientMessageId": envelope.clientMessageId,
            "encryptedPayload": envelope.encryptedPayload,
            "encryptionVersion": envelope.version,
            "senderEphemeralPublicKey": envelope.senderEphemeralPublicKey,
            "senderRecoveryEncryptedPayload": envelope.senderRecoveryEncryptedPayload,
            "senderRecoveryEphemeralPublicKey": envelope.senderRecoveryEphemeralPublicKey,
            "signature": envelope.signature,
            "senderKeyFingerprint": envelope.senderKeyFingerprint
        ]

        if let width, width > 0 { fields["width"] = String(width) }
        if let height, height > 0 { fields["height"] = String(height) }
        if let duration, duration > 0 { fields["duration"] = String(duration) }
        if let waveform, !waveform.isEmpty {
            fields["waveform"] = waveform
                .prefix(64)
                .map { String(format: "%.4f", max(0.04, min(1.0, $0))) }
                .joined(separator: ",")
        }
        if let replyToMessageID, !replyToMessageID.isEmpty {
            fields["replyToMessageId"] = replyToMessageID
        }

        let responseData = try await APIClient.shared.uploadMultipart(
            path: "/messages/media-e2ee",
            token: token,
            fields: fields,
            fileFieldName: "file",
            fileName: UUID().uuidString.lowercased() + ".bin",
            mimeType: "application/octet-stream",
            fileData: encryptedFile
        )

        return try JSONCoding.decoder.decode(ServerMessageDTO.self, from: responseData)
    }
}

enum E2EEMediaError: LocalizedError {
    case emptyMedia
    case mediaTooLarge(maximumMegabytes: Int)
    case missingMediaKey
    case invalidMediaKey

    var errorDescription: String? {
        switch self {
        case .emptyMedia:
            return "Медиафайл пуст."
        case .mediaTooLarge(let maximumMegabytes):
            return "Вложение слишком большое. Максимальный размер — \(maximumMegabytes) МБ."
        case .missingMediaKey:
            return "Ключ защищённого медиа недоступен."
        case .invalidMediaKey:
            return "Ключ защищённого медиа повреждён."
        }
    }
}

final class GRUE2EEMediaKeyStore {

    static let shared = GRUE2EEMediaKeyStore()
    private static let maximumRegisteredKeys = 512

    private let lock = NSLock()
    private var keysByPath: [String: Data] = [:]
    private var registrationOrder: [String] = []

    private init() {}

    func register(keyPayload: String, remoteURL: String) {
        guard let key = Self.keyData(from: keyPayload) else { return }
        let path = Self.normalizedPath(remoteURL)
        guard !path.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }

        keysByPath[path] = key

        if let existingIndex = registrationOrder.firstIndex(of: path) {
            registrationOrder.remove(at: existingIndex)
        }
        registrationOrder.append(path)

        while registrationOrder.count > Self.maximumRegisteredKeys {
            let evictedPath = registrationOrder.removeFirst()
            keysByPath.removeValue(forKey: evictedPath)
        }
    }

    func clear() {
        lock.lock()
        keysByPath.removeAll(keepingCapacity: false)
        registrationOrder.removeAll(keepingCapacity: false)
        lock.unlock()
    }

    func decryptIfRegistered(_ data: Data, path: String) throws -> Data {
        let normalized = Self.normalizedPath(path)

        lock.lock()
        let keyData = keysByPath[normalized]
        lock.unlock()

        guard let keyData else {
            return data
        }
        guard keyData.count == 32 else {
            throw E2EEMediaError.invalidMediaKey
        }

        let key = SymmetricKey(data: keyData)
        let box = try ChaChaPoly.SealedBox(combined: data)
        return try ChaChaPoly.open(box, using: key)
    }

    static func isMediaKeyPayload(_ value: String) -> Bool {
        value.hasPrefix(E2EEMediaService.mediaKeyPrefix)
    }

    private static func keyData(from payload: String) -> Data? {
        guard payload.hasPrefix(E2EEMediaService.mediaKeyPrefix) else {
            return nil
        }
        let encoded = String(payload.dropFirst(E2EEMediaService.mediaKeyPrefix.count))
        guard let data = Data(base64Encoded: encoded), data.count == 32 else {
            return nil
        }
        return data
    }

    private static func normalizedPath(_ value: String) -> String {
        if let url = URL(string: value), let path = url.path.removingPercentEncoding {
            return path
        }
        let raw = value.split(separator: "?", maxSplits: 1).first.map(String.init) ?? value
        return raw.hasPrefix("/") ? raw : "/" + raw
    }
}
