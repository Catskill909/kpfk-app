# 🧭 Audio App-Bar Notification Disposal Plan (Android-only)

Date: September 24, 2025
Owner: Cascade
Status: Planning document (no code changes yet)

---

## 🎯 Goal
When the Flutter app is closed (backgrounded, task-swiped away, or terminated), the audio notification/tray controls should not linger in the device tray unless audio is actively playing. We must accomplish this without breaking existing working functionality:

- iOS lockscreen controls and metadata flow
- Samsung J7 / older Android notifications
- Sleep Timer behavior
- Network loss/recovery flows
- Server error paths

---

## 🔒 Scope (Android-only)
- All implementation work for this plan applies ONLY to Android.
- Every behavioral change will be strictly guarded by `Platform.isAndroid` checks.
- iOS production code MUST remain untouched, including:
  - `NativeMetadataService`
  - `AppDelegate.swift` / MPNowPlayingInfoCenter integrations
  - iOS lockscreen command routing

---

## 🧩 Current Architecture Snapshot

- **Audio handler:** `wpfw_radio/lib/services/audio_service/wpfw_audio_handler.dart`
  - `pause()` hides Samsung notification and releases focus
  - `stop()` hides Samsung notification, sets `mediaItem.add(null)` and idle state (fully clears tray)
  - `_broadcastState()` is the single source of `mediaItem.add()` and includes `MediaControl.stop` (X)
  - `customAction('dispose')` disposes the internal `AudioPlayer`

- **Repository (orchestration):** `wpfw_radio/lib/data/repositories/stream_repository.dart`
  - `stopAndColdReset()` does a full cleanup and can optionally preserve metadata
  - `stop()` calls `_audioHandler.stop()` and stops metadata
  - `dispose()` cancels streams, disposes services, and calls `_audioHandler.customAction('dispose')`

- **App bootstrap:** `wpfw_radio/lib/main.dart`
  - Calls `AudioService.init()` with `androidStopForegroundOnPause: true`
  - Wires iOS `NativeMetadataService` to the `WPFWAudioHandler`

- **Service locator:** `wpfw_radio/lib/core/di/service_locator.dart`
  - Creates singletons for `WPFWAudioHandler`, `MetadataService`, `StreamRepository`, etc.

---

## ⚠️ Problem Statement
When the user "closes" the app (e.g., swipes away from recent apps or the app is backgrounded/terminated), the audio tray controls remain visible in the Android notification area even when playback is not active.

This indicates we don’t have a guaranteed lifecycle-driven cleanup path that clears the notification and MediaItem when playback is not active.

---

## ✅ Desired Behavior Policy
- **If audio is playing and the app is closed:** Keep playing and keep the notification (normal background playback behavior).
- **If audio is paused/stopped and the app is closed:** Remove the notification entirely and clear the MediaItem so the tray is clean.

Notes:
- This mirrors mainstream audio app behavior and prevents a “stuck” tray when the user is not listening.
- iOS does not present a persistent notification tray like Android; iOS behavior is unaffected by the Android cleanup logic.

---

## 🔍 Root Cause Analysis (Likely)
- Flutter `dispose()` of app-level singletons is not guaranteed on task swipe/OS termination.
- Android can leave the foreground service notification visible if not explicitly told to hide/stop.
- Our current cleanup (`pause()`/`stop()`) is only invoked via explicit user action, not on app lifecycle exit paths.

---

## 🚀 Implementation Plan (Phased, Low-Risk)

### Phase 0 — Instrumentation (no behavior change)
- **Logs:** Ensure we have clear logs when the app moves through lifecycle states and when tray cleanup triggers:
  - Add logs around new lifecycle observer callbacks.
  - Verify existing logs in `WPFWAudioHandler.stop()` and `pause()` are sufficient.

### Phase 1 — Flutter-only Lifecycle Guard (Android-only)
- **Add an `AppLifecycleObserver`** (e.g., `WidgetsBindingObserver`) in a small service or in `main.dart` that listens for:
  - `AppLifecycleState.detached`, `AppLifecycleState.paused`
- On lifecycle to background/termination:
  - Platform guard: perform actions ONLY when `Platform.isAndroid == true`.
  - Query `getIt<WPFWAudioHandler>().playbackState.value.playing`.
  - If NOT playing, call a new orchestration method (or reuse existing):
    - Preferred: `getIt<StreamRepository>().stopAndColdReset(preserveMetadata: false)`
    - This will internally call `_audioHandler.stop()` and clear the MediaItem (removes tray), stop metadata, and reset state.

