# KPFK Radio — Development History

The record of work done on the app, newest first. The front-facing
[README](../README.md) covers features and install; this file covers *what
changed and when*.

Dates are commit dates. Version numbers are `pubspec.yaml` `version:` values
(`marketing+build`). No git tags are in use — build numbers are the release
markers.

---

## `1.0.2+14` — Aug 19, 2026 · on TestFlight, Ready to Submit

Ships the live-stream blocker fix from 2026-08-18 plus the release-prep work
below. Validated by Xcode and processed by App Store Connect; awaiting an Apple
agreement signature (Account Holder) before external distribution.

### Release prep (2026-08-19)

- **Version `1.0.1+12` → `1.0.2+13` → `1.0.2+14`.** `+13` was **rejected** (see
  below) and re-cut as `+14`. Note `Generated.xcconfig` must be regenerated with
  `flutter build ios --config-only` after any pubspec version change — Xcode
  Archive otherwise keeps stamping the old build number.
- **`NSMicrophoneUsageDescription` removed, then restored.** Removing it caused
  the `+13` rejection (**ITMS-90683**). It is mandatory: `audio_session` and
  `flutter_inappwebview_ios` reference microphone APIs, and Apple scans embedded
  frameworks, not just the app binary. Restored with an explanatory purpose
  string — a dismissive one invites an App Review 5.1.1 question instead.
  Now guarded by `test/info_plist_required_keys_test.dart`.
- **iOS deployment target `13.0` → `15.0`** (Xcode project + Podfile + a fresh
  `pod install`), clearing **ITMS-90068** ahead of Apple's Spring 2027 deadline.
  `Podfile.lock` moved no pod versions, and the release build was clean. No
  devices dropped — iOS 15 supports the same hardware as iOS 13.
- **`ITSAppUsesNonExemptEncryption=false` added**, so App Store Connect stops
  prompting the export-compliance question on every upload.
- **`BGTaskSchedulerPermittedIdentifiers` removed** — `BGTaskScheduler` is used
  nowhere. `UIBackgroundModes: audio` retained; it is load-bearing.
- **Keystore password removed from the repo** — see Open Items below.
- **New docs:** [production-readiness-audit.md](production-readiness-audit.md)
  (full release audit, incl. the outstanding Android 13+ notification blocker)
  and [xcode-archive-warnings.md](xcode-archive-warnings.md) (baseline of the
  ~40 third-party deprecation warnings every archive emits).

### Live stream always plays live, never the cache (2026-08-18) — RELEASE BLOCKER, FIXED

On iOS, pressing play after the app had been dormant played several seconds of
stale buffered audio and then stopped dead — no error, no reconnect, no modal.
This violated the app's core mandate: **the play button ALWAYS plays the live
stream and NEVER the cache.**

- **Root cause: a resume-in-place fast path in `play()`**, gated on `sourceAlive`
  (`audioSource != null && processingState != idle`). That tests whether an
  AVPlayerItem *object* exists, not whether the socket is still delivering live
  bytes. After dormancy iOS suspends networking and Icecast drops the idle
  client — the socket is dead, but AVPlayer still holds already-buffered bytes.
  Resuming replayed those bytes, then hit `ProcessingState.completed` when they
  drained. Introduced in `bd82526` (Jun 23) to hide the ~2.6s lock-screen flash.
- **`play()` now rebuilds the AudioSource unconditionally**, every platform,
  every press. No staleness window: elapsed time is not a liveness signal, so
  any window is a window in which the cache plays.
- **`completed` on a live stream is now treated as a failure**, not a clean
  stop. A 24/7 stream has no end. It triggers reconnect in the handler and
  routes to the error classifier in the repository — previously it mapped to
  `StreamState.stopped`, identical to the user pressing stop, which is why the
  failure was completely silent.
- **`_handleError` documented as LOG ONLY.** The name implied recovery it never
  performed, which is how this hid for two months.
