# GRU Android / RuStore transfer

`rustore/` is now based on the current `release/physical-iphone-beta-0.9.2-full`
backend/iOS tree (latest auth fixes included). The Android shell mirrors the
current product direction without copying unsupported iOS capabilities.

## Product surface

- three bottom tabs: Chats, People and Settings;
- GRU.bot entry point and `/bot/chat` transport;
- People search and protected chat creation;
- nine custom GRU themes: Black Moon Cat, Neon Demon Cat, Ultraviolet
  Unicorn, Blood Dragon, Forest Witch, Cyber Midnight, Powder Princess,
  Green Acid Monster and Iron Knight;
- a full-screen animated painter with many small minimal fold-ear
  cat/dragon/unicorn drawings and light decorative motion;
- profile nickname/bio and avatar picker (library or camera), stored locally
  in Keystore until the profile endpoint is added to the backend;
- long-press message actions for delete-for-me and delete-for-everyone;
- no calls, Pulse, Radar or Music/Purr Library.

## Deliberate E2EE gate

The current backend exposes encrypted message history and rejects plaintext
`POST /messages`. The Android composer is intentionally read-only and points
at the E2EE transport work still required for sending text, audio, video and
video-notes. This is a safety boundary, not a hidden downgrade.

## Local commands

```bash
cd rustore
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=GRU_API_BASE_URL=https://gru-jiqi.onrender.com
```

Release builds require a local `android/key.properties` and an HTTPS backend.
