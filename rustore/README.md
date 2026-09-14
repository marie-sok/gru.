# GRU Android beta · current transfer

This Flutter client is the Android/RuStore transfer of the current GRU
SwiftUI release. The branch is rebased on the latest iOS release commit and
keeps the same authenticated REST contracts.

## Included in this transfer

- phone/password login and registration;
- secure auth, theme, profile and avatar-path storage in Android Keystore;
- Chats, People and Settings navigation with neon circular icons;
- GRU.bot chat through `POST /bot/chat` (including the backend fallback);
- GRU user search through `GET /users/search` and chat creation through
  `POST /chats`;
- message history through `GET /chats/{id}/messages`;
- delete for me and delete for everyone through the existing protected routes;
- nine GRU-only animated wallpaper presets with many small minimal
  fold-ear cat/dragon/unicorn doodles;
- avatar selection from the Android photo library or camera;
- no audio/video calls, Pulse, Radar or Music/Purr Library.

## Security boundary

The backend rejects legacy plaintext message writes with HTTP 426. The Android
preview therefore keeps the composer visibly read-only until the native GRU
E2EE envelope is ported. It never sends plaintext as a fallback. Release
builds use HTTPS only (`usesCleartextTraffic=false`).

## Run from Android Studio

```bash
cd rustore
flutter pub get
flutter run --dart-define=GRU_API_BASE_URL=https://gru-jiqi.onrender.com
```

For a local backend use a reachable HTTPS tunnel in a release build. Debug
builds can use a LAN URL when `--dart-define=GRU_API_BASE_URL=...` is supplied.

## RuStore bundle

Create `android/key.properties` from `key.properties.example` locally, keep it
out of Git, then run:

```bash
flutter build appbundle --release \
  --dart-define=GRU_API_BASE_URL=https://gru-jiqi.onrender.com
```

The output is `build/app/outputs/bundle/release/app-release.aab`.
