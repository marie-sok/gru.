import Foundation

/// Detects a server attempting to replay a valid signed E2EE envelope under a
/// different server message id. The signed client id is immutable because it is
/// part of the Ed25519-authenticated envelope.
final class GRUE2EEReplayGuard {

    static let shared = GRUE2EEReplayGuard()

    private struct State: Codable {
        var entries: [String: Entry]
    }

    private struct Entry: Codable {
        let serverMessageID: String
        let firstSeenAt: Date
    }

    private let queue = DispatchQueue(label: "sok.com.gru.e2ee.replay-guard")
    private let maxEntries = 5_000
    private let fileName = "gru-e2ee-replay-guard-v1.bin"

    private var state: State

    private init() {
        state = Self.loadState(fileName: fileName) ?? State(entries: [:])
    }

    /// Returns true for the original message and subsequent reads of that exact
    /// server/client-id pair. Returns false if the same signed client id is
    /// presented under a different server message id.
    func accept(clientMessageID: String, serverMessageID: String) -> Bool {
        queue.sync {
            if let existing = state.entries[clientMessageID] {
                return existing.serverMessageID == serverMessageID
            }

            state.entries[clientMessageID] = Entry(
                serverMessageID: serverMessageID,
                firstSeenAt: Date()
            )
            pruneIfNeeded()
            persist()
            return true
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
            .sorted { $0.value.firstSeenAt < $1.value.firstSeenAt }
            .prefix(overflow)
        for item in oldest {
            state.entries.removeValue(forKey: item.key)
        }
    }

    private func persist() {
        do {
            let plaintext = try JSONEncoder().encode(state)
            let encrypted = try GRUDataProtection.shared.seal(plaintext)
            let url = Self.fileURL(fileName: fileName)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try encrypted.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            #if DEBUG
            print("⚠️ E2EE replay guard persist failed:", error.localizedDescription)
            #endif
        }
    }

    private static func loadState(fileName: String) -> State? {
        let url = fileURL(fileName: fileName)
        guard let stored = try? Data(contentsOf: url),
              let plaintext = try? GRUDataProtection.shared.open(stored),
              let decoded = try? JSONDecoder().decode(State.self, from: plaintext)
        else {
            return nil
        }
        return decoded
    }

    private static func fileURL(fileName: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("gru-security", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
