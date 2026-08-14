# Stream-Offline Modal — Full Flow, Fixes & Code Audit (KPFK)

**Date:** 2026-07-26 · **Apps:** KPFK + WBAI (identical template, same fixes)
**Trigger:** A real Icecast outage went up-and-down repeatedly, exposing modal
dismissal + snackbar bugs. Fixes were developed with the WBAI sister app and
applied identically here. See WBAI's `docs/STREAM_OFFLINE_MODAL_AUDIT.md` for the
full annotated flow diagram — this file is the KPFK-specific copy.

**KPFK differences from WBAI:** KPFK is **dark-only** (no light theme), so the
modal is styled for dark surfaces with the **KPFK brand-red accent**
(`0xFFE53935`) instead of WBAI's blue. KPFK did *not* have WBAI's black-on-dark
contrast bug (its `bodyMedium` is white), but shared the copyWith + snackbar
bugs below.

---

## What the user sees
- **Live outage** → full-screen `AudioServerErrorModal`: "We'll be right back",
  friendly copy, red badge + "Got it" button. Raw reason only as a muted detail.
- **Transient blip** → floating snackbar "Stream unavailable — please try again
  shortly" + Retry. Never both at once.

## Flow (summary)
`StreamRepository._handleServerError` fires **two** channels — `stateStream`
(→ `UpdatePlaybackState(error)`, `isServerError:false`) and `serverErrorStream`
(→ `ServerErrorOccurred(msg)` → `showServerErrorModal:true`). The bloc guards so
the generic bridge can't clobber the modal; `home_page` hides any raced snackbar
while the modal is up. Dismiss → `ClearServerError` clears repo + bloc state.
Reconnect is **halted** on server-confirmed-down, so no modal loop — it only
returns if the user presses play/retry while still down (correct).

## Bugs found & fixed (this session)
### Bug A — modal/snackbar wouldn't clear after "Got it"
`StreamBlocState.copyWith` used `errorMessage ?? this.errorMessage`, so
`copyWith(errorMessage: null)` **kept the stale message** → snackbar re-fired
after dismiss. **Fix:** `_noUpdate` sentinel so an explicit `null` truly clears.
(`presentation/bloc/stream_bloc.dart`)

### Bug B — snackbar stranded behind the modal
If `UpdatePlaybackState(error)` arrives before `ServerErrorOccurred`, the
snackbar shows then the modal covers it. **Fix:** `home_page.dart` calls
`hideCurrentSnackBar()` whenever `showServerErrorModal` is true.

### Earlier this session (UI/UX rebuild)
Modal rebuilt self-styled with friendly copy, red accent, raw error demoted to a
detail line; snackbar gated on `!showServerErrorModal` with matching styling.

## Audit findings (verified sound)
- No infinite modal loop — reconnect halts on server-down.
- copyWith sentinel safe for all callers (only `_onStartStream` /
  `_onClearServerError` pass explicit null, both intend to clear).
- Modal can't be clobbered (`_onUpdatePlaybackState` early-returns while up).
- Dismiss fully resets repo + bloc state.

## If it recurs — checklist
1. Modal won't dismiss / re-fires on its own → check `haltReconnect()` fires and
   `copyWith` still has the `_noUpdate` sentinel.
2. Snackbar behind modal → confirm the `if (showServerErrorModal)
   hideCurrentSnackBar()` guard is first in the BlocListener.
3. Both modal + snackbar → the `!showServerErrorModal` snackbar guard was removed.
4. Reproduce without an outage: dispatch `ServerErrorOccurred('test')`. **Never**
   hardcode `showServerErrorModal:true` into the initial state (undismissable).

## Deep audit v2 (2026-07-26) — single source of truth + dismiss latch
A second live outage (dead `.m3u`) showed one outage was surfaced through THREE
UI surfaces (modal, snackbar, **inline error `Card`** with no modal guard) fed
by TWO redundant channels, and that "Got it" didn't stick because the reconnect
loop kept re-raising the modal. Fixes (ported from WBAI, identical bug):
- `stream_bloc.dart`: generic error bridge no longer attaches the noise string
  `'Stream playback error occurred'`.
