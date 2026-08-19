# audio-play-bug.md — "Plays the cache, then STOPS"

**Status:** Phases 1, 2, 5 IMPLEMENTED (2026-08-18) — **awaiting device verification (§7). Not cleared for release until §7 passes on a real iPhone.**
**Platform reported:** iOS (confirmed by user on-device).
**Date opened:** 2026-08-18
**Mandate being violated:** *When audio stops it resets, and the play button ALWAYS plays the live stream and NEVER the cache.*

---

## 1. The symptom

1. Open app, press play, audio streams fine.
2. Pause (or background the app) and leave it dormant for a while — minutes.
3. Return to the app, press play.
4. **A few seconds of stale audio plays — audio from when you paused, not live** — and then playback **stops dead**. No error, no modal, no reconnect. The button just flips back to "play".

This is a regression. It did not happen before the lock-screen work.

---

## 2. Root cause — confirmed by code, single line

`lib/services/audio_service/kpfk_audio_handler.dart`, in `play()`:

```dart
final bool sourceAlive = _player.audioSource != null &&
    _player.processingState != ProcessingState.idle;
if (Platform.isIOS && sourceAlive) {
  // RESUME IN PLACE — skip the rebuild
} else {
  // rebuild AudioSource from M3U
}
```

Introduced in **`bd82526` — "feat(audio): Implement instant reclaim of lock-screen Now Playing slot on play action"** (Tue Jun 23 2026). That commit was solving a real and different problem: on iOS, `await setAudioSource()` blocks ~2.5s, and during that gap iOS keeps the lock-screen Now Playing slot on the *previously used* audio app (Spotify/Music), whose art flashes before KPFK appears. The fix — resume in place instead of rebuilding — genuinely killed the flash.

**But `sourceAlive` is a lie.** It answers *"does an AVPlayerItem object still exist?"*. It does **not** answer *"is the TCP connection to the Icecast server still open and delivering live bytes?"* Those are completely different questions, and for a **live** stream only the second one matters.

### What actually happens on iOS during the dormant period

| | |
|---|---|
| App pauses / backgrounds | `AVPlayer.pause()`. `processingState` stays `ready`. `audioSource` stays non-null. |
| Minutes pass | iOS suspends the app's networking. Icecast drops the idle client (standard server-side idle timeout). The socket is dead. **But AVPlayer still holds the bytes it had already buffered.** |
| User presses play | `sourceAlive == true` → **resume in place** → AVPlayer plays out its stale buffer. **This is "the cache."** |
| Buffer exhausts (a few seconds) | Nothing behind it. Dead socket. AVPlayer reaches end-of-media. |
| just_audio reports | `ProcessingState.completed` |

That is the exact reported behavior, start to finish.

**Compounding it:** `pause()` on iOS was *deliberately* made non-destructive by the same lock-screen work — it does not release the session, does not clear the source, does not cold-reset. So the stale buffer is guaranteed to survive the dormant period intact and be sitting there waiting to be played.

---

## 3. Second bug — why it "STOPS" silently instead of recovering

Even granting the stale-buffer play, a correct radio app would notice the stream died and reconnect. This one does not. `ProcessingState.completed` is a **total dead end** in three consecutive layers:

**Layer 1 — `_handlePlayerState()` (handler):**
```dart
if (!state.playing && _player.processingState == ProcessingState.completed) {
  LoggerService.audioError('Playback ended unexpectedly');
  _handleError('Stream playback ended unexpectedly');
}
```
and `_handleError` is, in its entirety:
```dart
void _handleError(dynamic error) {
  LoggerService.audioError('Audio error', error);
}
```
**It only writes a log line.** No reconnect. No state change. No reset.

**Layer 2 — `_broadcastState()`** maps `completed` → `AudioProcessingState.completed` and pushes it.

**Layer 3 — repository's playback listener:**
```dart
case AudioProcessingState.completed:
  _updateState(StreamState.stopped);
  break;
```
`stopped` is treated as a **normal, successful, expected end of playback** — same as the user pressing stop. It cancels the connecting watchdog, clears `_awaitingPlay`, and raises **no notice**. The error modal never fires because nothing ever classified this as an error.

For an on-demand track, `completed` means "the song ended." **For a 24/7 live stream, `completed` is always a failure** — a live stream has no end. Treating it as a clean stop is categorically wrong.

Note also that `_reconnect()` is only ever reachable from `_handleStreamError` (the `playbackEventStream` `onError` hook) and from `play()`'s catch. A buffer-underrun-to-completion is **not** an error event on that stream, so the entire bounded-reconnect-with-backoff machinery — which is well built — is simply never invoked for this failure mode.

