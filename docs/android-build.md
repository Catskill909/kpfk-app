# Android Build Guide — KPFK Radio

Reference for setting up, maintaining, and building the Android app after any extended break.

---

## Quick commands

```bash
# From the Flutter project root
cd kpfk_radio

# Debug build (no signing needed)
flutter build apk --debug

# Release APK (requires key.properties — see Signing section)
flutter build apk --release

# Release App Bundle for Play Store
flutter build appbundle --release

# Install debug build on connected device
flutter install

# Run directly on connected device
flutter run
```

---

## First-time / after-a-break checklist

Run these in order any time you've been away for a while.

### 1. Check the environment

```bash
flutter doctor -v
```

All items should be green. Common failures and fixes are in the Troubleshooting section below.

### 2. Upgrade Flutter

```bash
flutter upgrade
```

As of the last maintenance run (June 2026): **Flutter 3.44.3 / Dart 3.12.2**

### 3. Refresh packages

```bash
cd kpfk_radio
flutter pub get
flutter pub outdated   # review what has newer versions
```

See the Package Upgrade Policy section before running `flutter pub upgrade --major-versions`.

### 4. Set up signing (if on a new machine)

```bash
cp android-signing/key.properties kpfk_radio/android/key.properties
```

`key.properties` is gitignored — it must be placed manually on each machine.
Full signing details are in [android-signing/SIGNING-INSTRUCTIONS.md](../android-signing/SIGNING-INSTRUCTIONS.md).

### 5. Clean build (do this after Flutter upgrades)

```bash
flutter clean && flutter build apk --debug
```

---

## Running on a physical device

1. **Enable Developer Options** on the Android device:
   Settings → About Phone → tap "Build number" 7 times

2. **Enable USB Debugging**:
   Settings → Developer Options → USB Debugging → ON

3. **Connect via USB** and accept the "Allow USB Debugging" prompt on the device.

4. **Verify the device appears:**

   ```bash
   adb devices
   flutter devices
   ```

5. **Install and launch:**

   ```bash
   cd kpfk_radio
   flutter run
   ```

   To target a specific device when multiple are connected:
   ```bash
   flutter run -d <device-id>
   ```

---

## Signing

The keystore lives in `android-signing/` at the repo root.

| File | Purpose |
|------|---------|
| `android-signing/kpfk-release.jks` | Release keystore (gitignored via `*.jks`) |
| `android-signing/key.properties` | Credentials — gitignored, **never commit** |
| `android-signing/SIGNING-INSTRUCTIONS.md` | Full signing docs + passwords |

**How `build.gradle` loads signing:**
`kpfk_radio/android/app/build.gradle` reads `android/key.properties` at build time.
If the file is missing, the release signing config fields are null and the build fails safely.

**Verify a built APK is properly signed:**
```bash
~/Library/Android/sdk/build-tools/36.1.0/apksigner verify --print-certs \
  kpfk_radio/build/app/outputs/flutter-apk/app-release.apk
```

Expected output: `CN=Pacifica Foundation, OU=Engineering, O=Pacifica Foundation`

---

## Android project versions

| Component | Version | File |
|-----------|---------|------|
| Gradle wrapper | 8.14.2 | `android/gradle/wrapper/gradle-wrapper.properties` |
| AGP (Android Gradle Plugin) | 8.12.2 | `android/settings.gradle` |
| Kotlin | 2.2.20 | `android/settings.gradle` |
| Android NDK | 28.2.13676358 | `android/app/build.gradle` |
| compileSdk | 36 | `android/app/build.gradle` |
| targetSdk | 35 | `android/app/build.gradle` |
| minSdk | Flutter default | `android/app/build.gradle` |

**Flutter's minimum requirements** (as of 3.44.x):
- Gradle ≥ 8.14.0
- Kotlin ≥ 2.2.20

If you see warnings about versions being "soon dropped", update the values in the table above.

---

## Package upgrade policy

These packages are core to audio playback — **do not upgrade major versions without testing on device:**

| Package | Current | Notes |
|---------|---------|-------|
| `just_audio` | `^0.9.35` | 0.10.x has breaking API changes |
| `audio_service` | `^0.18.12` | Tightly coupled to `just_audio` |
| `audio_session` | `^0.1.14` | Tightly coupled to `just_audio` |

Safe to upgrade (UI/network/tooling only):
- `google_fonts`, `connectivity_plus`, `xml`, `flutter_launcher_icons`, `flutter_lints`

---

## Troubleshooting

### `cmdline-tools component is missing`

```bash
brew install --cask android-commandlinetools
sdkmanager --sdk_root=$HOME/Library/Android/sdk "cmdline-tools;latest"
```

### `Android license status unknown`

```bash
yes | ~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager \
  --sdk_root=$HOME/Library/Android/sdk --licenses
```

Or use Flutter's shortcut (after cmdline-tools are installed):
```bash
flutter doctor --android-licenses
```

