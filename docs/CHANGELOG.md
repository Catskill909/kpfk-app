# KPFK Radio — Development History

The record of work done on the app, newest first. The front-facing
[README](../README.md) covers features and install; this file covers *what
changed and when*.

Dates are commit dates. Version numbers are `pubspec.yaml` `version:` values
(`marketing+build`). No git tags are in use — build numbers are the release
markers.

---

## Unreleased — after `1.0.1+12`

### Stream notices, outage testing, and Android audit (Aug 2026)

The largest block of work since the API-36 release. Error handling moved from
transient snackbars to a single acknowledged modal, and the failure paths behind
it became testable without taking the station off air.

- **Single stream-notice modal replaces error snackbars.** One persistent,
  acknowledged modal surface — no transient snackbars, no duplicate inline
  cards. The notice distinguishes a *confirmed station outage* from a
  *listener-side connection problem*, and offers **Try again** only when a retry
  can actually help.
  `stream_notice_modal.dart`, `domain/models/stream_notice.dart`
- **Fonts bundled locally.** Oswald and Poppins ship as assets (with OFL
  licenses) instead of being fetched at runtime by `google_fonts`, removing a
  network dependency from first paint. Covered by `bundled_fonts_test.dart`.
- **5xx misclassification fixed.** `audio_server_health_checker.dart` no longer
  reads server-side 5xx responses as listener connectivity failures. Added
  outage-scenario tests and golden coverage for both notice variants
  (`test/goldens/stream_notice_outage.png`,
  `stream_notice_connection.png`).
- **Debug outage panel.** Debug-only presets drive deterministic failures
  through the real playback pipeline, plus direct notice previews, reached from
  a bug icon in the home header. All of it is compiled out of release builds.
  `core/testing/debug_stream_override.dart`,
  `presentation/pages/debug_outage_page.dart`
- **Listener-first timeout response.** The notice now appears as soon as
  detection finishes, ahead of platform-audio cleanup, so the listener is not
  left watching a dead spinner.
- **Feedback email** corrected to `feedback@kpfk.org`; Xcode
  recommended-settings and archive-safety workflow documented.
- iOS `flutter_native_integration.env` fixed (`FLUTTER_TARGET` path, widget
  creation and icon-shaking settings).

Docs: [FEATURE_stream_offline_notice.md](../kpfk_radio/docs/FEATURE_stream_offline_notice.md) ·
[TESTING_outage_scenarios.md](../kpfk_radio/docs/TESTING_outage_scenarios.md) ·
[DEVICE_TEST_outage_2026-08-14.md](../kpfk_radio/docs/history/DEVICE_TEST_outage_2026-08-14.md) ·
[STREAM_OFFLINE_MODAL_AUDIT.md](../kpfk_radio/docs/history/STREAM_OFFLINE_MODAL_AUDIT.md)

### Android notice/debug audit — 2026-08-15

Preparatory audit ahead of Android device verification. **Static work is
complete; physical device verification is still outstanding.**

- `flutter analyze` clean; `flutter test` 59 passed with 1 intentional
  device-only skip.
- Debug APK and release App Bundle both build; debug-only labels and URLs
  confirmed absent from the release bundle.
- Android release lint improved from 5 errors / 24 warnings to **0 errors / 24
  warnings**.
- Private runtime receiver switched to `RECEIVER_NOT_EXPORTED` with
  package-scoped broadcasts.
- Launch-style API levels explicitly annotated for the API-24 minimum.

Still required: the Android device/emulator matrix (TalkBack, predictive Back,
font scaling, no-network recovery, media notification tray across every outage
transition), then the release matrix proving debug strings are absent.
See [ANDROID_NOTICE_DEBUG_AUDIT_2026-08-15.md](../kpfk_radio/docs/ANDROID_NOTICE_DEBUG_AUDIT_2026-08-15.md)
and [RELEASE-TODO.md](../kpfk_radio/RELEASE-TODO.md).

**Deliberately deferred:** removing the dormant native Samsung media fallback;
Kotlin/Gradle/AndroidX upgrades; portrait-policy changes; exported media-service
hardening; 16 KB native-library Play artifact certification.