- `home_page.dart`: inline error `Card` guarded with `&& !showServerErrorModal`.
- `stream_repository.dart`: `_serverErrorDismissed` latch — `clearServerError()`
  sets it + calls `haltReconnect()`; `_handleServerError()` early-returns while
  latched; `play()` clears it.

Net: the modal is the single authoritative outage UI; snackbar/card only show
for non-server action failures. See WBAI's audit doc §5b for the full write-up.

## Deep audit v3 (2026-07-26) — THE real dismiss blocker: AbsorbPointer
After v2 the snackbar/card were gone but the modal still wouldn't dismiss. Cause:
`AudioServerErrorModal` wrapped its whole subtree — including the "Got it"
button — in `AbsorbPointer(absorbing: true)`, which swallowed the button's own
taps. Fixed by rebuilding the modal as a `Stack` of siblings: a
`Positioned.fill(ModalBarrier(...))` scrim behind + `Center(card)` on top
(fully interactive). Also added a post-`await` re-check of `_serverErrorDismissed`
in `_handleServerError()` to close the mid-handling dismiss race. Each play after
dismiss already re-polls fresh (health cache cleared, `.m3u` re-resolved).
**Lesson:** if a modal won't dismiss, check for `AbsorbPointer`/`IgnorePointer`
around the button before auditing state. See WBAI audit doc §5c.

## Files touched
- `presentation/widgets/audio_server_error_modal.dart`
- `presentation/bloc/stream_bloc.dart`
- `presentation/pages/home_page.dart`
- `stream-offline-modal.md` (root, short changelog)

`flutter analyze` clean on all changed files.

---

## Deep audit v4 (2026-08-14) — silent failures, and one surface for real

A pre-release audit of the whole notification path found the previous design was
still telling the listener **nothing at all** for a large class of failures.

### Bug D — the silent failure (the important one)
v2 removed the `'Stream playback error occurred'` string from the generic error
bridge, and the `_noUpdate` sentinel made `copyWith` *explicitly clear*
`errorMessage` on every playback-state tick. Together those meant `errorMessage`
was only ever non-null while the modal was already up, or from the bloc's own
try/catch — and since `AudioHandler.play()` swallows its exceptions instead of
rethrowing, `_repository.play()` almost never throws. **The snackbar was
effectively unreachable.**

Concretely, three paths set the error state and emitted no message whatsoever:
`_onConnectingTimeout`'s `NetworkConnectivityException` catch,
`_handlePlaybackFailure`'s tail, and `_onPlayerError` (both its network catch
and its "server probes healthy" branch). Symptom: tap play → spinner runs 8s →
spinner stops → nothing. No modal, no message, no explanation.

Worst realistic trigger: captive-portal Wi-Fi (hotel/airport) doing TLS
interception → `DioExceptionType.badCertificate` → `NetworkConnectivityException`.
`NetworkLostAlert` doesn't cover it either, because `ConnectivityService`'s probe
accepts any 2xx/3xx and a captive portal's 200 login page reads as "online".

**Fix:** every one of those paths now emits `StreamNotice.connection()`.

### The rework
- **No snackbars, anywhere.** They self-dismiss; the one explanation a listener
  gets disappears if they looked away. Deleted.
- **Inline error `Card` deleted.** It duplicated the snackbar's text *and* its
  Retry action, and it sat inside the home Column **without being counted in
  `spaceLeftForImage`**, so it shrank the station image whenever it appeared.
- **`errorMessage` deleted from bloc state.** With the snackbar and card gone it
  had no consumer, which retires the whole `_noUpdate` sentinel class of bugs
  (Bug A). State now carries a single `StreamNotice? notice`; `copyWith` spells
  clearing out as `clearNotice: true` rather than a null sentinel.
- **Two channels collapsed to one.** `serverErrorStream` + the generic state
  bridge → one `noticeStream` carrying `StreamNotice?`. `UpdatePlaybackState`
  no longer carries error text at all, so it *structurally cannot* clobber a
  notice — the guard that used to do that job is gone.
