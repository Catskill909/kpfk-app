# Play Button Bug — Code Audit & Phased Fix Plan

## Symptoms (reported)
1. App backgrounded (not playing) → brought back → **play button stops working**, sometimes needs a full reboot to recover.
2. Tap play → **~2s delay** before the icon flips to pause and audio starts.
3. The spinner doesn't reliably appear on tap. **The spinner should always start on tap, regardless of cause.** The app should never sit on the play icon doing nothing.

The layout commit from "yesterday" (`adcc693` — portrait lock + responsive sizing) is **not** the cause. It only touched `main.dart` orientation and `home_page.dart` sizing. The real causes pre-date it but surface as a stuck/slow play button.

---

## Play-press flow (current)
```
Tap (home_page.dart:466)
  → setState(_showLocalLoading = true)        // spinner ON
  → StartStream  → StreamBloc._onStartStream
    → emit(errorMessage:null)                 // same playbackState
    → StreamRepository.play()
        → await checkServerHealth()           // BLOCKING HTTP GET (5s timeout)  ← delay
        → _updateState(connecting)            // only AFTER the await
        → await _audioHandler.play()
  → audio handler reports ready+playing
  → bloc emits playing
  → listener clears _showLocalLoading         // only on playing | error
  → icon flips to pause
```

---

## Root causes

### RC1 — Health-check cache poisoning  → "needs reboot"
- `StreamRepository.play()` runs a pre-flight `AudioServerHealthChecker.checkServerHealth()` before every play.
  - `lib/data/repositories/stream_repository.dart:207`
- The checker caches results — **including failures** — in **static** fields for **30s**.
  - `lib/core/services/audio_server_health_checker.dart:10` (`_cacheTimeout = 30s`)
  - `:129`, `:139`, `:152` set `_lastHealthResult = false; _lastHealthCheck = now`
- On resume from background the radio/network is cold; first health GET times out / connection-errors → caches `false`.
- For the next 30s every play press returns cached unhealthy → `_handleServerError` → `StreamState.error`, audio reset, no playback. Static cache survives until the process is killed → **"needs reboot."**
- Spinner flips to error almost instantly → looks like the button did nothing.

### RC2 — Pre-flight check is the 2s delay
- `play()` `await`s a full HTTP GET round-trip *before* `_updateState(connecting)` and `_audioHandler.play()`.
  - `lib/data/repositories/stream_repository.dart:200-237`
- `connecting` is emitted *after* the await (`:228`), so the BLoC shows no activity during the wait.
- just_audio already surfaces stream/connection errors itself; the pre-flight mostly just adds latency.

### RC3 — `isOnline` latches false on resume  → "play button stops working"
- `ConnectivityService.connectivityStream()` yields `false` on any 1.5s probe failure and only re-evaluates on the next `onConnectivityChanged` transport event.
  - `lib/core/services/connectivity_service.dart:61-78`
- Cold-radio probe on resume often fails → `isOnline=false`.
- Consequences:
  - Full-screen `NetworkLostAlert` overlay covers UI — `lib/main.dart:161`
  - Play `onTap` becomes a no-op — `lib/presentation/pages/home_page.dart:439`
- Nothing re-runs `checkNow()` on resume; the proactive check is gated on `firstRun` only (`main.dart:150`). No `WidgetsBindingObserver` watches `AppLifecycleState.resumed`.

### RC4 — Spinner clears on too few states
- Listener clears `_showLocalLoading` only on `playing` | `error`.
  - `lib/presentation/pages/home_page.dart:187`
- If playback settles to `paused`/`stopped`/stuck-`buffering`, spinner hangs until the 10s safety timeout (`_maxSpinnerDuration`, `home_page.dart:33`).

---

## Phased fix plan

Each phase is independent and individually shippable/testable. Order is by impact on the reported symptoms.

### Phase 1 — Stop the cache poisoning (fixes "needs reboot")  ⭐ highest impact ✅ DONE
**Files:** `lib/core/services/audio_server_health_checker.dart`
- ✅ Negative results are **never** cached — every failure path returns without writing the static cache. Only a healthy (2xx) result is cached.
- ✅ Positive cache window cut 30s → 5s; cache read is now success-only (`_lastHealthResult == true`).
- Resume-time `clearCache()` is deferred to Phase 3, where the `AppLifecycleState.resumed` observer is added (no observer exists yet).
- Acceptance: after a failed play, the very next tap re-checks the server (no 30s dead zone); killing/reboot no longer required to recover. ✅ Met by removing negative caching at the source.

### Phase 2 — Don't block play on the health check (fixes 2s delay + guarantees spinner activity) ✅ DONE
**Files:** `lib/data/repositories/stream_repository.dart`
- ✅ `play()` now sets `_updateState(connecting)` **first**, then calls `_audioHandler.play()` immediately. No blocking pre-flight GET.
- ✅ Health checker demoted to error *classification* on the failure path only: new `_handlePlaybackFailure()` tries `_classifyPlaybackError()` first and only probes the server when the cause is inconclusive.
- Acceptance: icon/spinner reflect activity instantly on tap; audio starts as soon as the stream connects, with no fixed pre-flight latency.

