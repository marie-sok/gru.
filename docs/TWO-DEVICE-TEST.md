# Physical two-iPhone E2EE validation

This is a beta release gate. A simulator-only result does not replace it.

## Setup

- Build: the exact TestFlight candidate intended for closed beta.
- Device A: account A.
- Device B: account B, owned by a trusted second tester if a second local iPhone is unavailable.
- Both devices use production HTTPS/WSS transport.

## Core messaging

- A sends text to B in foreground.
- B sends text to A in foreground.
- Both directions receive once, in order, with no plaintext fallback.
- Force-quit A, send from B, reopen A and verify history decrypt.
- Force-quit B, send from A, reopen B and verify history decrypt.
- Disable network on receiver, send, restore network and verify recovery/reconnect.

## Message features

Test both directions where applicable:

- reply
- edit
- reaction
- delivered/read state
- delete for self / everyone
- photo
- video
- voice/audio
- video note
- document

## Identity verification

- Compare safety number on A and B; it must be identical.
- Compare QR/fingerprint out of band.
- Mark peer explicitly verified and relaunch both apps.
- Deliberately replace one test identity and verify the other device blocks until re-verification.

## Recovery / reinstall

On device A:

1. Create/refresh encrypted recovery backup.
2. Confirm recovery code is available outside the app.
3. Remove/reinstall the TestFlight build or use a clean replacement test device.
4. Log into account A.
5. Restore via synchronized Keychain; repeat once with recovery-code fallback if feasible.
6. Verify restored public identity exactly matches the pre-reinstall identity.
7. Verify B does not show a false identity-change warning.
8. Verify historical incoming messages decrypt.
9. After sender-recovery protocol v2 lands, verify historical outgoing text and media-key payloads decrypt as well.

## Metadata authorization adversarial checks

Using an authenticated test account C that is not in A/B's chat:

- attempt STOMP subscribe to A/B `/topic/chat/{chatId}` -> must be rejected;
- attempt subscribe to `/topic/chat/{chatId}/typing` -> must be rejected;
- attempt authenticated GET of A/B media path -> must return non-enumerating 404;
- account C must not receive A/B message or typing events.

## Pass condition

All items above are green on the TestFlight candidate. Any failure involving key continuity, decryptability, unauthorized metadata access, duplicate delivery or plaintext fallback is a P0 blocker.
