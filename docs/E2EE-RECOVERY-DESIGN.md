# E2EE recovery design — beta P0

## Problem

GRU's long-lived X25519 and Ed25519 private identity keys are intentionally stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. That is correct for device isolation, but it means a replacement iPhone or reinstall cannot derive the old identity from the server.

The server-side key rotation endpoint also correctly requires a signature by the old Ed25519 key. Therefore password login alone cannot safely rotate a lost identity.

## Beta recovery design

1. Keep active X25519 + Ed25519 private identity keys device-local.
2. Export only the raw private identity material into a small recovery bundle on-device.
3. Encrypt that bundle with a random 256-bit recovery key using ChaChaPoly.
4. Sign the encrypted bundle with the current Ed25519 identity key.
5. Upload only the signed ciphertext to `/e2ee/recovery/me`.
6. Store the recovery key in synchronizable Apple Keychain for normal iPhone-to-iPhone migration.
7. Show the same recovery key to the user as an exportable recovery code for the case where iCloud Keychain is unavailable.
8. On restore, decrypt locally, derive the recovered public identity and compare it with the account's already registered public identity before replacing local Keychain items.
9. Never accept password-only silent E2EE identity replacement.

## What the GRU server learns

The server sees:

- whether an account has a recovery backup;
- backup version, ciphertext size and update time;
- a signature made by the user's current public signing identity.

The server does **not** receive:

- X25519 private key;
- Ed25519 private key;
- recovery key / recovery code;
- decrypted recovery bundle.

## Important sender-history consequence

Restoring the same long-lived identity is necessary but not by itself sufficient for complete history recovery in the current `gru-e2ee-v1` protocol.

Incoming messages are encrypted to the current user's X25519 identity, so the restored private agreement key can decrypt their historical envelopes.

Outgoing messages are encrypted to the peer. The sender currently relies on `GRUE2EESentMessageStore`, a device-local protected plaintext/key-payload copy. That store does not survive a lost device.

Before beta, future E2EE messages therefore need a sender-readable encrypted recovery copy stored alongside the receiver envelope (protocol v2), or an equivalently secure per-message recovery mechanism. The server must still receive ciphertext only.

This is a P0 requirement. Identity backup alone must not be represented as complete history recovery.
