# handoff.md — KPFK / WBAI / WPFW Radio Apps

**Purpose:** hand this project to a fresh chat window or a different LLM without
losing context. Read this first; it points at the deeper docs rather than
repeating them.

**Last updated:** 2026-08-19

---

## 1. What this is

Three Flutter radio-streaming apps for Pacifica stations, built from a shared
template (KPFK and WBAI were forked from `wpfw-app`; leftover
`com.wpfwfm.radio/*` channel names confirm the lineage). **KPFK leads: fixes are
made there and ported to the others.** Most work touches KPFK and WBAI; WPFW
enters the picture for the Pacifica-screen port (§4).

| App | Repo | Version | Notes |
|---|---|---|---|
| **KPFK** (lead) | `/Users/paulhenshaw/Desktop/kpfk-app` → `kpfk_radio/` | **`1.0.2+15`** | TestFlight internal + **external** testing |
| **WBAI** (sister) | `/Users/paulhenshaw/Desktop/wbai-app/wbai_radio` | `1.0.1+8` | Fixes ported, **untested on any device** |
| **WPFW** (origin template) | `/Users/paulhenshaw/Desktop/wpfw-app/wpfw_radio` | `1.0.1+4` | The app both others were forked from. Furthest behind; see its own `docs/SISTER_APP_PARITY_LEDGER.md` |

All three are **public** on GitHub (`Catskill909/kpfk-app`, `Catskill909/wbai-app`,
`Catskill909/wpfw-radio`). Work happens directly on `main` — **never create a
feature branch.**

**`wpfw_radio` carries uncommitted work that is not ours** — a modified
`pubspec.lock` and an untracked `docs/SISTER_APP_PARITY_LEDGER.md`. Preserve
both; never `git checkout -- .` or `git clean` in that repo.

**Structural note:** KPFK's project docs live at `kpfk-app/docs/` (top level) and
app-internal docs at `kpfk-app/kpfk_radio/docs/`. WBAI and WPFW each have a
single `<app>_radio/docs/`. Don't confuse the two KPFK trees.

---

## 2. Current state (2026-08-19)

**iOS — KPFK `1.0.2 (15)` is live on TestFlight for INTERNAL AND EXTERNAL
testing** (uploaded 2026-08-20, validated and uploaded clean). It is the first
build carrying the Pacifica-screen accessibility and text-scale fixes
(`6b5bf78`).

- **The Apple agreement blocker is CLEARED.** The Pacifica ED (Account Holder)
  signed it, which is what unlocked external distribution. Earlier notes in the
  docs describing this as blocking are historical.
- **Next milestone is App Store submission**, not another gate. Feedback from
  external testers is now the gating input.
- Build `1.0.2 (13)` was **rejected** (ITMS-90683) — see §3. `1.0.2 (14)` was
  the prior good build. TestFlight builds stay valid 90 days.
- Older `1.0.1 (15)` on TestFlight is a *different version train*; build numbers
  are scoped per marketing version, so it does not conflict with `1.0.2 (14)`.

**Android — untested, has a known blocker.** Planned next.

**WBAI — code complete, never run on a device** (iOS or Android).

**Pacifica Foundation screen — audited and fixed on KPFK** (`6b5bf78`). Three
defects found and closed: missing screen-reader labels on the sister-station
logos, and two layouts that overflowed at accessibility text sizes. Confined to
the two files that make up that screen; no playback, network, or lifecycle code
touched. See `docs/pacifica-screen.md`.

---

## 3. NON-NEGOTIABLE RULES (these have each caused a release blocker)

### 3.1 Play ALWAYS plays the live stream, NEVER the cache

`play()` rebuilds the AudioSource **unconditionally** — every platform, every
press. No resume path, no staleness window, no platform gate.

A `sourceAlive` check (`audioSource != null && processingState != idle`) once
skipped the rebuild to hide a ~2.6s iOS lock-screen flash. It tests whether an
*object* exists, not whether the socket is alive — so after the app sat dormant
it replayed stale buffered audio and then stopped dead, silently.

