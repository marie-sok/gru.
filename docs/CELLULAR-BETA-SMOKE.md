# GRU beta cellular smoke — physical iPhone

This gate must be run on a physical iPhone with an active SIM/eSIM. Simulator network changes do not prove radio handoff behavior.

## Preconditions

- Install the exact TestFlight/Release candidate build.
- Use two GRU accounts on two devices when validating A↔B delivery.
- Confirm Settings diagnostics reports the production HTTPS/WSS host.
- Start on Wi-Fi with cellular data enabled.

## Gate A — cold cellular launch

1. Force-quit GRU.
2. Disable Wi-Fi in iOS Settings (not only Control Center).
3. Confirm Safari can load a public page over cellular.
4. Launch GRU.
5. Pass criteria: no crash, existing session restores or login succeeds, diagnostics shows `Cellular`, `/health` and `/ready` are healthy, WebSocket connects.
6. Send A→B and B→A text messages. Both must arrive without manual refresh.

## Gate B — live Wi-Fi → cellular handoff

1. Keep an authenticated chat open while connected to Wi-Fi.
2. Send one message and confirm delivery.
3. Disable Wi-Fi while GRU remains foregrounded.
4. Do not relaunch the app.
5. Pass criteria: the route changes to `Cellular`, GRU refreshes backend readiness and creates a fresh authenticated STOMP connection automatically.
6. Send A→B and B→A again. No duplicate messages and no permanently queued message are allowed.

## Gate C — cellular → Wi-Fi handoff

Repeat Gate B in reverse. Realtime must recover automatically and no stale socket may remain authoritative.

## Gate D — temporary loss

1. On cellular, enable Airplane Mode for 15 seconds.
2. Attempt one text send while offline.
3. Disable Airplane Mode and keep GRU foregrounded.
4. Pass criteria: offline UI appears, the app does not crash, backend readiness recovers, WebSocket reconnects, and the queued/retry path does not create duplicates.

## Gate E — media on cellular

With Wi-Fi disabled, validate in this order:

- photo
- regular video
- document
- voice message
- cat video note (record → preview/send → peer receive/playback)

Pass criteria: upload completes, peer receives the message, media can be opened/played, no plaintext downgrade endpoint is used, and a failed transfer surfaces a retryable error rather than hanging forever.

## Gate F — message mutations after handoff

After at least one Wi-Fi/cellular transition:

- edit your own text message
- delete for yourself
- delete your own message for everyone
- verify the peer receives the mutation

## Evidence to keep with the RC

Record:

- build number and commit SHA
- iPhone model + iOS version
- carrier
- test timestamp
- diagnostics text before and after the handoff
- result for A–F

A beta candidate is blocked if cold cellular launch, A↔B text, realtime recovery, or cat-video-note send/receive fails. Performance-only differences on cellular may be deferred if correctness and retry behavior remain intact.