---

## `1.0.1+12` — Jul 2026 · Android 16 (API 36) release

- Targeted **Android 16 / API 36** for Play Store compliance (`compileSdk` and
  `targetSdk` raised, Gradle config updated).
- Android `versionCode` now derives automatically from the git commit count, so
  build numbers cannot collide or regress.
- Release-build pass over logging, ProGuard rules, manifest, audio handler, and
  metadata service.
- "About Pacifica" drawer link pointed at `pacifica.org/about_mission`.
- Release checklist added at `kpfk_radio/RELEASE-TODO.md`.

See [api-target-android.md](../kpfk_radio/docs/api-target-android.md).

## `1.0.1+11` / `1.0.1+10` — Jul 9, 2026

- **Home station image is width-first.** The station artwork is sized from the
  available *width* and shrinks only as a last resort. Sizing it from leftover
  vertical space had repeatedly collapsed the image on smaller devices.
  See [main-screen-layout-fix.md](main-screen-layout-fix.md).
- Flutter environment configuration refresh; build mode returned to release.

## `1.0.1+9` — Jun 30, 2026

- Podcasts URL added to `StreamConstants` and surfaced as an app-drawer link.
- Drawer spacing adjusted.
- Removed unused `FlutterGeneratedPluginSwiftPackage` files.

## `1.0.1+8` — Jun 23–26, 2026 · iOS lockscreen and layout

- **Instant reclaim of the lockscreen Now Playing slot on play**, removing the
  gap where a previously-playing app's artwork flashed on the lockscreen.
- Improved playback handling and buffering-state management.
- Small-screen work: drawer and home-logo tuning, logo sizing and padding fixes.
- Adaptive icon documented; About URL updated; Twitter icon replaced with an SVG
  asset in the drawer.
- iOS housekeeping: stopped tracking auto-generated Flutter/Xcode files and
  `ios/Pods` (fixing `Manifest.lock` drift), podspec and environment config
  updates, `flutter_native_splash` plugin removed from the iOS side.
- Android `MainActivity` and `SamsungMediaSessionManager` cleaned up for
  readability.

Docs added in this window: iOS fixes, Xcode warnings, lock-screen image issues,
Android signing instructions rewritten for clarity.

## `1.0.1+6` — Jun 17–22, 2026 · Stream reliability

The reliability push that produced the outage-detection foundation.

- **Play button reliability plus network/server recovery** reworked.
- **Real Icecast outage detection**, surfacing a server-error modal instead of
  failing silently.
- **Standardized server-down detection** — ad-hoc workarounds removed in favor
  of `just_audio`'s `onError`.
- **Phase 10: bounded reconnect** with a mid-stream outage modal and tests
  (`reconnect_backoff_test.dart`).
- Home screen locked to portrait with improved responsive sizing.
- Playlist Archive option removed from the drawer.
- iOS: all iPad orientations enabled, full-screen requirement removed,
  `UIBackgroundModes` audio capability corrected, native asset dSYM generation
  script added.

## Mar 2026 · iOS warnings cleanup and first successful deploy

Multi-phase cleanup of the iOS build, tracked in
[ios-warnings.md](../kpfk_radio/docs/history/ios-warnings.md).

- **Phase 1**: fixed deprecated `allowBluetooth`, removed orphaned AppIcon PNGs,
  removed dead code, fixed a duplicate linker flag.
- **Phase 2**: Podfile aligned to iOS 13.0, `dart:ui` import fixed, phantom
  `wpfw_radio` Gradle warning removed, clean rebuild.
- **Phase 3A/3B**: `-Wl,-no_warn_duplicate_libraries` added to the Runner
  target, `flutter_native_splash` upgraded to 2.4.7, `url_launcher` constraint
  updated.
- Xcode recommended settings applied: deprecated embed-Swift flags removed,
  String Catalog generation enabled.
- Loading indicator moved inside the play button icon; home page refactor and
  spinner-bug investigation ([spinner-placement-bug.md](history/spinner-placement-bug.md)).
- First successful iOS deploy from this repo.