**The lock-screen flash is cosmetic and belongs to the native
`reassertNowPlaying` pre-claim in `ios/Runner/AppDelegate.swift`.** Device-proven
sufficient on its own. Never fix the flash by resuming a buffer.

Also: **`ProcessingState.completed` on a live stream is ALWAYS a failure**, never
a clean stop. A 24/7 stream has no end.

Guarded by `test/live_stream_always_rebuilds_test.dart` (both apps).
Full analysis: `docs/audio-play-bug.md`.

### 3.2 `NSMicrophoneUsageDescription` must STAY in Info.plist

Neither app has a microphone feature, so it looks removable. It is not.
`audio_session` and `flutter_inappwebview_ios` reference mic APIs, and **Apple
scans embedded frameworks, not just the app binary.** Removing it →
**ITMS-90683**, rejected upload (this happened on build `1.0.2+13`).

It fails in **both** directions: absent → rejection; present with a dismissive
string like *"This app does not use the microphone"* → App Review **5.1.1**
question. Correct state: present, with an honest explanation.

Guarded by `test/info_plist_required_keys_test.dart` (both apps).

To check properly, scan frameworks — not the main binary:
```bash
for f in build/ios/iphoneos/Runner.app/Frameworks/*.framework; do
  n=$(basename "$f" .framework)
  strings -a "$f/$n" | grep -qiE "requestRecordPermission|AVAudioRecorder|AVCaptureDevice|microphone" && echo "$n"
done
```

### 3.3 Android: anything producing `ProcessingState.idle` blanks the lock screen

`_broadcastState`'s Android branch maps `idle` → `mediaItem.add(null)` → the
notification and lock screen erase. Before changing any player state
(`stop`/`pause`/`seek`/`setAudioSource`), trace it through that branch.

- Rebuilding and want the notification kept → wrap in `_rebuildingSource = true/false`
- Genuinely tearing down (app close, sleep timer) → let it blank; that is intended

### 3.4 Home screen station image is sized by WIDTH

Never by leftover vertical space — height-budget math shrinks it. Recurring
regression. See `docs/main-screen-layout-fix.md`.

### 3.5 User-facing messages are acknowledged modals, never snackbars

Snackbars vanish and confuse listeners. One modal surface — `StreamNotice`.

### 3.6 NEVER run `dart format` on a directory

`dart format lib/` rewrites line breaks in **every** file it is given. Run
against `lib/` while editing two files, it reformatted 20 — including
`ios_lockscreen_service.dart`, `android_notification_service.dart`, and
`audio_state_manager.dart`, the exact files this project treats as untouchable
mid-release. The changes were cosmetic reflow only and were reverted before any
commit, but the review cost and the alarm were real, and a diff that large hides
anything genuine inside it.

**Rule:** format by explicit file path only, or not at all — never a directory,
never `.`. Then confirm with `git status` that only the intended files changed.

**This is now enforced, not just documented.** A `PreToolUse` Bash hook at
`~/.claude/hooks/guard-wide-scope.sh` (wired in `~/.claude/settings.json`)
hard-blocks `dart format` / `flutter format` on a directory or bare, and prompts
for confirmation on `git clean`, `git checkout -- .`, `git restore .`, and
`git reset --hard`. It handles `-C <dir>` and compound `a && b` commands.
Single-file formatting and everyday git are untouched. It applies to **all three
sister apps**, since it lives in user settings rather than any one repo.
Review or disable it with `/hooks`; a timestamped backup of the previous
settings sits beside `settings.json`.

The same applies to any whole-tree command during a release: check `git status`
**before and after**, and if it lists files you did not intend to touch, revert
them individually rather than continuing.

---

## 4. Outstanding work

### BLOCKER — Android 13+ never requests notification permission
`POST_NOTIFICATIONS` is declared but never requested at runtime, and
`audio_service` doesn't request it either. From API 33 it's denied by default,
so the foreground service runs while its notification — the media control
surface — is suppressed. **Affects both apps.**

**Test on the `Android16_API36` emulator** (`flutter emulators`). The Samsung
SM-S737TL is API 27, where the permission is granted at install — **the bug
cannot appear there.**