Why Phase 1 first:
- Pure Flutter, low-risk, does not require native changes.
- Immediate improvement for most exit cases (home button, app background, hot restart).

### Phase 2 — Android Native Hardening (edge cases, task swipe)
- In the Android layer that manages our Samsung MediaSession notification, ensure notification removal on app/task removal when not playing:
  - Implement hooks in the service (or notification manager) for `onTaskRemoved()` and `onDestroy()`.
  - On those events, if `isPlaying == false`, call `hideNotification()` and release the MediaSession.
- Optionally add a small MethodChannel to invoke a native cleanup when Flutter detects `detached` and not playing (belt-and-suspenders for OEM quirks).

Rationale:
- Some OEMs (older Samsung) behave differently on task swipe. Native hooks ensure cleanup even if Flutter lifecycle observers don’t fire.

### Phase 3 — Service/Config Review (no behavior change intended)
- Confirm `AudioService.init()` config is optimal (already includes `androidStopForegroundOnPause: true`).
- Ensure `WPFWAudioHandler` always exposes `MediaControl.stop` for the X button and that `stop()` performs a full tray removal via `mediaItem.add(null)`.
- Ensure `pause()` does not re-post a notification when paused.

### Phase 4 — Regression and Device QA
- Validate on Samsung J7 (Android 6–8), modern Android, and iOS.
- Validate against network and server error flows (below).

---

## 🧪 Regression Test Matrix

- **Android (Samsung J7 and a modern Pixel):**
  - Close app while playing → notification remains, audio continues.
  - Close app while paused → notification disappears.
  - Press Stop (X) → notification disappears immediately.
  - Sleep timer expiration → notification disappears and does not re-appear.
  - Network lost → audio reset occurs immediately, tray cleared. Bringing app back doesn’t resurrect tray unless user presses Play.
  - Server error path (`_handleServerError`) → tray cleared reliably.

- **iOS:**
  - Lock screen controls/metadata unaffected by Android changes.
  - App background/foreground transitions do not regress play/pause behavior.
  - Lock screen play when app inactive does not cause desync with main UI.

---

## 🔒 Non-Goals and Constraints
- Do not alter the proven iOS metadata path (MPNowPlayingInfoCenter via NativeMetadataService).
- Do not reintroduce multiple competing `mediaItem.add()` sources — keep `_broadcastState()` as the single source of truth.
- Preserve the DI/service locator boot pattern to avoid startup regressions.

---

## 🛠️ Proposed Code Touchpoints (for later implementation)
- `wpfw_radio/lib/main.dart`
  - Add lifecycle observer registration in `main()` or a small `AppLifecycleObserver` class.
  - Guard all lifecycle cleanup logic with `if (Platform.isAndroid) { ... }`.

- `wpfw_radio/lib/data/repositories/stream_repository.dart`
  - Optionally add `ensureTrayClearedIfNotPlaying()` that checks handler playing state and calls `stopAndColdReset(preserveMetadata: false)` if needed.

- Android native (Samsung MediaSession manager/service)
  - Add `onTaskRemoved()` and `onDestroy()` guards to call `hideNotification()` when not playing.

No immediate code changes are being made in this document — this is the approved plan.

---

## 📏 Acceptance Criteria
- Paused/stopped state + app closed → no lingering notification.
- Playing state + app closed → background playback and notification persist.
- iOS behavior and metadata remain unchanged and stable.
- No regressions in: sleep timer, network alerts, or server error cleanup.

---

## 🧰 Rollback Plan
- Phase 1 can be disabled by removing the lifecycle observer registration.
- Phase 2 native hooks can be guarded by a feature flag and reverted independently of Flutter changes.

---

## 📚 References
- `wpfw_radio/lib/services/audio_service/wpfw_audio_handler.dart` — `pause()`, `stop()`, `_broadcastState()`, `customAction('dispose')`
- `wpfw_radio/lib/data/repositories/stream_repository.dart` — `stopAndColdReset()`, `stop()`, `_handleServerError()`
- `wpfw_radio/lib/main.dart` — `AudioService.init()` and iOS Native handler wiring
- `wpfw_radio/lib/core/di/service_locator.dart` — construction order and singletons