## Nov 2025 · Initial KPFK build

The app was created from the WPFW Radio codebase and re-skinned for KPFK.

- Initial commit from the WPFW code; all WPFW references replaced with KPFK.
- Bundle/package IDs set to `app.pacifica.kpfk`; Xcode project updated.
- Stream URL switched from a direct Icecast URL to the `.m3u` playlist; KPFK
  metadata feed URL wired up.
- New app graphics: launcher icon, splash screen, header image, feed image.
- Lockscreen artwork bug worked and fixed.
- Donate links corrected across several passes.
- First App Store upload and TestFlight push.
- Build hygiene: `.gitignore` updated to exclude `kpfk_radio` build output;
  retemplate steps and [git-hell.md](history/git-hell.md) written up.

See [TRANSFORMATION-SUMMARY.md](history/TRANSFORMATION-SUMMARY.md) and
[FINAL-STATUS.md](history/FINAL-STATUS.md).

---

## Inherited from the WPFW lineage (pre-repo, Sep 2025)

This work predates the KPFK repo — it arrived with the WPFW codebase the app was
built from, and is recorded here because the KPFK app still depends on it.

### iOS lockscreen audio controls — resolved (Sep 12, 2025)

- Fixed lockscreen play/pause buttons that were non-responsive.
- Resolved stuck loading states triggered by lockscreen controls.
- Audio commands routed through the `StreamRepository` singleton, giving
  lockscreen, in-app controls, and system audio interfaces a single source of
  truth.
- Native `MPNowPlayingInfoCenter` updates via platform channel, debounced to
  avoid churn; `MPRemoteCommandCenter` handlers wired through to the
  `KPFKAudioHandler` (play/pause/toggle).
- Verified: VoiceOver reads the current show/song on the lockscreen and controls
  operate playback without flicker.

Full system reference:
[iOS_LOCKSCREEN_METADATA_MASTER.md](../kpfk_radio/docs/iOS_LOCKSCREEN_METADATA_MASTER.md)

### Accessibility baseline (Sep 5, 2025)

Non-visual changes only:

- Play/pause control labeled and operable with TalkBack and VoiceOver.
- Live announcements for playback transitions (Loading, Buffering, Playing,
  Paused) and error states.
- Loading spinner marked as a live region, so "Loading audio" is announced
  without moving focus.
- Donate sheet: labeled close button, page-loaded announcement, and an
  announcement before handing off to the external browser.

### Typography and version management

- Custom typography via Google Fonts (Oswald and Poppins) — later replaced by
  locally bundled font assets in Aug 2026.
- Automated version management using `cider`; see
  [VERSION_MANAGEMENT.md](../kpfk_radio/docs/VERSION_MANAGEMENT.md).

---

## Open Items

### 🔑 Release keystore password is in public git history — deferred by decision

`android-signing/SIGNING-INSTRUCTIONS.md` is tracked in git and contains the
release keystore password in plaintext. It entered history in commit `386014c`
and is public on `github.com/Catskill909/kpfk-app`.

- **Not exposed:** the keystore itself. `*.jks` and `key.properties` are
  gitignored and have never been committed, so the password alone cannot sign
  anything.
- **Status:** reviewed 2026-08-15 and **deliberately left as-is.** Remediation
  requires either a history rewrite and force-push, or a Play Console upload-key
  reset — both disruptive relative to the actual risk.
- **If revisited, the options are:** strip the credentials from the doc going
  forward (history retains them); rewrite history with `git filter-repo` and
  force-push; or rotate the upload key through Play Console.

*Re-check this item whenever the signing docs or the README set are revised.*

## Backlog

- Complete the Android device/emulator verification matrix (see
  [RELEASE-TODO.md](../kpfk_radio/RELEASE-TODO.md)).
- Accessibility: focus traps in modals, `MergeSemantics` for metadata blocks,
  contrast and tap-target audits, dev-only a11y tooling.
- CI accessibility checks and widget tests for semantics.
- Dark-theme contrast and typography to AA.
- Remove the dormant native Samsung media fallback in a separate,
  device-verified cleanup.