### Phase 3 — Re-check connectivity on resume (fixes latched `isOnline`) ✅ DONE
**Files:** `lib/main.dart`
- ✅ Added cross-platform `_AppResumeObserver` (registered for all platforms) that on `AppLifecycleState.resumed` calls `AudioServerHealthChecker.clearCache()` (deferred from Phase 1) and `getIt<ConnectivityCubit>().checkNow()`.
- Acceptance: returning from background with a healthy network clears `NetworkLostAlert` and re-enables the play button without a transport change.

### Phase 4 — Spinner clears on all settled states ✅ DONE
**Files:** `lib/presentation/pages/home_page.dart`
- ✅ New `_sawPlaybackProgress` flag: spinner clears immediately on `playing`/`error`, and on `paused`/`stopped`/`initial` only once an in-progress state (connecting/loading/buffering) has been observed — so the transient old-state emit at dispatch time can't kill the spinner early. Flag reset on each new play tap.
- Acceptance: spinner never outlives a settled playback state; 10s timeout becomes a true last resort.

### Phase 5 — Restore "server down" UX without the pre-flight delay ✅ DONE
**Files:** `lib/services/audio_service/kpfk_audio_handler.dart`, `lib/data/repositories/stream_repository.dart`
**Why:** The audio handler's `play()` catch **swallows** connect failures (`_handleError` + `_reconnect`, no rethrow), so a down server never throws back to `StreamRepository.play()`. After Phase 2 removed the blocking pre-flight check, a down server produced ~10s of silent spinner → play icon, no modal, plus a hidden 5s reconnect loop forever.
- ✅ **Connecting watchdog** in the repository: `play()` arms an 8s timer. If playback hasn't reached `playing`, it probes the server. Down → show error modal (`_handleServerError`) + `haltReconnect()`. Healthy-but-slow → keep waiting (no false modal). Cancelled on any settled state (`_updateState`) and in `dispose()`.
- ✅ **Reconnect gate** in the handler: new `_reconnectEnabled` flag + `haltReconnect()`. `_reconnect()` bails when halted (including the scheduled 5s re-fire); a fresh `play()` re-enables it. Stops the app hammering a dead server behind the modal.
- Watchdog (8s) fires before the home-page spinner safety timeout (10s), so the modal/error replaces the spinner cleanly.
- Acceptance: server down → "server unavailable" modal in ~8s, spinner cleared, no endless background retries; healthy server still starts instantly; retry/play re-arms everything.

### Phase 6 — Offline modal latches forever (CRITICAL — froze whole app) ✅ DONE
**Files:** `lib/core/services/connectivity_service.dart`, `lib/presentation/bloc/connectivity_cubit.dart`
**Repro:** Airplane Mode ON → offline modal (correct) → Airplane Mode OFF → **entire app frozen, play button dead.**
**Root cause:** `NetworkLostAlert` is a full-screen `AbsorbPointer(absorbing:true)` with no retry button (`network_lost_alert.dart:11`); it only dismisses when `isOnline` flips true. But `ConnectivityService.connectivityStream` re-probes internet only on an `onConnectivityChanged` event, with a single 1.5s probe. Airplane-off fires one event while the radio is still cold → probe fails → `yield false` → no further event → `isOnline` latched false → modal absorbs all input forever. The Phase 3 resume-observer can't help (toggling Airplane Mode doesn't background the app).
- ✅ **Resilient probe:** `hasInternet()` now retries (`_probeAttempts = 3`, 3s timeout, 0.8s gap) so a cold radio doesn't produce a false negative.
- ✅ **Recovery poll (guaranteed):** `ConnectivityCubit` starts a 3s `Timer.periodic` whenever it goes offline; each tick re-probes and, on success, emits `isOnline:true` and stops the poll — independent of any further transport-change event. Stopped when online and in `close()`; `_probing` guard prevents overlap.
- Acceptance: Airplane off (or any network return) clears the modal within a few seconds and re-enables the UI, even when no new connectivity event fires.

---

## ⚠️ STILL BROKEN after Phase 6 — failure log + standard-pattern research

**Reported again:** Airplane ON → OFF → play button does not function. Phases 3 and 6 did **not** fix it. Stop hand-rolling; adopt the patterns thousands of apps use.

### Failure log (do NOT retry these — they didn't work)
- ❌ **Phase 3 (resume observer `checkNow()`):** toggling Airplane Mode does **not** background/resume the app, so `AppLifecycleState.resumed` never fires. Irrelevant to this repro.
- ❌ **Phase 6 (resilient probe + hand-rolled recovery `Timer.periodic` in the cubit):** still broken on device. We are building on `connectivity_plus.onConnectivityChanged`, whose events are documented as unreliable; patching our own probe/poll on top keeps missing edge cases. Root tooling choice is wrong, not the tuning.

### Research findings (sourced)