- **Two variants** (`outage` / `connection`) so a network fault isn't
  mislabelled as a station outage. Retry appears only on `connection`.

### Adjacent bugs found and fixed in the same pass
- `retry()` called `stop()` (which halts metadata polling) and `play()` never
  restarted it → show name/host froze after every retry. Now calls
  `restartMetadataService()`. Newly important: "Try again" is a real button now.
- Metadata `onError` did `_updateState(StreamState.error)` → a transient
  show-info fetch failure knocked the play button out of its playing state
  mid-stream. Now logs only.
- `stopAndColdReset` didn't clear `_awaitingPlay` (WBAI already did). Latched
  true, the next `ready && !playing` maps to `buffering` → a spinner that never
  resolves. Ported.
- WBAI `widget_test.dart` failed in `setUpAll` (SharedPreferences has no
  platform channel headless) — whole suite red. Added
  `SharedPreferences.setMockInitialValues`.

### Verified
`flutter analyze` clean and `flutter test` green in both apps (KPFK 23 passed,
WBAI 35 passed, 1 skipped each — the pre-existing device-only smoke test).
New `test/stream_notice_test.dart` guards the notice state machine.

### If it recurs — checklist
1. Notice won't dismiss → check `haltReconnect()` fires and `clearNotice: true`
   is used (never `notice: null`, which `copyWith` treats as "leave unchanged").
2. Notice never appears for a network fault → check the emit calls in
   `_emitConnectionNotice` callers; that's the silent-failure regression.
3. Two messages at once → something reintroduced a snackbar or inline card.
   Don't. See `no-snackbars` in the feature doc.
4. Reproduce without an outage: emit `StreamNotice.connection()` on
   `noticeStream`. **Never** hardcode a notice into the bloc's initial state.
---

## Deep audit v5 (2026-08-14) — scenario coverage, and a live misclassification

Writing the scenario matrix immediately caught a real bug.

### Bug E — every 5xx blamed the listener's internet
`checkServerHealth` probed with `validateStatus: (status) => status != null &&
status < 500`, so Dio threw on any 5xx *before* the status-code branching ran.
That made two branches of the classifier unreachable dead code — `statusCode ==
503` and the generic 5xx case — and routed every 5xx into
`NetworkConnectivityException`, i.e. the **connection** notice.

Net effect: an overloaded Icecast returning **503**, one of the most ordinary
outage modes a radio station has, told the listener to check their own internet
connection while the station was the thing that was down. Same for a 5xx from
the `.m3u` host. Fixed by accepting every status so the classifier's own
branches decide, in both the mount probe and the playlist fetch.

### Testability seam
`StreamBloc` now depends on a `StreamSource` interface that `StreamRepository`
implements. Production wiring is unchanged; it exists so the bloc can be driven
by a fake, since the real repository builds a just_audio player in its
constructor and cannot run headless. This is what makes the "stays quiet when
nothing is wrong" half of the matrix testable at all.

### Coverage added
- `outage_scenarios_test.dart` — 17 scenarios, split into "the listener IS
  warned" and "the listener is NOT warned". The second group is the point:
  healthy start, rebuffering blips, pause/resume, bare error states and metadata
  updates must all raise nothing.
- `audio_server_health_checker_test.dart` — 503, 403, timeout, playlist 5xx,
  captive-portal bad certificate, and proof that a failure is never cached.
- `stream_notice_modal_golden_test.dart` — both variants rendered to PNG with
  real Oswald/Poppins and the MaterialIcons badge, plus tap tests guarding the
  old `AbsorbPointer` regression.
- `widget_test.dart` — moved `setupServiceLocator()` out of `setUpAll` and into
  the (skipped) test body. `setUpAll` runs even for skipped tests, so it was
  spinning up audio_service/AudioSession for nothing and intermittently failing
  the whole suite under parallel load.

See `TESTING_outage_scenarios.md` for the fault→notice table and the recipes for
reproducing each outage on a device.
