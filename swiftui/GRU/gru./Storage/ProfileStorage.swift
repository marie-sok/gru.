import Combine
import Foundation

@MainActor
final class ProfileStorage: ObservableObject {
    static let shared = ProfileStorage()

    private enum Keys {
        static let nickname = "gru.profile.nickname.v5"
        static let username = "gru.profile.username"
        static let bio = "gru.profile.bio"
        static let avatarData = "gru.profile.avatarData"
        static let removedLegacyMedia = "gru.profile.legacyMedia.removed.v5"
        static let legacySavedMedia = "gru.profile.legacySavedMedia.v2"
    }

    @Published var nickname: String {
        didSet {
            if nickname.count > 40 {
                nickname = String(nickname.prefix(40))
                return
            }

            UserDefaults.standard.set(
                nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: Keys.nickname
            )
        }
    }

    @Published var username: String {
        didSet {
            let clean = username
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "@", with: "")

            let normalized = clean.isEmpty ? "gru.user" : clean

            if username != normalized {
                username = normalized
                return
            }

            UserDefaults.standard.set(normalized, forKey: Keys.username)
        }
    }

    @Published var bio: String {
        didSet {
            if bio.count > 160 {
                bio = String(bio.prefix(160))
                return
            }

            UserDefaults.standard.set(bio, forKey: Keys.bio)
        }
    }

    @Published var avatarData: Data? {
        didSet {
            UserDefaults.standard.set(avatarData, forKey: Keys.avatarData)
        }
    }

    private init() {
        let defaults = UserDefaults.standard

        username = defaults.string(forKey: Keys.username) ?? "gru.user"
        nickname = defaults.string(forKey: Keys.nickname) ?? ""
        bio = defaults.string(forKey: Keys.bio) ?? ""
        avatarData = defaults.data(forKey: Keys.avatarData)

        removeLegacyMediaIfNeeded(defaults: defaults)
    }

    func applyFallbackNickname(_ value: String) {
        guard nickname
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        else {
            return
        }

        nickname = value
    }

    func removeAvatar() {
        avatarData = nil
    }

    private func removeLegacyMediaIfNeeded(defaults: UserDefaults) {
        guard !defaults.bool(forKey: Keys.removedLegacyMedia) else {
            return
        }

        defaults.removeObject(forKey: Keys.legacySavedMedia)

        if let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            let legacyDirectory = base
                .appendingPathComponent("GRU", isDirectory: true)
                .appendingPathComponent("SavedVideoNotes", isDirectory: true)

            try? FileManager.default.removeItem(at: legacyDirectory)
        }

        defaults.set(true, forKey: Keys.removedLegacyMedia)
    }
}
