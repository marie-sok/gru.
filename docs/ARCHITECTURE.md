# Architecture — gru. 0.9.x

This document describes the active beta architecture. It is intentionally concise and should evolve with the beta branch.

## Active product path

The active mobile client is the native SwiftUI project under:

```text
swiftui/GRU/
```

The active application source is under:

```text
swiftui/GRU/gru./
```

The repository also contains older Flutter/Android and experimental material. Those paths are not the primary TestFlight target.

## iOS layers

Typical source layout:

```text
gru./
├── Components/      # Reusable SwiftUI views and recording/media UI
├── Models/          # Domain models and DTO-adjacent types
├── Services/        # REST, WebSocket, media and system integrations
├── Storage/         # Local persistence/session helpers
├── Themes/          # Colors, fonts and theme configuration
├── ViewModels/      # Screen/domain presentation state
└── Views/           # Feature screens
```

### Networking

The iOS client uses:

- REST for request/response operations;
- WebSocket/STOMP for realtime chat updates;
- a production endpoint configuration for Release/TestFlight;
- local/LAN development endpoints only for development builds.

Release builds must not depend on localhost or developer-LAN addresses.

### Messaging

The beta path includes:

- send/receive;
- reply;
- edit in place;
- local-only deletion;
- delete-for-everyone;
- realtime updates;
- media attachments.

Deletion must remain transparent: deletion is not a new chat activity and deleted content must not reappear after refresh/reconnect.

### Media

Media flows include:

- photos;
- ordinary video;
- documents;
- voice messages;
- branded cat video notes.

Cat video notes are recorded with AVFoundation and must be validated on a physical iPhone before a TestFlight build is accepted.

## Backend

The repository root contains Maven/Spring Boot configuration. The current backend stack is based on:

- Java 21;
- Spring Boot;
- Spring Security;
- JWT authentication;
- REST;
- WebSocket/STOMP;
- MongoDB.

The checked-in Compose configuration is self-contained: it builds the backend
from the repository root and starts a local MongoDB volume. Redis is not part
of the active runtime. Hosted-vendor instructions are intentionally absent.

Backend unit tests cover JWT validation, authentication, content-safety rules
and the public health endpoint. GitHub Actions runs them on beta/backend changes.

Deployment configuration and secrets belong in environment/deployment settings, not in Git.

## Beta release rule

`beta/0.9.0` is feature-frozen. Only beta blockers, crash fixes, auth/networking/media reliability work and release-readiness changes should land before the first TestFlight build.

See [`../BETA_0.9.0.md`](../BETA_0.9.0.md).
