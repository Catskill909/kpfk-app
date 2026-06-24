# Lock-Screen "Previous App Flashes On Play" Bug — Master Record

> Purpose: stop the error-loop. This is the single source of truth for the iOS
> lock-screen flash bug. Every attempt (and why it failed) is recorded here so we
> never repeat a failed approach. **Append to this doc; do not delete history.**

Last updated: 2026-06-23

---

## ✅ RESOLVED (2026-06-23, confirmed on device)

**Root cause (proven by device logs, not theory):** on iOS, `KPFKAudioHandler.play()`
*always* rebuilt the audio source via `await _player.setAudioSource(...)`, which
**blocks ~2.3–2.6 seconds** connecting + buffering a fresh live AVPlayerItem. iOS
only hands an app the lock-screen "Now Playing" slot once it is *actually playing
audio* — so during that 2.6s gap the previously-used app (Spotify/Music) kept the
slot. **That gap is the flash.** Setting `nowPlayingInfo`/artwork could never fix
it (the slot follows playback, not metadata) — which is why every metadata/reclaim
attempt (#4, #7, #8) failed.

**The fix:** in `KPFKAudioHandler.play()`, when the player source is still alive
(we were *paused*, not stopped → `processingState != idle`), **resume in place**
(`_player.play()` only — no `setAudioSource`). Playback restarts in milliseconds,
KPFK claims the slot instantly, and there is no gap for the other app to fill.
Only rebuild the source after a real stop (idle / cold start) or on Android.

**Tradeoff (accepted):** a resumed pause continues from the buffer (a second or two
behind live) instead of a fresh reconnect. Fine for radio; a long/dead pause still
rebuilds or hits the reconnect path.

**How it was found:** ran a debug build on the device and read live timestamped
logs (after 8 blind attempts). The smoking gun: `Play pressed 22:23:56.039` →
`setAudioSource returns 58.618` = 2.58s with no KPFK audio.

**Files changed:** `lib/services/audio_service/kpfk_audio_handler.dart` (`play()`
resume-in-place gate). Secondary belt-and-suspenders from earlier attempts remain
and are harmless: native `reassertNowPlaying` (AppDelegate + handler) and the
artwork-preserve rewrite in `AppDelegate.swift` (helps the stop→rebuild path).

**Ported to WBAI (2026-06-23):** `wbai-app/wbai_radio/.../wbai_audio_handler.dart`
`play()` now uses the same resume-in-place gate. (WBAI previously *never* rebuilt —
pure resume-in-place on all platforms — so it had no flash but also no live
reconnect on Android / after stop; now it matches KPFK.)

---

## 1. The exact symptom (from the user)

- App is **playing**, lock screen shows KPFK's image + show metadata. ✅
- User presses **Stop** (or pause) on the **lock screen**.
- Waits a bit.
- Presses **Play** again.
- **For ~1 second the lock screen shows whatever audio app was used previously**
  (Spotify / Apple Music / podcast) — its image and metadata.
- Then KPFK's real image + metadata appear and the stream plays.

This does **NOT** happen in the sister app **wpfw** (`/Users/paulhenshaw/Desktop/wpfw-app/wpfw_radio`), which the user confirms works. KPFK was forked from wpfw.

---

## 2. Confirmed mechanism (high confidence)

iOS shows exactly **one** app in the lock-screen "Now Playing" slot, tied to the
**active audio session** + `MPNowPlayingInfoCenter.nowPlayingInfo`.

1. KPFK playing → KPFK owns the session + Now Playing → lock screen = KPFK.
2. Stop → KPFK releases the session (`AudioSession.setActive(false)`) and clears
   its Now Playing → **iOS hands the slot back to the previously-used media app.**
3. Play → KPFK must **reconnect to the stream** (rebuild AVPlayerItem for live
   audio) before it can repopulate Now Playing. That reconnect takes ~1s.
4. During that ~1s gap the **previous app is still the slot owner** → its image
   shows. Then KPFK finishes and reclaims the slot.

So the fix must make KPFK **reclaim the Now Playing slot instantly on play**,
before the previous app can render — without going stale on audio.

---

## 3. The core tension (why we keep looping)

Two requirements that fight on iOS:

| Approach in `play()` | Live audio | Lock screen |
|---|---|---|
| **Rebuild AudioSource** (`setAudioSource`) | ✅ live | ❌ tears down AVPlayerItem → Now-Playing gap → previous app flashes |
| **Resume in place** (no rebuild) | ❌ stale/cached | ✅ no flash |

The user wants BOTH (live audio **and** no flash). wpfw achieves both, so it IS
possible. Reverting the rebuild "fixes" the flash but reintroduces the original
stale-audio complaint — that round-trip is the loop. **Do not revert the rebuild
as a fix.**

---

## 4. Chronological log of attempts THIS THREAD

| # | Change | Hypothesis | Result |
|---|---|---|---|
| 1 | `play()` iOS: rebuild AudioSource if paused > **4s** (`_lastPauseTime` + threshold) | Stale audio = iOS resumed buffered audio in place | ✅ Live audio fixed (user: "this fixed it"). Exposed lock-screen issues. |
| 2 | Repo `_awaitingPlay` guard: `ready`+`!playing` during startup → `buffering` not `paused` | Play icon flashed between spinner and pause | ✅ Fixed, still in place. **Unrelated to lock screen.** |
| 3 | Raised iOS rebuild threshold 4s → **15s** | Short screen off/on (<15s) shouldn't rebuild → no flash for short gaps | ✅ for short gaps; ❌ long gaps / Stop still rebuild → blank |
| 4 | wpfw-align #1: **always-rebuild** (all platforms) + native push in `_updateMediaMetadata` | wpfw uses native cached-artwork push; match it | ❌ **WORSE** — previous-app flash became prominent |
| 5 | Reverted handler to iOS resume-in-place; removed native push | Stop the bleeding | No flash BUT stale audio returned. User upset work was removed. |
| 6 | Restored **always-rebuild** live-audio fix (kept `_awaitingPlay`) | User wants live audio back | Live audio restored; flash still open |
| 7 | wpfw-align #2: Swift `AppDelegate` **preserve artwork** (drop text-only-first + 2s `isSettingArtwork` lock), add `forceUpdate` immediate path; Dart **instant reclaim** `_pushNativeLockscreen(forceUpdate:true)` at start of **`StreamRepository.play()`** + keep native push in `_updateMediaMetadata` | Reclaim the slot instantly before reconnect | ❌ Still broken — **because the reclaim was in the WRONG place** (see #8) |
| 8 | **ROOT CAUSE FOUND.** The lock-screen play button routes via audio_service → **`KPFKAudioHandler.play()`**, NOT `StreamRepository.play()`. So the attempt-#7 reclaim (in the repository) **never fired for lock-screen play**. `KPFKAudioHandler.play()` then does `setActive(true)` → **HTTP GET of the `.m3u`** (`StreamConstants.streamUrl` is an `.m3u`!) → `setAudioSource` → ~1s with no KPFK Now Playing → previous app shows. **Fix:** added native `reassertNowPlaying` (AppDelegate repaints from its cached title/artist/artwork) and call it via MethodChannel at the **very top of `KPFKAudioHandler.play()`** — the single path BOTH the in-app and lock-screen buttons hit, BEFORE the slow M3U fetch. | The reclaim must be on the handler path, not the repository path; and before the M3U fetch | ⏳ awaiting device test |

| 9 | **PROVEN ON DEVICE (debug build, live logs).** Root cause is NOT a metadata race — it's **latency**. Timestamped logs of a lock-screen pause→play: `Play button pressed 22:23:56.039` → `setAudioSource starts 56.042` → `setAudioSource RETURNS 58.618`. **`await setAudioSource()` blocks ~2.3–2.6s** connecting+buffering a fresh live AVPlayerItem. iOS only hands KPFK the Now Playing slot once it's *actually playing audio*; during that 2.6s the previous app keeps the slot = the flash. The native `reassertNowPlaying` ran (no error) but **could not override** — setting `nowPlayingInfo` does not claim the slot while not playing. Also confirmed: the bad play had **no `StreamRepository: Play requested` line** → it was lock-screen-initiated → `KPFKAudioHandler.play()` directly. **Fix:** when the player source is still alive (paused, not stopped → `processingState != idle`), **resume in place** (`_player.play()` only, no `setAudioSource`) — restarts in ms, no gap, KPFK claims the slot instantly. Only rebuild after a real stop (idle) or on Android. | The flash is the ~2.6s `setAudioSource` buffering gap, not a metadata race; resume-in-place removes the gap | ✅ **CONFIRMED FIXED on device** |

**PROVEN ROOT CAUSE (attempt #9):** the always-rebuild `await setAudioSource()`
takes ~2.6s to buffer a fresh live stream; iOS shows the previous app for that
whole window because KPFK isn't playing yet. nowPlayingInfo reclaim CANNOT fix it
(slot follows actual playback, not metadata). Resume-in-place (skip the rebuild
when the source is alive) removes the gap. Tradeoff: a resumed pause is buffered
(a few seconds behind live), not a fresh reconnect — acceptable; long/dead pauses
still rebuild or hit the reconnect path.

**Earlier pattern (now explained):** the native-push/reclaim approach failed in #4
and #7 because it was fighting the wrong thing — it tried to win a metadata race
when the real problem was the 2.6s no-audio gap.

---

## 5. What we have RULED OUT (wpfw vs kpfk, confirmed identical)

- `AudioService.init(...)` config in `main.dart` — **identical** (only formatting).
- iOS remote-command registration block in `main.dart` — **identical**; *neither*
  app calls `NativeMetadataService.registerRemoteCommandHandler()` (so the 30s
  audio-session keep-alive timer runs in **neither** app).
- Audio-session category: near-identical (`allowBluetooth` vs `allowBluetoothA2DP`
  only — cosmetic).

## 6. Confirmed DIFFERENCES wpfw vs kpfk (and current status)

- **Repository native push:** wpfw's `_updateMediaMetadata` calls
  `_nativeMetadataService.updateLockscreenMetadata(...)`; KPFK's 226c757 "final
  fix" had dropped it. → **NOW ADDED in KPFK** (attempt #7).
- **Swift artwork handling:** wpfw *preserves* existing artwork and sets Now
  Playing in one shot; KPFK set **text-only first** then downloaded (blank), plus
  a **2s `isSettingArtwork` lock**. → **NOW FIXED to preserve in KPFK** (attempt #7).

We have matched wpfw on both known differences and it's still broken → there is
**either a build problem or an unidentified difference.**

---

## 7. Current code state (as of attempt #7)

- `kpfk_audio_handler.dart` `play()`: **always** `setAudioSource` (all platforms) → live audio.
- `stream_repository.dart`:
  - `_awaitingPlay` guard (icon fix).
  - `play()` start: `_pushNativeLockscreen(_currentMetadata!, isPlaying:true, forceUpdate:true)` (instant reclaim).
  - `_updateMediaMetadata`: `_audioHandler.updateMediaItem(...)` + `_pushNativeLockscreen(... isPlaying: playing)`.
  - helper `_pushNativeLockscreen(metadata, {isPlaying, forceUpdate})`.
- `ios/Runner/AppDelegate.swift`:
  - `applyPendingMetadataUpdate`: one-shot set with cached-or-preserved artwork; download only on URL change.
  - `handleUpdateMetadata`: `forceUpdate` → apply immediately (bypass 250ms debounce + identical-skip).
  - removed `isSettingArtwork` lock entirely.

---

## 8. MANDATORY next step — capture logs BEFORE any more code changes

We are blind without runtime logs. The attempt-#7 Swift prints distinctive lines.
On the iPhone, do a **clean rebuild** (Swift changed — `flutter clean`, full Xcode
build, NOT hot reload), then reproduce Stop → wait → Play with Xcode console open
and capture:

- `[METADATA] Force update - applying immediately (instant reclaim)` ← proves the
  reclaim fired and the new Swift is running.
- `[METADATA] ✅ Lockscreen set (artwork preserved) - title=...`
- Any `AVAudioSessionClient ... error -50` lines (session contention).
- The Dart `🎵 StreamRepository: Re-asserting / reclaim` and `play()` order.

Decision tree from the logs:
- **If those log lines are ABSENT** → the build did not include the Swift changes.
  The "still broken" result is stale. Rebuild clean and retest. (Most likely.)
- **If present but still flashes** → the native reclaim is firing but
  audio_service (just_audio_background) is overwriting `MPNowPlayingInfoCenter`
  during the play state churn (idle→loading→ready). Then the real fix is about the
  **dual-writer conflict**: make ONE owner of iOS Now Playing (either suppress
  audio_service's iOS Now-Playing and let native own it, or drop native and keep
  audio_service but pre-populate before reconnect).

---

## 9. Open hypotheses to test (in order), once logs are captured

1. **Build didn't include Swift** (most likely given "same issue" with no behavior change). Verify via §8 log lines.
2. **Dual-writer conflict**: audio_service clears Now Playing on the idle/loading
   transition of the rebuild, overwriting the native reclaim. Candidate fixes:
   - Don't let `_broadcastState` push an `idle`/empty state to iOS during the
     rebuild (KPFK already never pushes null mediaItem on iOS — verify it holds).
   - Or stop deactivating the audio session on Stop/pause so iOS never hands the
     slot away in the first place (note: must not break the Stop "remove player"
     behavior).
3. **wpfw works for a reason we haven't found** — do a FULL `wpfw_audio_handler.dart`
   vs `kpfk_audio_handler.dart` diff (not just `play()`), and a full `AppDelegate`
   diff (done once — re-verify after attempt #7), and compare `MetadataService`
   polling/`_broadcastState` exactly.

---

## 10. Existing lock-screen docs (DO NOT recreate; mine these first)

Many prior docs exist (the team spent hours here before). Most relevant:
- `kpfk_radio/docs/THE_REAL_BUG_FOUND.md`, `FINALLY_FIXED.md`, `LOCKSCREEN_FIX_FINAL.md`, `NUCLEAR_FIX_README.md`
- `kpfk_radio/docs/LOCKSCREEN_ARTWORK_FLOW.md`, `LOCKSCREEN_DEEP_AUDIT_V3.md`, `iOS_LOCKSCREEN_METADATA_MASTER.md`
- `kpfk_radio/docs/archive/LOCKSCREEN_METADATA_SINGLE_SOURCE.md`, `iOS_FUNDAMENTAL_ISSUES.md` (notes audio session configured in BOTH Flutter and native → -50 errors, destabilizes MPNowPlayingInfoCenter — relevant to the dual-writer hypothesis #2)
- `old-docs/lock-screen-stop-image.md` (the pause→image-cleared bug + preserveMetadata fix)

**DONE — read `THE_REAL_BUG_FOUND.md` + `LOCKSCREEN_FIX_FINAL.md`:** they describe
a **different bug** — KPFK's *own* artwork blanking/disappearing, caused by (a) a
broken placeholder `artUri` (`kpfk_logo.png` 404) overriding real artwork every
second [already removed in current code], and (b) `MetadataController.swift`'s
forensic timer reapplying metadata without artwork [fix: disable MetadataController].
**Neither addresses the "previous app flashes" symptom.** Conclusion: the user's
memory of "we fixed this" most likely refers to the **artwork-blank** fix, not the
previous-app-slot fix. There may be NO prior fix for the slot-ownership flash.

**Verified now:**
- `MetadataController.swift` still exists but is **dormant** — its `.shared` is
  never referenced outside the file. Ruled OUT as an interferer.
- Only two iOS `MPNowPlayingInfoCenter` writers: `AppDelegate.swift` (native
  channel) and the `just_audio_background` Pod (driven by audio_service mediaItem
  + playbackState). The dual-writer conflict (hypothesis #2) is between THESE two.

---

## 11. Rules to avoid the loop

1. **No blind code changes.** Capture logs first (§8).
2. **Never "fix" the flash by reverting the live-audio rebuild** — that just swaps bugs.
3. Record every attempt in §4 with its result before trying the next.
4. wpfw is the working baseline — when in doubt, diff against it (whole files, not snippets).
5. Sister app: any final fix must be ported to WBAI too.