### Android device matrix (untested)
`docs/audio-play-bug.md` §13. Highest value: network-drop-and-recover (does the
notification art blank?) and swipe-from-recents while paused. **Use `adb
logcat`, not flutter logs.**

### WBAI (few days out)
Version bump + full iOS and Android testing.
**Start at `wbai_radio/docs/RELEASE-TESTING-HANDOFF.md`.** Two highest-risk
items: its `reassertNowPlaying` is brand new and unexercised, and a duplicate
`UIBackgroundModes` key was just collapsed to one, so background playback needs
an explicit regression check.

### Pacifica Foundation screen — port to WPFW and WBAI (not started)
KPFK's two-tab rebuild shipped in `f016754`; its three accessibility and
text-scale fixes shipped in `6b5bf78`. **Port the current KPFK version — the
fixes are already in it**, so there is no longer any reason to copy the older
unfixed state. Both siblings still run the pre-rebuild single-page version.

The port is a **two-file copy plus one string edit**. All supporting
bloc/repository/model code was verified byte-identical across the three apps on
2026-08-19, and neither target file contains station names, URLs, or per-station
colors.

**Do WPFW first** (dark-only, like KPFK). **WBAI second — it is the only app
with light mode** (`themeMode` is user-selectable; its light AppBar foreground
is `WBAIColors.darkBrown`), so its
`iconTheme: const IconThemeData(color: Colors.white)` must be preserved or the
back arrow goes dark-brown on a near-black bar.

Full plan, audit findings, and per-app verification checklist:
**`docs/pacifica-screen.md`**.

### Donate URL — GM request, DEFERRED on App Review risk (2026-08-19)
The KPFK GM asked to repoint the **side-drawer** Donate link from
`https://docs.pacifica.org/kpfk/donate/` to `https://kpfk.org/donate`. It was
changed, then **reverted before commit**. Both URLs are live (200).

**Why it was held back:** the destination is a commercial donation page, and
App Review scrutinises payment flows that appear inside an app. Taking money for
digital content through anything but In-App Purchase breaches **Guideline 3.1.1**;
non-profit donations are a documented exception (**3.2.1(vi)**) but the exception
is conditional and Review does reject on it.

**How each donate path actually opens** — verified in the package source, not
assumed:

- **Drawer** → `_launchUrl` calls `launchUrl(...)` with no `mode:`, so it gets
  `platformDefault`. In `url_launcher_ios` 6.4.1 that resolves to **in-app**
  for any `http/https` URL (`url_launcher_ios.dart` ~line 89 → 
  `openUrlInSafariViewController`). So it is an **`SFSafariViewController`
  sheet**, not the Safari app: browser-like, non-editable URL, no free
  navigation.
- **Home screen** → `DonateWebViewSheet`, a real **`WKWebView`** via
  `flutter_inappwebview`, with its own hardcoded `docs.pacifica.org` URL.

Both are in-app. `SFSafariViewController` is Apple's own sandboxed component
and the app cannot read or script it; the bottom sheet is an embedded webview
the app hosts. For a payment flow the bottom sheet is the more exposed of the
two.

**Key point if this is revisited:** reverting did not remove the mechanism. The
drawer already opens a donate page in `SFSafariViewController` today, and that
ships in `1.0.2 (14)`. The change was only ever about the **destination**, so
the open question is whether `kpfk.org/donate` reads as more commercial to a
reviewer than the Pacifica-hosted page — a judgement about the page, not the
plumbing.

Decide the App Review question first; changing the constant is a one-line edit
afterwards, and `donateUrl` is referenced only by the drawer.

### Deferred, non-blocking
- **ATS** — `NSAllowsArbitraryLoads` is on though all production URLs are HTTPS.
  Scope to `NSAllowsArbitraryLoadsInWebContent`, then retest donate/archive/
  schedule WebViews. KPFK only; WBAI has no ATS block.
- **Startup `paramErr (-50)`** — KPFK activates the audio session in `_init()`
  before iOS allows it. Harmless (play() re-activates) but noisy. WBAI already
  has the fix; port it back and re-verify Android lock-screen controls, since
  the startup activation was originally a Samsung fix.
