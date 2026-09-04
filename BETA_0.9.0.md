# gru. 0.9.0 Beta

Base branch: `verification`
Beta branch: `beta/0.9.0`
Target: closed TestFlight beta.

## Beta freeze

No new large features before the first beta build. Only blocker, crash, auth, networking, media and release-readiness fixes.

## Required before TestFlight

- [ ] Clean install launches on a physical iPhone without a crash.
- [ ] Login creates a valid session; relaunch keeps the session.
- [ ] Production backend is reachable outside the developer LAN over HTTPS.
- [ ] Realtime transport is available over WSS.
- [ ] Chat list loads after login.
- [ ] Text message send/receive works between two accounts.
- [ ] Reconnect after temporary network loss works.
- [ ] Reply works.
- [ ] Edit changes the existing message instead of creating a new message.
- [ ] Delete locally stays local and persists after relaunch.
- [ ] Delete for everyone removes the message silently on both peers.
- [ ] Photo/video/document attachments send and load.
- [ ] Voice message recording/send works.
- [ ] Cat video note recording starts and finishes on a physical iPhone.
- [ ] Cat video note sends and plays on the peer device.
- [ ] Contacts/People screen does not crash when Contacts permission is denied.
- [ ] Camera/microphone/photo permissions have valid usage descriptions.
- [ ] Release build uses production HTTP/WSS endpoints, not `192.168.31.61` or localhost.
- [ ] Archive succeeds with automatic signing for bundle id `sok.com.gru`.

## Known beta blockers

### P0 — Cat video recording on physical iPhone

Current physical-device diagnostics showed attempts to start recording while `AVCaptureSession.isRunning == false`. The beta branch contains retry/session diagnostics, but the feature must be confirmed on-device before distributing the build.

Expected successful console sequence:

```text
🐱 VIDEO NOTE: configured inputs= ... outputs= ...
🐱 VIDEO NOTE: startRunning attempt 1
✅ VIDEO NOTE: CAPTURE SESSION RUNNING
🐱 VIDEO NOTE: movieOutput.startRecording -> ...
✅ VIDEO NOTE: REAL RECORDING STARTED -> ...
```

### P0 — Production transport

Debug currently has a physical-device LAN fallback (`192.168.31.61:8081`). Release already expects production values through `GRUProductionHTTPBaseURL` and `GRUProductionWebSocketURL`, but real HTTPS/WSS values still need to be configured for a TestFlight build.

## Allowed to defer from first beta

- `gru.bot` while provider/API billing is unavailable.
- Calls/video calls.
- GRU Pulse.
- Music/Purr Library.
- Cosmetic polish that does not block primary chat flows.

## First beta acceptance test

Use two real accounts on two physical devices when possible:

1. Install the TestFlight build cleanly.
2. Login on both devices.
3. Open/create a chat.
4. Exchange text messages both directions.
5. Reply, edit and delete messages.
6. Send photo, video, file and voice message.
7. Record/send/play a cat video note.
8. Kill and relaunch both apps; verify history/session.
9. Disable network for ~20 seconds and restore it; verify reconnect.
10. Confirm no request uses a LAN/localhost backend in the Release build.

## Release policy

First external testers receive the build only when every P0 item above is green. Non-blocking UI defects are tracked for `0.9.1`.