- **6s timeout on the M3U fetch**, now that every play routes through it.
- **The flash fix never needed resume-in-place.** The native `reassertNowPlaying`
  pre-claim added in the same commit is sufficient alone — device-verified by
  switching repeatedly between Spotify/Music and KPFK with the rebuild
  unconditional. Measured cost of always rebuilding: **~1.5s play→Ready**, under
  the ~2.6s that motivated the shortcut.
- **Android audit**: reverted an over-tightening (`resetToColdStart` using
  `stop()`) that blanked the Android notification on the metadata-preserving
  network-recovery path, and guarded `_reconnect()`'s source rebuild with
  `_rebuildingSource` so reconnects no longer flash the lock screen — which
  matters more now that `completed` routes there.
- **Regression guard**: `test/live_stream_always_rebuilds_test.dart` fails the
  build if a resume path, platform gate, or staleness window is reintroduced, or
  if `completed` stops triggering recovery. Verified to fire by reintroducing
  the bug.

Device-verified on iPhone 17 Pro / iOS 26.6: 7 plays, all live, zero failures —
including the blocker scenario (pause → 7m51s dormant → play). **Android device
testing still outstanding.** Full analysis: [audio-play-bug.md](audio-play-bug.md).
Master record updated: [lock-screen-bug.md](lock-screen-bug.md).

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

### 🤖 Android 13+ never requests notification permission — BLOCKER for the Play release

`POST_NOTIFICATIONS` is declared but never requested at runtime, and
`audio_service` does not request it either. From Android 13 it is denied by
default, so the foreground service runs while its notification — the media
control surface — is suppressed. Affects both apps. **Test on the API 36
emulator**; the Samsung SM-S737TL is API 27, where the permission is granted at
install and the bug cannot appear. Detail in
[production-readiness-audit.md](production-readiness-audit.md) §B2.

### 📋 Deferred, non-blocking

- **A1 — ATS.** `NSAllowsArbitraryLoads` is on although all production URLs are
  HTTPS. Left as-is for `1.0.2+14` (it already passed review); scope it to
  `NSAllowsArbitraryLoadsInWebContent` next cycle, then retest the donate,
  archive, and schedule WebViews.
- **H4 — startup `paramErr (-50)`.** The audio session is activated in `_init()`
  before iOS permits foreground audio. Harmless — `play()` re-activates
  successfully — but noisy. WBAI already has the fix (configure only, activate
  on play); port it back and re-verify lock-screen controls on Android, since
  the startup activation was originally a Samsung fix.
- **UIScene lifecycle** — Flutter warns it will be required on upcoming iOS
  versions. Framework-level; arrives via a Flutter upgrade.
- **Dependency upgrades** — `just_audio` and `audio_session` are behind, and are
  exactly the layer verified on device. Upgrade early next cycle with a full
  device retest, never immediately before a release.

### 🔑 Release keystore password — removed from the working copy 2026-08-19

`android-signing/SIGNING-INSTRUCTIONS.md` contained the release keystore
password in plaintext, in four places, on a public repo
(`github.com/Catskill909/kpfk-app`). **All four were removed on 2026-08-19**,
replaced with pointers to the password manager, and the file now carries a
security note.

- **Redaction does not undo the exposure.** The password remains in git history
  and in any clone or fork made while it was present. Treat it as permanently
  public.
- **Still not exposed:** the keystore itself. `*.jks` and `key.properties` are
  gitignored and have never been committed, so the password alone cannot sign
  anything.
- **Full remediation, if wanted:** rotate via a Play Console **upload key reset**
  — supported, does not require a new listing, does not affect existing
  installs. A history rewrite alone would not recall existing clones.
- **Status:** working copy clean; rotation not done, and not required for
  release.

## Backlog

- Complete the Android device/emulator verification matrix (see
  [RELEASE-TODO.md](../kpfk_radio/RELEASE-TODO.md)).
- Accessibility: focus traps in modals, `MergeSemantics` for metadata blocks,
  contrast and tap-target audits, dev-only a11y tooling.
- CI accessibility checks and widget tests for semantics.
- Dark-theme contrast and typography to AA.
- Remove the dormant native Samsung media fallback in a separate,
  device-verified cleanup.
