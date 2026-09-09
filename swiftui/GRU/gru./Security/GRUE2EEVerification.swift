import CryptoKit
import Foundation
import Security

struct GRUE2EESafetyCode: Equatable {
    let digits: String
    let grouped: String
    let qrPayload: String
}

extension GRUE2EE {
    /// Generates the same safety number on both devices by sorting the two
    /// user-id/identity pairs before hashing them together.
    func safetyCode(
        currentUserID: String,
        peerUserID: String,
        peerIdentity: GRUE2EEPublicIdentity
    ) throws -> GRUE2EESafetyCode {
        let ownIdentity = try publicIdentity()
        let ownFingerprint = ownIdentity.trustFingerprint
        let peerFingerprint = peerIdentity.trustFingerprint

        guard ownFingerprint != "invalid", peerFingerprint != "invalid" else {
            throw GRUE2EEError.invalidFingerprint
        }

        let pairs = [
            (currentUserID, ownFingerprint),
            (peerUserID, peerFingerprint)
        ].sorted { lhs, rhs in
            if lhs.0 == rhs.0 { return lhs.1 < rhs.1 }
            return lhs.0 < rhs.0
        }

        let canonical = [
            "gru-e2ee-safety-v1",
            pairs[0].0,
            pairs[0].1,
            pairs[1].0,
            pairs[1].1
        ].joined(separator: "|")

        let digest = Array(SHA256.hash(data: Data(canonical.utf8)))
        var groups: [String] = []
        groups.reserveCapacity(12)

        for index in stride(from: 0, to: 24, by: 2) {
            let value = (UInt32(digest[index]) << 8) | UInt32(digest[index + 1])
            groups.append(String(format: "%05u", value % 100_000))
        }

        return GRUE2EESafetyCode(
            digits: groups.joined(),
            grouped: groups.joined(separator: " "),
            qrPayload: canonical
        )
    }
}

/// Stores explicit out-of-band verification separately from TOFU trust.
/// A verification is valid only for the exact combined X25519+Ed25519 identity.
final class GRUE2EEVerificationStore {
    static let shared = GRUE2EEVerificationStore()

    private let service = "sok.com.gru.e2ee.verified-peers.v1"
    private init() {}

    func isVerified(userID: String, identity: GRUE2EEPublicIdentity) -> Bool {
        let current = identity.trustFingerprint
        guard current != "invalid", let stored = load(userID: userID) else {
            return false
        }
        return constantTimeEqual(stored, current)
    }

    func verify(userID: String, identity: GRUE2EEPublicIdentity) throws {
        let fingerprint = identity.trustFingerprint
        guard fingerprint != "invalid", let data = fingerprint.data(using: .utf8) else {
            throw GRUE2EEError.invalidFingerprint
        }

        remove(userID: userID)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(userID),
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw GRUE2EEError.keychain(status)
        }
    }

    func remove(userID: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(userID)
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func load(userID: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(userID),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func account(_ userID: String) -> String {
        "verified-peer-" + userID
    }

    private func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        guard a.count == b.count else { return false }
        var result: UInt8 = 0
        for index in a.indices {
            result |= a[index] ^ b[index]
        }
        return result == 0
    }
}