### Gradle download fails (FileNotFoundException)

The `gradle-wrapper.properties` version may not exist. Check what's available:
```bash
curl -sI "https://services.gradle.org/distributions/gradle-X.Y.Z-all.zip" | grep HTTP
```

A `307` redirect means the version exists. Update `gradle-wrapper.properties` to use it.

If there's a stale partial download blocking things:
```bash
ls ~/.gradle/wrapper/dists/     # find the version dir
rm -rf ~/.gradle/wrapper/dists/gradle-X.Y.Z-all/<hash>/
```

### Device not showing in `adb devices`

- Make sure USB Debugging is on (Developer Options)
- Accept the "Allow USB Debugging" dialog on the device
- Try a different USB cable or port
- `adb kill-server && adb start-server`

### `storeFile not found` on release build

`key.properties` is missing from `kpfk_radio/android/`. Copy it:
```bash
cp android-signing/key.properties kpfk_radio/android/key.properties
```

---

## Known Android-specific behaviors

### Samsung Android 8.x — media button abort during load

**Symptom:** User presses the notification tray play/pause button while the stream is still
connecting/buffering. App shows "Stream playback error occurred." Logs show:
```
PlatformException(abort, Connection aborted, null, null)
OMX.SEC.mp3.dec: signalFlush
Bad state: Cannot fire new event. Controller is already firing an event
Reconnect exhausted after 3 attempts
```

**Root cause:** Samsung's native codec receives the media button event and directly flushes
the audio codec (`OMX.SEC.mp3.dec: signalFlush`). This is a platform-level interruption that
bypasses `just_audio`'s normal control flow. The resulting `PlatformException(abort)` was
previously treated as a network error, triggering 3 reconnect attempts that all immediately
abort, exhausting the retry budget and surfacing a false error to the user.

**Fix (2026-06-24):** `_isAbortError()` helper in `KPFKAudioHandler` detects `abort` /
`Connection aborted` exceptions. `_handleStreamError`, the `_reconnect()` catch block, and
the `play()` catch block all bail out early on abort errors instead of triggering reconnects.

**File:** `lib/services/audio_service/kpfk_audio_handler.dart`

---

### Notification tray controls persist after app close

**Symptom:** After swiping the app away from Android recents, the media notification
stays in the tray and controls remain active.

**Fix (2026-06-24):** Two parts.
1. `android:stopWithTask="true"` on the `AudioService` service in `AndroidManifest.xml`.
2. **The reliable part:** `KPFKAudioHandler.onTaskRemoved()` override that calls `stop()`.

`android:stopWithTask` ALONE is unreliable for a foreground media service on Android
8.x. The `onTaskRemoved()` → `stop()` override tears down playback and clears the
notification, and is the audio_service-canonical approach.

3. **`androidStopForegroundOnPause: false`** in `main.dart` (paired with
   `androidNotificationOngoing: false`). This was the final piece, proven by native
   logcat: with `true`, pausing drops the service out of the foreground. Swiping the
   app away then kills the now-background service BEFORE audio_service can dispatch
   `onTaskRemoved` to the Dart isolate — so `stop()` never runs and the notification
   is orphaned. Result: close-while-playing cleared the tray, close-while-paused did
   NOT. The native log of the failing case showed `Stopping service …: remove task` +
   `Killing …: remove task` with **no** `onTaskRemoved`/`Stop requested` line after the
   swipe. Keeping the service foreground through pause (`false`) makes `onTaskRemoved`
   fire reliably in both states.

   Safe for the lock screen: the lock-screen art blank was a separate `STATE_NONE`
   issue (see lock-screen-bug.md) fixed in `_broadcastState`, NOT dependent on this
   flag. An earlier round set this flag `false` and the lock screen still blanked only
   because `STATE_NONE` wasn't fixed yet.

**Files:** `android/app/src/main/AndroidManifest.xml` (`stopWithTask`),
`lib/services/audio_service/kpfk_audio_handler.dart` (`onTaskRemoved` override),
`lib/main.dart` (`androidStopForegroundOnPause: false`, `androidNotificationOngoing: false`).

**Diagnosis lesson (both this and the lock-screen bug):** `flutter run` logs only carry
`flutter`/skia/codec tags. The decisive evidence — `vol.MediaSessions: Removing KPFK`,
`MediaSessionRecord: setPlaybackState`, `ActivityManager: …remove task` — only appears in
full `adb logcat`. Capture native logs before theorizing.

---

## Maintenance history

| Date | Flutter | Gradle | Kotlin | Notes |
|------|---------|--------|--------|-------|
| 2026-06-24 | 3.41.6 → 3.44.3 | 8.13 → 8.14.2 | 2.1.0 → 2.2.20 | Initial keystore setup; fixed cmdline-tools; migrated to built-in Kotlin plugin; NDK → 28.2.13676358; Fixed notification abort storm + stopWithTask |
