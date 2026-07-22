# KPFK — Next session release checklist

**Written 2026-07-22.** WBAI was fully finished and published this day; KPFK was
intentionally deferred to the next session. The API-36 target bump and the
Java-8 warning fix are **already done and pushed** for KPFK (commit `a351652`).
What remains is the same cleanup + release that WBAI got, mirrored here.

Reference the completed WBAI work as the exact template — same codebase lineage,
same steps. WBAI commits on its `main`:
- `1c7f292` — remove dead Samsung MediaSession Dart service
- `3bc5c26` — drop dead media permissions + version bump

## What's left for KPFK

### 1. Remove the dead Samsung MediaSession service
Same as WBAI: `SamsungMediaSessionService` calls a native MethodChannel
(`app.pacifica.kpfk/samsung_media_session`) that nothing implements — the
manifest launches `AudioServiceActivity`, not the `MainActivity` where the
channel would be registered. It spams `MissingPluginException` (SEVERE) on
device every playback change. The media tray is produced entirely by the
`audio_service` plugin and is unaffected by removing it.

- Delete `lib/services/samsung_media_session_service.dart`.
- Remove its references (import + init block) in `lib/main.dart`.
- Remove its 5-ish call sites + import in
  `lib/services/audio_service/kpfk_audio_handler.dart`
  (note: KPFK's handler is `kpfk_audio_handler.dart`, not `wbai_...`).
- Leave the orphaned native `MainActivity.kt` / `SamsungMediaSessionManager.kt`
  in place (R8 strips them; native-file deletion is a separate change).

### 2. Drop two dead permissions from `android/app/src/main/AndroidManifest.xml`
Currently at lines ~19 and ~21, under the "CRITICAL: Samsung MediaSession
permissions" comment:
- `android.permission.MEDIA_CONTENT_CONTROL` — signature/privileged, a normal
  app can never hold it; declaring it can draw Play pre-launch notes.
- `android.permission.BIND_MEDIA_BUTTON_RECEIVER` — not a real platform
  permission.
Keep `FOREGROUND_SERVICE_MEDIA_PLAYBACK` and `POST_NOTIFICATIONS` (audio_service
needs them). Fix the misleading comment.

### 3. Bump the build number
`pubspec.yaml`: `version: 1.0.1+11` → `1.0.1+12` (keep versionName 1.0.1).
`flutter build` regenerates `android/local.properties` versionCode from this.

### 4. Verify + build
- `flutter analyze` (expect clean).
- `flutter run --release` on a real device — confirm **no** `SAMSUNG`
  SEVERE/`MissingPluginException` lines, tray + streaming still work. (WBAI was
  verified this way on Android 8.1 and Android 14.)
- `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.
- Sanity-check the bundle: versionCode 12, targetSdk 36, and that the two dead
  permissions are gone (check AGP `output-metadata.json` + unzip base manifest).

### 5. KPFK-specific pre-ship check (does NOT apply to WBAI)
KPFK's `AudioServiceActivity` hardcodes `android:screenOrientation="portrait"`.
Android 16's (repeatedly delayed) large-screen orientation-override for apps
targeting SDK 36 could force rotation on tablets/foldables. Give it a quick
tablet-emulator check before promoting to production. See
`docs/api-target-android.md` for the full risk notes.

### 6. Publish
Upload the `.aab` to Play Console → internal testing first, then promote to
production ahead of the **Oct 31, 2026** API-36 update deadline.

## Signing (already configured, same as WBAI)
`android/key.properties` present, keystore resolves; release `signingConfig`
wired. Nothing to set up.
