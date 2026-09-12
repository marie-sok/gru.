import CryptoKit
import Foundation

final class GRUVoiceTranscriptCache {
    static let shared = GRUVoiceTranscriptCache()

    private let queue = DispatchQueue(
        label: "sok.com.gru.voice-transcript-cache",
        qos: .utility
    )

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let protector = GRUDataProtection.shared

    private init() {}

    func load(
        fingerprint: String
    ) -> GRUVoiceTranscript? {
        let url = fileURL(fingerprint: fingerprint)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let stored = try Data(contentsOf: url)
            let data = try protector.open(stored)
            let transcript = try decoder.decode(
                GRUVoiceTranscript.self,
                from: data
            )

            if !stored.starts(with: Data("GRUENC1".utf8)) {
                save(transcript, fingerprint: fingerprint)
            }
            return transcript
        } catch {
            return nil
        }
    }

    func save(
        _ transcript: GRUVoiceTranscript,
        fingerprint: String
    ) {
        let url = fileURL(fingerprint: fingerprint)

        queue.async { [encoder, protector] in
            do {
                let data = try encoder.encode(transcript)
                let encrypted = try protector.seal(data)
                try encrypted.write(
                    to: url,
                    options: [.atomic, .completeFileProtection]
                )
            } catch {
                print(
                    "⚠️ Voice transcript protected cache save:",
                    error.localizedDescription
                )
            }
        }
    }

    func clear() {
        let directory = cacheDirectory(createIfNeeded: false)

        queue.async {
            guard FileManager.default.fileExists(atPath: directory.path) else {
                return
            }
            try? FileManager.default.removeItem(at: directory)
        }
    }

    static func fingerprint(
        remoteURL: String?,
        fileName: String,
        size: Int64,
        duration: Double?
    ) -> String {
        let identity: String

        if let remoteURL, !remoteURL.isEmpty {
            identity = "remote|\(remoteURL)"
        } else {
            identity = [
                "local",
                fileName,
                String(size),
                duration.map { String($0) } ?? ""
            ]
            .joined(separator: "|")
        }

        let digest = SHA256.hash(
            data: Data(identity.utf8)
        )

        return digest.map {
            String(format: "%02x", $0)
        }
        .joined()
    }

    private func fileURL(
        fingerprint: String
    ) -> URL {
        cacheDirectory(createIfNeeded: true)
            .appendingPathComponent(fingerprint + ".bin")
    }

    private func cacheDirectory(createIfNeeded: Bool) -> URL {
        let base = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]

        let directory = base.appendingPathComponent(
            "gru-voice-transcripts-v1",
            isDirectory: true
        )

        if createIfNeeded {
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        return directory
    }
}
