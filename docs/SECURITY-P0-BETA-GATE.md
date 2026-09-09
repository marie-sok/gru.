# GRU E2EE — P0 beta gate

This document is a release gate, not a marketing checklist. Closed beta must not be treated as security-ready until every P0 item below is complete.

## P0-1 — reinstall / replacement iPhone recovery

Required behavior:

1. The long-lived X25519 + Ed25519 identity must survive a new installation without uploading plaintext private keys to GRU servers.
2. The server may store only an opaque, client-encrypted recovery bundle.
3. The recovery key must remain outside the GRU backend. Beta recovery uses iCloud Keychain plus a user-held recovery code fallback.
4. A restored identity must be checked against the account's already registered public identity before local Keychain replacement.
5. A successful restore must not trigger a peer identity-change warning.
6. A missing recovery key must fail closed. Password login alone must not silently replace an E2EE identity.
7. Sent-message history must remain readable after reinstall. Device-local sender plaintext cache alone is not sufficient; the message protocol needs a sender-readable encrypted recovery copy for future messages.

## P0-2 — physical two-device validation

Run with two separate GRU accounts on two real iPhones through the TestFlight build intended for beta.

Required matrix:

- A -> B realtime text
- B -> A realtime text
- reconnect after force quit on both devices
- receiver offline, then reconnect/history sync
- text history decrypt after relaunch
- photo both directions
- video both directions
- voice/audio both directions
- video note both directions
- document both directions
- reply, edit, reaction, delivered/read state and delete
- safety number identical on both devices
- explicit verification survives relaunch
- deliberate key change blocks communication until re-verification
- reinstall/new-device restore keeps the same identity
- old history remains readable after restore
- peer does not receive a false identity-change warning after a valid restore

Simulator tests are useful for deterministic protocol and UI checks, but do not satisfy this gate by themselves.

## P0-3 — metadata authorization

E2EE does not authorize metadata automatically. Required controls:

- STOMP CONNECT requires a valid JWT.
- `/topic/chat/{chatId}` subscription requires chat membership.
- `/topic/chat/{chatId}/typing` subscription requires chat membership.
- unknown broker topics are denied by default.
- media retrieval requires authentication plus membership in the owning chat.
- unauthorized media access returns a non-enumerating response and does not read the blob.
- REST chat/message operations must continue to enforce participant/sender/receiver authorization.
- presence exposure must be explicitly scoped before public launch; global authenticated presence is accepted only as a beta-known limitation if documented.

## Known non-P0 follow-ups

- short-lived access token + rotating refresh token
- stronger presence privacy/scoping
- edge CAPTCHA / phone verification with an SMS provider
- message-retention policy
- independent security/cryptography review
- ongoing DAST and dependency automation on the production branch
