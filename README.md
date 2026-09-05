# gru.

**gru.** is a private, expressive messenger for close communication — a native iOS experience with its own visual language, realtime messaging and lightweight media flows.

> **Status:** `0.9.0` closed-beta preparation. The active release target is the native SwiftUI iOS app.

## Product

The first beta is intentionally focused on the core messenger experience:

- authentication and session persistence;
- one-to-one chats and realtime messaging;
- reply, edit and delete flows;
- photo, video, document and contact attachments;
- voice messages;
- branded **cat video notes**;
- People / contacts;
- per-chat appearance and app themes;
- built-in **GRU Bot** beta agent for navigation, themes and messenger help;
- automatic network recovery and offline/cached-state feedback.

Audio/video calls, GRU Pulse, GRU Radar and Music/Purr Library are intentionally
not part of the beta product.

## Active stack

### iOS

- Swift / SwiftUI
- iOS 17+
- AVFoundation
- REST API
- WebSocket / STOMP
- Xcode project: `swiftui/GRU/gru..xcodeproj`
- scheme: `gru`
- bundle identifier: `sok.com.gru`

### Backend

- Java 21
- Spring Boot
- Spring Security + JWT
- REST API
- WebSocket / STOMP
- MongoDB
- Maven

## Repository layout

```text
.
├── swiftui/GRU/                 # Active native iOS client
│   ├── gru..xcodeproj
│   ├── gru./                    # SwiftUI application source
│   ├── gru.Tests/
│   └── gru.UITests/
├── src/                         # Spring Boot backend
├── pom.xml                      # Maven build
├── Dockerfile
├── docker-compose.yml
├── docs/                        # Architecture and repository notes
├── BETA_0.9.0.md                # Beta acceptance checklist
├── AUTHORS.md                   # Project authorship
├── SECURITY.md                  # Security reporting policy
└── README.md
```

Old Flutter, generated IDE/tooling output and abandoned web experiments are not part of the beta branch. Their previous versions remain available through Git history.

## Run the iOS app

1. Open `swiftui/GRU/gru..xcodeproj` in Xcode.
2. Select scheme `gru`.
3. Select a **physical iPhone** for camera, microphone and video-note testing.
4. Build and run with `⌘R`.

The checked-in development entitlements are compatible with an Apple Personal
Team. Push Notifications and iCloud are deliberately disabled in this local
beta configuration; enable them only with a paid team and matching provisioning.

For TestFlight/Release, the app must use production HTTPS/WSS endpoints instead of localhost or a developer-LAN address.

## Run the backend

Requirements: Java 21 and Maven.

```bash
mvn clean test
mvn spring-boot:run
```

Or launch the complete local server stack (backend + local MongoDB):

```bash
docker compose up --build
curl http://127.0.0.1:8081/health
```

The backend entry point is `gru.app.GruApplication`. The local stack does not
use Redis, Render or MongoDB Atlas; persistent Mongo data is stored in the
Docker volume `mongo_data`.

Production credentials and secrets must be supplied through deployment configuration or environment variables. They must never be committed to the repository.

## Beta 0.9.0

Active beta branch:

```text
beta/0.9.0
```

Readiness criteria are tracked in [`BETA_0.9.0.md`](./BETA_0.9.0.md).

Current P0 focus:

1. stable cat-video recording on a physical iPhone;
2. production HTTPS/WSS transport for TestFlight;
3. clean-install/login/session/reconnect stability;
4. message and media smoke tests on real devices.

## Authorship

**Created and developed by Marie Sok (`@marie-sok`).**

Marie Sok is the creator of **gru.**, primary product author, designer/developer and repository maintainer. See [`AUTHORS.md`](./AUTHORS.md).

## License

Copyright © 2026 Marie Sok. All rights reserved. See [`LICENSE`](./LICENSE).

---

**gru. — For your people.**
