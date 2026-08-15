# Android notice and debug-screen audit

**Audit date:** 2026-08-15

**App version:** `1.0.1+12`

**Scope:** Stream outage/connection notices, no-network alert, debug-only
Outage Testing screen, and their interaction with Android media notifications.

## Outcome

The Dart notice architecture passes its automated suite, both Android build
types compile, the release App Bundle contains none of the debug menu labels or
failure URLs, and Android release lint finishes with **0 errors**. Two classes
of Android lint defects were fixed during this audit. Physical Android testing
is deliberately still pending and is listed below as a reproducible handoff.

## Surfaces and ownership

| Surface | Purpose | Owner |
|---|---|---|
| `StreamNoticeModal` — outage | Confirmed station/server fault | `StreamRepository` → `StreamBloc` → `HomePage` |
| `StreamNoticeModal` — connection | Listener/network path could not reach a healthy stream | Same single notice channel |
| `NetworkLostAlert` | Device has no usable network | `ConnectivityCubit`, globally layered in `MaterialApp.builder` |
| Outage Testing | Real-pipeline presets and direct modal previews | Debug builds only via `kDebugMode` |
| Android media notification | Playback metadata and controls—not an outage-message surface | `audio_service` / `KPFKAudioHandler` |

The in-app notices and Android media notification are intentionally different
systems. Outage cleanup changes playback state, so device testing must still
confirm that the tray and lock-screen controls settle correctly when a notice
appears or is dismissed.

## Code-path audit

- The home-header bug icon and Settings developer entry are guarded by the
  compile-time `kDebugMode` constant.
- `DebugStreamOverride.url` is independently hard-gated by `kDebugMode`; even a
  future accidental release caller resolves to the real station URL.
- Selecting a preset dispatches `StopStream` so the next Play loads the chosen
  endpoint instead of resuming an old live source.
- Direct previews enter the same bloc state and render the same production
  modal as a detected fault.
- `StreamNoticeModal` uses a non-dismissible barrier with an interactive card.
  Outage exposes only **Got it**; connection exposes **Try again** and
  **Dismiss**.
- Playback-state churn cannot clear or synthesize a notice. Network recovery
  can explicitly clear a stale connection notice.
- Confirmed faults emit the listener notice before audio cleanup, and cleanup
  does not reload the failed endpoint.
- Playback failures use no snackbar or inline error card. Snackbars elsewhere
  in the project belong to unrelated WebView/sleep-timer/settings actions.
- No-network state is a separate global alert and is not mislabeled as a
  station outage.
