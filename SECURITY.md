# Security Policy

## Supported line

Security fixes for the current beta are developed on the latest `beta/0.9.x` release-candidate branch and carried forward.

## Current protection model

### Transport

Production API and realtime traffic use TLS (`HTTPS` / `WSS`). TLS protects traffic between the app and production infrastructure. E2EE-protected content is additionally encrypted on the iOS device before it enters that transport.

### Authentication and device storage

- Authentication tokens are stored in iOS Keychain.
- Sensitive local chat/message caches are encrypted before being written to disk.
- The local cache master key is stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and is not designed to migrate to another device.
- Sensitive cache files additionally use iOS complete file protection.
- Long-lived E2EE private identity keys stay in the iOS Keychain and are not uploaded to the server.

### Direct-chat E2EE v1

`feature/e2ee-v1` implements a first direct-chat E2EE protocol for the current iOS client:

- X25519 key agreement via CryptoKit;
- per-message ephemeral sender key;
- ChaCha20-Poly1305 authenticated encryption;
- Ed25519 signatures over canonical encrypted envelopes;
- signed client-generated message IDs plus replay detection;
- TOFU peer identity pinning in Keychain;
- the pinned identity binds both the peer X25519 and Ed25519 public keys;
- later peer-key changes fail closed rather than being silently accepted;
- text messages are encrypted before transport and have no plaintext fallback in the normal direct-chat send path;
- message edits are sent as new authenticated encrypted envelopes;
- reply routing keeps message IDs/sender IDs on the server but does not require reply plaintext;
- realtime and history E2EE envelopes are verified and decrypted on-device;
- photo, video, video-note, document and voice/audio bytes are encrypted on-device before upload;
- each media file uses a random symmetric key; that key is itself carried inside the signed E2EE envelope;
- GridFS stores encrypted media bytes for the E2EE media path;
- authenticated `/media/...` downloads are decrypted on-device after the matching E2EE envelope has been verified;
- the server stores public identity material, ciphertext and operational metadata, not the protected message/media plaintext for these E2EE paths.

The server still sees metadata required to operate the service, including participants, timestamps, delivery/read state, message IDs, attachment metadata and routing information.

## Trust model

The current beta uses trust-on-first-use (TOFU): the first observed complete peer identity is pinned locally. A later identity change is blocked.

TOFU is materially weaker than out-of-band identity verification against a malicious first-contact key-directory/server. A safety-number / QR verification UI is therefore still required before making stronger identity-authentication claims.

## Important limitations

E2EE v1 is a direct-chat protocol implementation, **not** a claim of Signal Protocol equivalence and not yet a blanket claim that every possible gru. communication is end-to-end encrypted.

Before public product copy describes gru. as fully E2EE, the following still need to be completed and verified:

1. implement explicit fingerprint / safety-number verification UX;
2. define and test multi-device key management, reinstall recovery and user-facing signed key rotation without server access to private keys;
3. extend the model to groups before claiming group-chat E2EE;
4. perform two-device physical-iPhone/TestFlight interoperability tests covering text, realtime reconnect, edits and every encrypted media type;
5. expand protocol/adversarial tests, including key substitution, malformed envelopes, replay, rollback and media corruption cases;
6. complete an independent cryptographic/security review before making strong security claims.

Legacy plaintext endpoints remain for compatibility with older clients. The current E2EE branch routes its normal direct-chat text and supported media send paths through the encrypted endpoints, but the backend does not yet enforce a universal “E2EE-only” policy for every client version.

## Reporting a vulnerability

Please do **not** publish credentials, tokens, private user data or reproducible security details in a public issue.

For a security-sensitive report:

1. contact the repository owner, **Marie Sok (`@marie-sok`)**, privately; or
2. use GitHub private security reporting / Security Advisories when available.

Include the affected component, impact, reproduction steps and the smallest safe proof of concept you can provide.

## Secrets

The repository must never contain production API keys, JWT secrets, database credentials, signing certificates, provisioning profiles, private `.env` files or private E2EE identity keys.

Production secrets are supplied through deployment configuration and environment variables.
