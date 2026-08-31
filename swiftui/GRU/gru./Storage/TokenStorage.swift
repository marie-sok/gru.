import Foundation

final class TokenStorage {

    static let shared = TokenStorage()

    private init() {}

    // MARK: - Keys

    private let tokenKey = "jwt"

    private let userIDKey = "serverUserID"

    // MARK: - Token

    var token: String? {

        UserDefaults.standard.string(
            forKey: tokenKey
        )
    }

    // MARK: - User ID

    var userID: String? {

        UserDefaults.standard.string(
            forKey: userIDKey
        )
    }

    // MARK: - Save Session

    func save(
        token: String,
        userID: String
    ) {

        UserDefaults.standard.set(
            token,
            forKey: tokenKey
        )

        UserDefaults.standard.set(
            userID,
            forKey: userIDKey
        )
    }

    // MARK: - Compatibility

    func save(
        _ token: String
    ) {

        UserDefaults.standard.set(
            token,
            forKey: tokenKey
        )
    }

    // MARK: - Clear

    func clear() {

        UserDefaults.standard.removeObject(
            forKey: tokenKey
        )

        UserDefaults.standard.removeObject(
            forKey: userIDKey
        )
    }
}

// MARK: - Session Events

extension Notification.Name {

    static let gruSessionInvalidated =
        Notification.Name(
            "gru.session.invalidated"
        )
}
