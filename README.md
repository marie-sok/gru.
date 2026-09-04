# gru.

**gru.** is a private, expressive messenger focused on close communication, a distinct visual language, and lightweight real-time interaction.

> **Status:** `0.9.0` closed-beta preparation. The active release target is the native iOS app in SwiftUI.

## Product direction

gru. is being built around personal communication rather than feature-count competition: chats, media, voice, branded cat video notes, expressive themes, contacts, and a focused AI layer.

The current beta scope includes:

- authentication and session persistence;
- chat list and one-to-one chats;
- realtime messaging over WebSocket/STOMP;
- reply, edit and delete flows;
- photo, video, document and contact attachments;
- voice messages;
- branded **cat video notes**;
- People / contacts;
- per-chat appearance and app themes;
- optional `gru.bot` integration.

Calls, GRU Pulse and Music/Purr Library are intentionally outside the first beta scope.

## Current stack

### iOS client

- Swift / SwiftUI
- iOS 17+
- Xcode project: `swiftui/GRU/gru..xcodeproj`
- scheme: `gru`
- bundle identifier: `sok.com.gru`
- REST API + WebSocket/STOMP
- AVFoundation for voice/video capture

### Backend

- Java 21
- Spring Boot 3.2.x
- REST API
- Spring WebSocket / STOMP
- Spring Security + JWT
- MongoDB
- Maven

The repository also contains older Flutter/Android and experimental materials. They are retained for history/reference, but **the SwiftUI iOS client is the active beta target**.

## Repository map

```text
.
├── swiftui/GRU/                 # Active native iOS client
│   ├── gru..xcodeproj
│   └── gru./                    # SwiftUI application source
├── src/                         # Spring backend source where present
├── pom.xml                      # Spring Boot / Maven configuration
├── android/                     # Legacy / experimental Android material
├── lib/                         # Legacy Flutter source
├── BETA_0.9.0.md                # Beta freeze and acceptance checklist
├── AUTHORS.md                   # Authorship and maintainership
└── README.md
```

## Run the iOS app

1. Open `swiftui/GRU/gru..xcodeproj` in Xcode.
2. Select scheme `gru`.
3. Select a physical iPhone for camera, microphone and video-note testing.
4. Build and run with `⌘R`.

For TestFlight/Release, the app must use production HTTPS/WSS endpoints rather than localhost or a developer-LAN address.

## Run the backend

Requirements: Java 21 and Maven.

```bash
mvn spring-boot:run
```

Production configuration, credentials and secrets must be supplied through deployment configuration/environment variables and must not be committed to the repository.

## Beta 0.9.0

The beta branch is:

```text
beta/0.9.0
```

Beta readiness and blocker criteria are tracked in [`BETA_0.9.0.md`](./BETA_0.9.0.md).

Current P0 focus:

1. stable cat-video recording on a physical iPhone;
2. production HTTPS/WSS transport for TestFlight;
3. clean-install/login/session/reconnect stability;
4. message send/receive/edit/delete and media smoke tests.

## Security

Do not commit:

- API keys;
- JWT signing secrets;
- production credentials;
- private certificates or provisioning files;
- `.env` files containing secrets.

## Authorship

**Created and developed by Marie Sok (`@marie-sok`).**

Primary author, product creator and repository maintainer: **Marie Sok**.

See [`AUTHORS.md`](./AUTHORS.md) for the authorship statement.

---

**gru. — Для своих.**