---

## 4. Why the watchdog doesn't save us

`_startConnectingWatchdog()` (8s) is armed on `play()` and cancelled by `_updateState` on **`playing`**. In this scenario the stale buffer genuinely *does* reach `playing` within a second or two — so the watchdog is cancelled as a success. There is **no** equivalent watchdog covering "we were playing and then playback ceased." Once we're past `playing`, nothing is watching.

---

## 5. Full inventory of contributing defects

| # | Defect | File | Severity |
|---|---|---|---|
| D1 | `sourceAlive` tests object existence, not stream liveness — resumes a dead connection's buffer | `kpfk_audio_handler.dart` `play()` | **Blocker** |
| D2 | `ProcessingState.completed` on a live stream is treated as a clean stop, not a failure | `stream_repository.dart` listener | **Blocker** |
| D3 | `_handleError()` only logs — every caller believes it handles something; it handles nothing | `kpfk_audio_handler.dart` | **Blocker** |
| D4 | ~~No app-lifecycle invalidation of the audio pipeline~~ — moot once `play()` always rebuilds | `main.dart` | Resolved by P1 |
| D5 | iOS `pause()` is non-destructive by design, preserving a stale buffer. Fixed by Phase 1 (pause = stop) | `kpfk_audio_handler.dart` / `stream_repository.dart` | High |
| D6 | No liveness watchdog once playback has started (only a pre-`playing` connect watchdog) | `stream_repository.dart` | High |
| D7 | `_resolveStreamUrl` fetches M3U with `http.get` and no timeout — can hang indefinitely on a half-open network after resume | `kpfk_audio_handler.dart` | Medium |
| D8 | `resetToColdStart()` calls `_player.pause()` + `seek(0)` + `setAudioSource` — it never calls `_player.stop()`, so it leaves a *loaded* source behind. A "cold start" that isn't cold feeds D1 | `kpfk_audio_handler.dart` | Medium |
| D9 | Live stream never sets `AudioSource` live/stall handling options; no explicit buffer policy for live playback | `kpfk_audio_handler.dart` | Medium |
| D10 | `seek()` is a no-op (correct) but `SeekHandler` mixin + `duration: 24h` still advertise a seekable timeline to iOS Control Center | `kpfk_audio_handler.dart` | Low |

---

## 6. Streaming standards this violates

Industry practice for **live** (non-seekable, continuous) audio:

1. **Pause on a live stream is semantically a stop.** There is no "resume" — the live edge has moved on. Every major radio app (TuneIn, iHeart, BBC Sounds, Radio Paradise) tears down and reconnects on play. Resuming a buffer replays the past, which is exactly the mandate violation here.
2. **Never present buffered-but-stale audio as live.** If the connection's liveness is unknown, reconnect. The cost is ~1–2s of buffering; the cost of getting it wrong is playing minutes-old audio and then dying.
3. **End-of-stream on a live source is an error condition**, always. It must route to reconnect-with-backoff, then to a user-visible failure — never to a silent "stopped".
4. **Connections must be assumed dead after backgrounding.** iOS suspends sockets; you do not get a callback telling you the stream rotted. Invalidate on foreground.
5. **Bounded exponential backoff with a user-visible terminal state.** (This app has this — it's just unreachable from the failing path.)
6. **All network fetches in the play path need timeouts.** A hanging M3U fetch is an infinite spinner.

---

## 7. The fix plan

### Phase 1 — Delete resume-in-place. Play always rebuilds live. — **BLOCKER**

**The app's mandate is absolute: the play button ALWAYS plays the live stream and NEVER the cache.** Any conditional resume — any staleness window, any timing heuristic — is a window in which cache can play. There is no correct value for that window, because elapsed time does not tell you whether the socket is alive: a 5-second-old pause can have a dead connection just as easily as a 5-minute-old one. The only implementation that satisfies "never" is one where resuming a buffer is not reachable.

In `KPFKAudioHandler.play()`, remove the branch entirely:

```dart
// DELETE this and the `sourceAlive` variable feeding it:
//   final bool sourceAlive = _player.audioSource != null &&
//       _player.processingState != ProcessingState.idle;
//   if (Platform.isIOS && sourceAlive) { /* resume in place */ } else { ... }

// play() unconditionally rebuilds from the live edge, all platforms:
_rebuildingSource = true;
try {
  final directStreamUrl = await _resolveStreamUrl(_streamUrl);
  await _player.setAudioSource(
    AudioSource.uri(Uri.parse(directStreamUrl), tag: _currentMediaItem),
  );
} finally {
  _rebuildingSource = false;
}
await _player.play();
```

**Pause is stop.** On a live stream there is nothing to resume to — the live edge has moved on. `pause()` should tear the source down so there is no buffer to inherit, and `play()` reconnects. This is what TuneIn, iHeart, and BBC Sounds do, and it is why they cannot exhibit this bug.

**Cost:** ~1–2s of buffering on play. That is the correct and unavoidable price of live audio.

**On the lock-screen flash:** `bd82526` used resume-in-place to hide the ~2.5s `setAudioSource()` gap during which iOS leaves the Now Playing slot on the previously-used app. That was the wrong lever — it traded a correctness bug for a cosmetic one. The right lever is already in the codebase: the native `reassertNowPlaying` pre-claim on the `com.kpfkfm.radio/metadata` channel, invoked at the top of `play()` before the rebuild. If a flash remains after Phase 1, strengthen that native pre-claim. **Under no circumstances reintroduce a conditional resume to suppress it** — a cosmetic flash is a cosmetic bug; playing minutes-old audio and dying is a broken product.

### Phase 2 — Treat `completed` as the failure it is — **BLOCKER**

**2a. Handler** — in `_handleProcessingState`, add a real branch:
```dart
case ProcessingState.completed:
  LoggerService.audioError('🎵 Live stream reached completed — stream died');
  if (_reconnectEnabled) _reconnect();
  break;
```
Remove the duplicated, log-only `completed` handling from `_handlePlayerState`.

**2b. Handler** — make `_handleError` do something, or delete it. Recommended: rename to `_logError` for the genuinely log-only call sites, and route real failure paths to `_reconnect()`/error state explicitly. The current name promises handling it does not deliver — that ambiguity is how D2 survived review.

**2c. Repository** — `AudioProcessingState.completed` must not map to `stopped`:
```dart
case AudioProcessingState.completed:
  // A 24/7 live stream has no end. Reaching `completed` always means the
  // stream died. The handler is already reconnecting; classify + surface
  // if that reconnect chain exhausts.
  LoggerService.warning('🎵 Live stream completed — treating as failure');
  _onPlayerError();
  break;
```

### Phase 3 — Lifecycle — **mostly moot after Phase 1**

With `play()` unconditionally rebuilding, there is no stale source to invalidate — the class of bug Phase 3 was guarding against no longer exists. Keep `_AppResumeObserver` as-is (health-cache clear + connectivity re-check on resume); no player interaction needed.

The one rule that still matters: **never touch a session that is actively playing in the background.** Background radio must keep running untouched.

### Phase 4 — Playing-liveness watchdog — High

The connect watchdog covers pre-`playing` only. Add its post-`playing` twin in `StreamRepository`: once state is `playing`, arm a periodic check; if the player reports `playing == true` but `bufferedPosition` has not advanced across two consecutive ~10s ticks, the stream is stalled — invalidate and reconnect. Cancel on any deliberate pause/stop.

This is the safety net that catches every *future* variant of "audio silently died", including ones we haven't found yet.

### Phase 5 — Harden the play path — Medium

- **D7:** `_resolveStreamUrl` → `http.get(...).timeout(const Duration(seconds: 6))`, with the existing fallback-to-original-URL behavior on timeout.
- **D8:** `resetToColdStart()` → call `await _player.stop()` first so it is genuinely cold, then set the source. Set `_sourceInvalidated = true`.
- **D9:** Consider `AudioSource.uri(..., )` with explicit live-appropriate buffer config; at minimum document the current defaults.
- **D10:** Drop the fake `duration: const Duration(hours: 24)` on the MediaItem, or keep it but verify Control Center shows no scrubber. A live stream should advertise no duration.

### Phase 6 — Tests

New `test/live_stream_resume_test.dart`:
- `play()` calls `setAudioSource` on **every** invocation — no path skips the rebuild
- `play()` rebuilds after a fresh pause (guards against reintroducing a resume window)
- `play()` rebuilds identically on iOS and Android — no platform branch
- `pause()` leaves no resumable buffered source behind

New cases in `test/outage_scenarios_test.dart`:
- `AudioProcessingState.completed` routes to the error/notice path, **never** to `StreamState.stopped`
- stalled-buffer watchdog fires reconnect when `bufferedPosition` is frozen while `playing`

### Phase 7 — Device verification (the only acceptance that counts)

Per prior sessions: **get device logs, do not guess.** On a real iPhone:

1. Play → confirm live audio. **PASS = audio is current, not replayed.**
2. Pause → wait **5 minutes** → play. **PASS = brief buffering, then LIVE audio, and it keeps playing.** FAIL = any stale audio, or any stop.
3. Pause → background app → wait 5 min → foreground → play. Same PASS criteria.
4. Play → background → confirm background playback continues uninterrupted for 5 min (**Phase 3 regression check**).
5. Quick pause → play within 5s → **confirm the lock-screen flash from `bd82526` has NOT returned.**
6. Play → enable airplane mode mid-stream → confirm reconnect attempts, then the notice modal (not silence).
7. Lock-screen play/pause buttons exercise all of the above.

---

## 8. Sequencing

Phase 1 and Phase 2 together fix the reported blocker and must land as one change — Phase 1 makes playing the cache structurally impossible, Phase 2 ensures that if the stream dies anyway, the app recovers loudly instead of failing silent. Phase 4 (stall watchdog) and Phase 5 (timeouts, genuine cold reset) close the remaining holes. Phase 6 locks it in with tests that fail if a resume window is ever reintroduced. Phase 7 gates the release.

---

## 9. Port to WBAI

WBAI is the same template and carries the same `bd82526` lineage. Once this is device-verified on KPFK, port Phases 1–5 verbatim to `/Users/paulhenshaw/Desktop/wbai-app/wbai_radio`.


---

## 10. Implementation log — 2026-08-18

Landed in one change. `flutter analyze` clean; full suite 65/65 green.

### Code changes

| File | Change |
|---|---|
| `kpfk_audio_handler.dart` `play()` | **Deleted the `sourceAlive` resume-in-place branch.** `play()` now rebuilds the AudioSource unconditionally, every invocation, every platform. Replaced with a long HISTORY comment recording why the branch existed (`bd82526`, lock-screen flash), why it was wrong, and the explicit instruction never to reintroduce it. |
| `kpfk_audio_handler.dart` `_handleProcessingState` | `ProcessingState.completed` now triggers `_reconnect()`, or raises an error playbackState when reconnect is halted. Was: one log line. |
| `kpfk_audio_handler.dart` `_handlePlayerState` | Removed the duplicate log-only `completed` handling that made the case *look* covered. |
| `kpfk_audio_handler.dart` `_handleError` | Doc comment now states plainly it is LOG ONLY and does not recover — the misleading name hid this bug for two months. |
| `kpfk_audio_handler.dart` `resetToColdStart` | `_player.stop()` instead of `pause()` + `seek(0)`, so a "cold" reset is actually cold (D8). |
| `kpfk_audio_handler.dart` `_resolveStreamUrl` | 6s timeout on the M3U fetch. Now that every play routes through here, an untimed GET could hang forever behind the spinner on a half-open network (D7). |
| `stream_repository.dart` playback listener | `AudioProcessingState.completed` → `_onPlayerError()` instead of `StreamState.stopped`. A dead stream now reaches the listener instead of failing silent. |

### Deliberately NOT changed

**`pause()` remains non-destructive on iOS.** With `play()` rebuilding unconditionally, the buffer a pause leaves behind is unreachable — nothing can play it — so the mandate is satisfied without touching pause. Keeping pause non-destructive preserves the paused lock-screen tile and the active audio session. Making pause destructive would clear `mediaItem` and drop the lock-screen entry while paused, regressing behavior the station wants.

Every playback entry point was traced before relying on this: in-app button, iOS lock-screen `remotePlay`, and `remoteTogglePlayPause` all route through `StreamRepository.play()` → `handler.play()`. There is no path that reaches `_player.play()` without a rebuild.

### Regression guard

`test/live_stream_always_rebuilds_test.dart` — 6 tests. It asserts on the handler *source*, not on a mocked player, because the invariant is structural: there must exist no conditional path through `play()` that skips the rebuild. A behavioral test would pass happily against a resume branch the mock never triggers.

It fails the build if anyone:
- removes `setAudioSource` from `play()`
- reintroduces `sourceAlive` or a "resume in place" path
- puts a `Platform.is*` condition in front of the rebuild
- gates the rebuild on elapsed time (`_pausedAt`, staleness windows)
- makes `completed` stop reconnecting, in either the handler or the repository

The guard strips `//` comments before asserting, so the HISTORY comment naming the old shape does not trip it.

### Why this kept coming back

Each recurrence had the same shape: someone chasing the ~2.5s iOS lock-screen Now Playing flash traded correctness for cosmetics, because the flash is *visible in five seconds* and the stale-cache failure only shows up after the app has been dormant for minutes. The flash gets noticed in dev; the cache bug gets noticed in production.

**The rule, stated once so it does not need re-deriving:** the lock-screen flash is a cosmetic bug and belongs to the native `reassertNowPlaying` pre-claim. Playing minutes-old audio and then stopping is a broken product. These are not comparable, and the trade is never worth making.
