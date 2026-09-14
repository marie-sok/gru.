# GRU Android / RuStore adapter

This branch adds a separate Flutter Android preview under `rustore/`. The
canonical iOS SwiftUI beta and Spring backend remain unchanged.

Current preview scope:

- phone/password login and registration;
- secure token storage using Android Keystore-backed `flutter_secure_storage`;
- chat list and message history over the current REST API;
- production HTTPS endpoint by default;
- RuStore-ready Android package ID: `com.marie.sok.gru`;
- no audio/video calls, Pulse, Radar or Music/Purr Library;
- no cleartext HTTP in release builds.

The current backend deliberately rejects plaintext message writes with HTTP 426
and requires the GRU E2EE envelope. Therefore this first Android preview is
read-only for message history until the E2EE v2 transport is ported. It must not
silently downgrade to plaintext.

Build locally on macOS:

```bash
cd rustore
flutter pub get
flutter run --dart-define=GRU_API_BASE_URL=https://gru-jiqi.onrender.com
```

For a local backend in a debug build, use an HTTPS tunnel or set a reachable
HTTPS URL. Release builds reject cleartext traffic by design.

Create a private signing key once:

```bash
keytool -genkeypair -v -keystore ~/gru-release.jks \
  -alias gru-release -keyalg RSA -keysize 2048 -validity 10000
cp key.properties.example android/key.properties
```

Fill `android/key.properties` locally (never commit it), then build the
bundle:

```bash
flutter build appbundle --release \
  --dart-define=GRU_API_BASE_URL=https://gru-jiqi.onrender.com
```

The output is `build/app/outputs/bundle/release/app-release.aab`. For a
quick device smoke test, use `flutter build apk --debug` or
`flutter run`.

If Flutter reports that the Gradle wrapper is missing, run this once from the
`rustore` directory; it generates the official wrapper without changing the
Dart UI:

```bash
flutter create --platforms=android --org com.marie.sok .
```

Before uploading to RuStore, replace the example signing values with the
private release key and test the signed AAB on a physical Android device. Do
not reuse an iOS bundle identifier or an already-published Android package
unless its signing certificate is intentionally preserved.
