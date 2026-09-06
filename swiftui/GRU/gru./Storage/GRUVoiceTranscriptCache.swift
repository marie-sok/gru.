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

    private init() {}

    func load(
        fingerprint: String
    ) -> GRUVoiceTranscript? {
        let url = fileURL(fingerprint: fingerprint)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(
                GRUVoiceTranscript.self,
                from: data
            )
        } catch {
            return nil
        }
    }

    func save(
        _ transcript: GRUVoiceTranscript,
        fingerprint: String
    ) {
        let url = fileURL(fingerprint: fingerprint)

        queue.async { [encoder] in
            do {
                let data = try encoder.encode(transcript)
                try data.write(to: url, options: .atomic)
            } catch {
                print(
                    "⚠️ Voice transcript cache save:",
                    error.localizedDescription
                )
            }
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
        let base = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]

        let directory = base.appendingPathComponent(
            "gru-voice-transcripts-v1",
            isDirectory: true
        )

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory.appendingPathComponent(
            fingerprint + ".json"
        )
    }
}