- The Android manifest declares `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, and `POST_NOTIFICATIONS`; the audio
  service declares `foregroundServiceType="mediaPlayback"`.

## Defects fixed during this audit

### 1. Context-registered receiver compatibility and isolation

The dormant custom Samsung media fallback registered the private
`kpfk_media_action` receiver without an export flag. Apps targeting Android 14+
must specify export behavior for non-system context receivers. Registration now
uses `ContextCompat.RECEIVER_NOT_EXPORTED`, and both broadcast creation paths
set the app package explicitly.

This native fallback is not the production notification owner—the manifest
launches `AudioServiceActivity`, and Dart uses `audio_service`. Keeping dormant
native code lint-clean prevents it from becoming a crash/security defect if it
is reconnected later. A future cleanup may remove it in a separate commit after
Android device parity is recorded.

Official rule: [Android 14 behavior changes](https://developer.android.com/about/versions/14/behavior-changes-14#runtime-receivers-exported).

### 2. Launch-theme API lint errors

The base and night launch styles used API-27/API-29 framework attributes while
the app supports API 24. Their deliberate API levels are now annotated with
`tools:targetApi`. This preserves the existing launch appearance and makes the
compatibility intent explicit to Android lint.

## Automated and artifact evidence

Run from `kpfk_radio/` unless noted:

| Check | Result on 2026-08-15 |
|---|---|
| `flutter analyze` | Pass, no issues |
| `flutter test` | Pass, 59 tests; 1 intentional device-only skip |
| `flutter build apk --debug` | Pass |
| `flutter build appbundle --release` | Pass after fixes, 71.7 MB |
| `android/gradlew :app:lintRelease` | Pass, 0 errors / 24 warnings |
| Release `libapp.so` string scan | All debug labels/URLs absent |
| Debug APK control scan | Debug label and `127.0.0.1:9` present |

Release strings checked: `Outage Testing`, `Server refuses connection`,
`127.0.0.1:9`, `10.255.255.1/kpfk.m3u`, and `Show OUTAGE notice`.

The 24 lint warnings are non-blocking but retained as backlog evidence:

- Kotlin/Gradle and AndroidX version suggestions—do not mix upgrades into this
  notice fix.
- Portrait/large-screen policy warnings; Android 16 may ignore the lock on some
  large displays, so the tablet matrix below matters.
- Exported media-service warning inherited from the media-browser integration;
  review caller access when upgrading the audio stack.
- Unused/duplicate legacy notification and generated splash resources.
- Deprecated legacy MediaSession flags in the dormant Samsung fallback.
- Android SDK XML tool-version mismatch warning from a native dependency build.

## Android device/emulator matrix still required

Do not mark this audit device-complete until these are recorded with Android
version, API level, model/emulator profile, build mode, and pass/fail notes.

### Debug build: in-app UI and detection

- [ ] Confirm the bug icon appears in the header and opens Outage Testing.
- [ ] Preview OUTAGE: wording fits; **Got it** dismisses; background cannot be
      tapped through.
- [ ] Preview CONNECTION: **Try again** starts a fresh attempt; **Dismiss**
      closes without retry.
- [ ] Run refused, timeout, playlist-404, and no-stream presets through Play.
- [ ] Reset to Live; repeat play/pause and a natural rebuffer with no false
      notice.
- [ ] Press Android Back/predictive Back while each notice and debug
      confirmation is visible; record whether behavior is understandable and
      state remains recoverable.
- [ ] Repeat on a small phone, tablet/foldable, landscape if Android overrides
      portrait, and font scales 1.0/1.3/2.0. Check for overflow or inaccessible
      actions.
- [ ] Use TalkBack: verify initial focus, heading/body/action order, button
      labels, and that the notice is not announced twice (manual announcement
      plus modal semantics is a known risk to assess).

### Connectivity separation

- [ ] Airplane mode before Play: only `NetworkLostAlert`; play disabled.
- [ ] Restore network: alert and stale notice clear; Play works.
- [ ] Drop network during playback, then recover; no outage misclassification.
- [ ] If available, test captive-portal or TLS-intercepted Wi-Fi: connection
      notice, not station-outage wording.

### Media notification and lifecycle

- [ ] During normal Play/Pause, tray and lock-screen controls match the app.
- [ ] Trigger each notice while the tray is visible; confirm no stuck spinner,
      stale Playing action, duplicate notification, or orphaned notification.
- [ ] Dismiss/retry and recover; metadata and controls repopulate correctly.
- [ ] Background/foreground during detection and while a notice is visible.
- [ ] Swipe away while playing and paused; confirm audio and notification clear
      according to current product behavior.
- [ ] Repeat on Android 8.1/API 27 if still supported, Android 13/14, Android
      16/API 36, and at least one Samsung device.

### Release build

- [ ] Confirm no bug icon and no Settings developer entry.
- [ ] Repeat normal playback, no-network, and one real connection-fault path.
- [ ] Inspect Play internal-test/pre-launch results before promotion.

## Resume commands

```bash
cd /Users/paulhenshaw/Desktop/kpfk-app/kpfk_radio
flutter analyze
flutter test
flutter build apk --debug
flutter build appbundle --release
cd android && ./gradlew :app:lintRelease
```

After the final release build, repeat the release string scan documented in
`TESTING_outage_scenarios.md`. Never infer release exclusion only from the
source-level `kDebugMode` guard.