**1. `connectivity_plus` is the wrong tool for "is there internet," by its own docs.**
- It reports **transport only**, not actual internet. WiFi present ≠ internet (captive portals, cold radio).
- Its event stream is explicitly **unreliable**: on iOS/macOS it uses `NWPathMonitor`, which emits `none` then `wifi` right after reconnect, "does not filter events, nor ensure distinct values."
- Known bug: ~1 in 12 times Airplane ON reports `wifi/mobile` instead of `none` (plus_plugins #290).
- Android O+: connectivity changes are **not delivered in the background**; docs say "always check connectivity when your app is resumed."
- It does **no polling** — if no transport-change event fires after Airplane OFF (transport stays "connected" the whole time), nothing re-checks. This is exactly our latch.

**2. Standard fix: `internet_connection_checker_plus`.**
- Purpose-built to verify *actual* internet by reaching multiple global endpoints (Cloudflare, Google, Apple, icanhazip); connected if any succeeds.
- Exposes a reliable status stream that does its own internal periodic checking — recovery does **not** depend on a flaky transport event:
  ```dart
  final sub = InternetConnection().onStatusChange.listen((status) {
    if (status == InternetStatus.connected) { /* online */ }
    else { /* offline */ }
  });
  ```
  One-off: `final ok = await InternetConnection().hasInternetAccess;`
- v3 is pure Dart (dropped its own `connectivity_plus` dependency); subsecond response times.
- This **replaces** our `ConnectivityService` probe AND the Phase 6 hand-rolled poll with a single battle-tested stream.

**3. just_audio does NOT auto-reconnect live radio streams on iOS after network loss (issue #1277).**
- Android (ExoPlayer) reconnects automatically; iOS (AVPlayer) does **not** for non-HLS radio streams (iOS 17+). `onItemStalled`/`onFailToComplete` fire but it never resumes on its own.
- Standard workaround: on network **recovery**, explicitly tear down and re-`setAudioSource()` then `play()` (recreate the source). Our handler's `_reconnect()` already does `setAudioSource` + `play`, but it's only triggered from a `play()` catch — not from a network-recovery signal while the user expects playback.

### Current package versions
- `connectivity_plus: ^6.1.3`, `just_audio: ^0.9.35`, `audio_service: ^0.18.12` (no internet checker yet).

---

## CORRECTED DIAGNOSIS (from user's device observation)

After Airplane OFF: **the modal removes itself, then the play button is dead.** This is decisive:
- ✅ **Connectivity recovery already works** — `isOnline` flips back true (modal auto-dismisses). Phase 6's poll did its job; the latch is fixed.
- ❌ **The real remaining bug is the audio pipeline**, not connectivity. After a network drop, just_audio's iOS AVPlayer item is dead (issue #1277) and the recovery branch was deliberately coded to do **nothing** to audio ("Network recovery only removes modal, doesn't touch audio"). So `play()` resumes a dead player → no sound. Exactly the user's suggestion: **reset the audio after connectivity is restored.**

### Phase 8 — Cold-reset audio on network recovery (the actual fix) ✅ DONE
**Files:** `lib/presentation/bloc/connectivity_cubit.dart`
- ✅ Refactored all connectivity updates (stream listener, recovery poll, `checkNow`) through one `_applyConnectivity()` so loss/recovery side-effects run no matter which path detects the change. (Previously the poll-driven recovery bypassed the transition handler entirely — a real gap.)
- ✅ `_onNetworkRecovered()` now calls `_streamRepository.stopAndColdReset(preserveMetadata: true)`. `resetToColdStart()` does `setAudioSource()` with a fresh URL → new AVPlayerItem → next `play()` works. Metadata preserved so show info/lockscreen don't blank.
- ✅ `_onNetworkLost()` keeps the existing pause.
- Acceptance: Airplane OFF → modal clears → tap play → audio starts cleanly (no reboot, no dead player).

### Phase 7 — (Optional, deferred) Replace custom connectivity with `internet_connection_checker_plus`
Not needed for the current bug (Phase 6 already recovers reliably per device observation). Worth doing later as hardening: `InternetConnection().onStatusChange` is the standard, polls internally, and would let us delete our hand-rolled probe-retry + recovery `Timer.periodic`. Track as tech-debt, not a blocker.

---

## Out of scope / verified-not-affected
- BLoC events/state shape (`stream_bloc.dart`) — fine as-is.
- Lock screen / `KPFKAudioHandler` / metadata services — untouched.
- Spinner *placement* (already fixed; see `spinner-placement-bug.md`).
- Layout/orientation commit `adcc693` — not a cause.

---

## Progress
- [x] Phase 1 — health-check cache (no negative caching; positive cache 30s→5s, success-only)
- [x] Phase 2 — non-blocking play (connecting-first; health check classifies failures only)
- [x] Phase 3 — connectivity on resume (`_AppResumeObserver`: clearCache + checkNow)
- [x] Phase 4 — spinner clear states (`_sawPlaybackProgress`-gated clear)
- [x] Phase 5 — server-down UX (8s connecting watchdog + reconnect gate)
- [x] Phase 6 — CRITICAL: offline modal latch (resilient probe + recovery poll)
- [x] Phase 8 — CRITICAL: cold-reset audio on network recovery (just_audio iOS #1277)
- [ ] Phase 7 — (deferred/optional) adopt internet_connection_checker_plus
