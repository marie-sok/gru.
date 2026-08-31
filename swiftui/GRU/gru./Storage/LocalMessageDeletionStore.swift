import Foundation

final class LocalMessageDeletionStore {

    static let shared = LocalMessageDeletionStore()

    private let defaults = UserDefaults.standard

    private init() {}

    func hide(
        _ serverMessageID: String
    ) {
        guard !serverMessageID.isEmpty else {
            return
        }

        var hiddenIDs = loadHiddenIDs()
        hiddenIDs.insert(serverMessageID)
        saveHiddenIDs(hiddenIDs)
    }

    func isHidden(
        _ serverMessageID: String
    ) -> Bool {
        guard !serverMessageID.isEmpty else {
            return false
        }

        return loadHiddenIDs().contains(serverMessageID)
    }

    func unhide(
        _ serverMessageID: String
    ) {
        guard !serverMessageID.isEmpty else {
            return
        }

        var hiddenIDs = loadHiddenIDs()
        hiddenIDs.remove(serverMessageID)
        saveHiddenIDs(hiddenIDs)
    }

    func clearCurrentUser() {
        defaults.removeObject(
            forKey: storageKey(
                userID: TokenStorage.shared.userID
            )
        )
    }
}

private extension LocalMessageDeletionStore {

    func loadHiddenIDs() -> Set<String> {
        guard
            let data = defaults.data(
                forKey: storageKey(
                    userID: TokenStorage.shared.userID
                )
            )
        else {
            return []
        }

        do {
            let values = try JSONDecoder().decode(
                Set<String>.self,
                from: data
            )
            return values
        } catch {
            print(
                "❌ Local message deletion load:",
                error.localizedDescription
            )
            return []
        }
    }

    func saveHiddenIDs(
        _ hiddenIDs: Set<String>
    ) {
        do {
            let data = try JSONEncoder().encode(hiddenIDs)
            defaults.set(
                data,
                forKey: storageKey(
                    userID: TokenStorage.shared.userID
                )
            )
        } catch {
            print(
                "❌ Local message deletion save:",
                error.localizedDescription
            )
        }
    }

    func storageKey(
        userID: String?
    ) -> String {
        let cacheID = userID?
            .filter {
                $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_"
            }

        let suffix: String
        if let cacheID, !cacheID.isEmpty {
            suffix = cacheID
        } else {
            suffix = "anonymous"
        }

        return "gru.messageDeletion.v1.\(suffix)"
    }
}