- **UIScene lifecycle** — Flutter-level, arrives via a Flutter upgrade.
- **Keystore password** — was plaintext in a public repo, removed 2026-08-19.
  History still has it. Real remedy is a Play Console upload-key reset.
- **Dependency upgrades** — `just_audio`/`audio_session` are behind and are
  exactly the layer verified on device. Next cycle, with a full device retest.

---

## 5. Operational gotchas (each cost real time)

| Trap | Rule |
|---|---|
| `flutter run` from VSCode rewrites `ios/Flutter/ephemeral/flutter_native_integration.env` with debug values (`TRACK_WIDGET_CREATION=true`, `TREE_SHAKE_ICONS=false`) — **happened three times**, most recently found committed in that state just before the `1.0.2+15` archive | `flutter build ios --config-only` before archiving rewrites it to release values *and* syncs the build number — do both in one step. Never use `flutter run` just to open Xcode; open `ios/Runner.xcworkspace` directly |
| `plutil -extract` **overwrites the input file** without `-o -` (destroyed a real `Info.plist`) | Always `plutil -extract KEY raw -o - file`, or use `plutil -p` / `grep` |
| Xcode caches a stale project model across external edits (`pod install`, `project.pbxproj`, `Generated.xcconfig`) | `Cmd+Q` and reopen the workspace. A `flutter clean` is NOT the fix |
| Xcode Archive ignores `pubspec.yaml` version changes | Run `flutter build ios --config-only` after any version bump, then verify in the **built artifact**, not the source |
| Bash `cd` does not persist reliably between tool calls | Use absolute paths in every command |
| `flutter clean` | Do NOT run routinely — reserve for a genuinely stale build |
| `dart format lib/` reformatted 20 files while two were being edited, including the lockscreen and notification services | Format by **explicit file path only**, never a directory. See §3.6 |

---

## 6. Working preferences

- **Commit and push to `main` directly.** Never a feature branch.
- **Run builds/verification in the terminal** so errors are caught live — but the
  **final archive + upload stays in Xcode**, because the user wants the
  Organizer's validation report to review.
- **Get device logs; don't theorize.** iOS: `flutter run -d <id>`, tail output
  (release builds log nothing — the logger is `kDebugMode`-gated). Android:
  `adb logcat`.
- **Don't sit in long blocking poll loops** waiting on a device build — the user
  watches the device.
- **The user tests on real hardware.** Verify claims there, not by assertion.

---

## 7. Key files

| Path | What |
|---|---|
| `lib/services/audio_service/<app>_audio_handler.dart` | `play()`, reconnect, `_broadcastState` — the heart of §3.1 and §3.3 |
| `lib/data/repositories/stream_repository.dart` | Playback-state → UI state, outage classification, watchdog |
| `ios/Runner/AppDelegate.swift` | Native lock-screen metadata + `reassertNowPlaying` |
| `ios/Runner/Info.plist` | §3.2 lives here |
| `docs/audio-play-bug.md` | The live-stream fix, Android audit, device matrices |
| `docs/production-readiness-audit.md` | Full release audit (KPFK) |
| `docs/lock-screen-bug.md` | Master record — **its old "resume in place" advice is REVERSED**, see the banner |
| `docs/xcode-archive-warnings.md` | Baseline of ~40 third-party warnings; use it to spot one that's actually yours |
| `kpfk_radio/docs/XCODE_RECOMMENDED_SETTINGS_WORKFLOW.md` | Archive workflow + the §5 gotchas |

---

## 8. Health check

All repos: `flutter analyze` clean.

| | Tests | Latest commit | Working tree |
|---|---|---|---|
| KPFK | **69/69** | see §2 — `1.0.2+15` is the TestFlight build | clean |
| WBAI | **83/83** | `0e000d2` | clean |
| WPFW | not run this cycle | `d218e27` | 2 files, **the user's own** — leave them |

If a guard test fails (`live_stream_always_rebuilds_test.dart` or
`info_plist_required_keys_test.dart`), **do not "fix" it by weakening the test** —
it is catching a regression that has shipped before.
