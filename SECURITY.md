# Security Policy

## Supported line

Security fixes for the current beta are developed on the latest `beta/0.9.x` release-candidate branch and carried forward.

## Current protection model

### Transport

Production API and realtime traffic use TLS (`HTTPS` / `WSS`). TLS protects data in transit between the app and production infrastructure, but TLS alone is **not** end-to-end encryption.

### Authentication and device storage

- Authentication tokens are stored in iOS Keychain.
- Sensitive local chat/message caches are encrypted before being written to disk.
- The local cache master key is stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and is not designed to migrate to another device.
- Sensitive cache files additionally use iOS complete file protection.

### E2EE v1 foundation

`feature/e2ee-v1` introduces the first direct-chat E2EE protocol foundation:

- X25519 key agreement via CryptoKit;
- per-message ephemeral sender key;
- ChaCha20-Poly1305 authenticated encryption;
- Ed25519 signatures over canonical encrypted envelopes;
- public-key fingerprints and key-change detection;
- private identity keys remain on the iOS device in Keychain;
- the server stores public identity keys and opaque ciphertext only for E2EE messages.

A key change must not be silently trusted. The client is expected to surface a safety-number/fingerprint confirmation before enabling E2EE by default for a peer.

## Important limitations

E2EE v1 is a foundation, not a claim of Signal-protocol equivalence. Before calling all gru. chats end-to-end encrypted in public product copy, the following must be completed and verified:

1. wire encrypted send/decrypt into the production chat UI;
2. implement explicit fingerprint/safety-number verification UX;
3. encrypt attachments, voice notes and video notes end-to-end;
4. define multi-device key management and recovery without server access to private keys;
5. add protocol replay/ordering protections and key-rotation tests;
6. complete an independent security review before making strong security claims.

Until those gates are complete, public copy must say E2EE is being implemented/rolled out rather than implying every message is already E2EE-protected.

## Reporting a vulnerability

Please do **not** publish credentials, tokens, private user data or reproducible security details in a public issue.

For a security-sensitive report:

1. contact the repository owner, **Marie Sok (`@marie-sok`)**, privately; or
2. use GitHub private security reporting / Security Advisories when available.

Include the affected component, impact, reproduction steps and the smallest safe proof of concept you can provide.

## Secrets

The repository must never contain production API keys, JWT secrets, database credentials, signing certificates, provisioning profiles, private `.env` files or private E2EE identity keys.

Production secrets are supplied through deployment configuration and environment variables.
