# GRU 0.9.2 — Physical iPhone Beta Release Checklist

Updated: 2026-09-12
Branch: `release/physical-iphone-beta-0.9.2-full`

## Physically verified on iPhone

The current beta line has been exercised on a real iPhone through the ordinary Xcode Run flow.

Verified by physical-device smoke:

- ordinary Xcode Run launches without local backend/Docker/manual endpoint switching;
- authentication completes against production transport;
- Wi-Fi -> cellular handoff keeps GRU usable;
- cellular -> Wi-Fi and offline -> online recovery reconnect realtime;
- background/foreground recovery works;
- runtime RU/EN switching no longer recreates the root navigation tree;
- Chats <-> Settings switching is stable;
- keyboard no longer depends on the removed hidden secure-text responder;
- reply, edit and delete paths work in physical-device smoke;
- voice recording/playback works;
- video-note / cat-circle flow works;
- production Release Info.plist points to `gru-edge-v2` for HTTPS and WSS.

## Security/privacy hardening

- E2EE transport remains fail-closed for direct chat text/media paths.
- Private E2EE key material remains device-side; backend receives public identity material and encrypted recovery payloads only.
- Cached chats/messages/media/transcripts use protected local storage.
- Logout / cache reset now cancels delayed chat-cache writes and purges chat cache, protected media cache, voice-transcript cache and per-user local deletion markers.
- The unstable whole-app secure `UITextField` compositor was removed because it caused responder/black-screen regressions on physical devices.
- Stable screen privacy now covers:
  - active screen recording / mirroring (`UIScreen.isCaptured`);
  - app switcher / inactive / background snapshots;
  - immediate privacy shielding and warning after iOS reports a still screenshot.

### iOS screenshot limitation

Public iOS APIs notify an app after a normal still screenshot has been taken. GRU can immediately shield the UI and react to the event, but cannot truthfully guarantee cancellation of the system screenshot before it is produced without relying on unsupported compositor tricks. Those tricks are intentionally not used in the beta because they previously caused black-screen and keyboard regressions.

## Automated beta gate

`.github/workflows/physical-iphone-beta.yml` now runs on every push to the physical beta branch and covers:

1. release-hardening source audit;
2. RU/EN runtime localization audit;
3. edge proxy validation;
4. beta-critical Spring Boot security/E2EE/media/auth tests;
5. dual-client E2EE crypto smoke;
6. Debug Simulator build;
7. unsigned Release iPhone-architecture build;
8. verification of generated Release HTTPS/WSS endpoints.

The TestFlight workflow also runs release/localization/E2EE preflight and verifies the archived app's production endpoints before IPA export/upload.

## Open P1 before broad external beta

### Remote push notifications (APNs)

Not complete yet.

Current state:

- local notification service exists;
- notification privacy settings exist;
- notification permission can be requested from Settings;
- `gru_.entitlements` does not yet contain an APNs entitlement;
- there is no production device-token registration API in the backend;
- there is no APNs provider delivery path on the backend.

Required before claiming remote push support:

1. enable Push Notifications for the App ID/provisioning profile;
2. add APNs entitlement through the signed target capability;
3. register/unregister device tokens per authenticated account/device;
4. send privacy-safe pushes from backend when the recipient is not active;
5. test sandbox + TestFlight production APNs on two physical devices;
6. verify logout/account deletion revokes the stored device token.

### Profile cross-device sync

Profile avatar/bio/username presentation is currently primarily local iOS state. Backend user data currently centers on account identity/nickname and safety/E2EE fields. Do not claim full cross-device profile synchronization until the server contract is explicitly extended and tested.

## Release policy

No new large product features should enter this branch before the first external beta. From this point, changes should be limited to:

- P0/P1 crash, auth, privacy, transport, E2EE, data-loss and physical-device regressions;
- localization correctness;
- APNs production integration;
- small UX fixes that do not replace stable root/navigation infrastructure.
