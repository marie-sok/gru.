# GRU Android beta

This is the fast RuStore adaptation of GRU. It is intentionally isolated from
the SwiftUI iOS project in the parent repository.

The app uses the same `/auth/login`, `/auth/register`, `/chats` and
`/chats/{id}/messages` REST routes as the current backend. The base URL is
configurable at build time:

```text
GRU_API_BASE_URL=https://gru-jiqi.onrender.com
```

The release target is `com.marie.sok.gru`, target SDK 35, min SDK 24.
Only INTERNET permission is declared. Calls and unused media permissions are
not requested.

This is a read-only Android preview while the backend's required E2EE v2
message envelope is ported. A plaintext fallback is deliberately not
implemented.
