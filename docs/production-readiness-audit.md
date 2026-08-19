# KPFK Production Readiness Audit — 2026-08-19

Scope: release-candidate review of `kpfk_radio` ahead of App Store / Play Store
submission. Audio-playback correctness is covered separately in
[audio-play-bug.md](audio-play-bug.md) and is **not** re-litigated here.

**Verified healthy:** `flutter analyze` clean · 65/65 tests · iOS release build
succeeds (32.8 MB `Runner.app`) · no `TODO`/`FIXME`/`HACK` markers · no stray
`print()` outside the kDebugMode-gated logger.

**Verdict: not yet submittable as-is.** Two items must be fixed (B1, B2). Four
more are cheap App Store friction removals worth doing in the same pass.

---

## B1 — Version not bumped (BLOCKER)

`pubspec.yaml` is still `1.0.1+12`, which is the **already-released** build
(`70b7c56 Prep KPFK API-36 release build (1.0.1+12)`). A submission reusing an
existing build number is rejected by App Store Connect outright.

This release contains the live-stream blocker fix, so it needs a new build.

**Fix:**
1. Bump `version:` in `pubspec.yaml` (e.g. `1.0.2+13`).
2. **Regenerate `ios/Flutter/Generated.xcconfig`** — it currently pins
   `FLUTTER_BUILD_NAME=1.0.1` / `FLUTTER_BUILD_NUMBER=12`, and **Xcode Archive
   does not pick up the pubspec change on its own**:
   ```
   flutter build ios --config-only
   ```
   Skipping this ships an archive still stamped `+12`.
3. Android needs nothing — `versionCode` is derived from the git commit count
   (`e239ef6`), so it advances automatically.

---

## B2 — Android 13+ never requests notification permission (BLOCKER)

`POST_NOTIFICATIONS` is declared in the manifest, but **nothing ever requests it
at runtime** — not the app, and not `audio_service` 0.18.15 (verified: no
`requestPermissions` anywhere in the plugin's Android source).

From Android 13 (API 33) onward that permission is runtime-gated and **denied by
default**. The foreground service still runs, but its notification is
suppressed. That notification *is* the media control surface — so affected users
get audio with **no notification and no lock-screen controls**, and no
explanation.

The app targets API 36, so this affects a large share of the Play audience.

**Why it has not been caught:** the Android test device is a Samsung SM-S737TL
on **Android 8.1 (API 27)**, where the permission is granted at install time.
This defect is invisible on that hardware.

**Fix:** request `POST_NOTIFICATIONS` at runtime before/at first playback on
API 33+, with a graceful path if denied. `permission_handler` is the usual
route; a small platform channel also works since the app already has one.

**Must be verified on an Android 13+ device**, not the 8.1 unit.

---

## S1 — Keystore password is public (SECURITY — previously accepted, resurfaced)

`android-signing/SIGNING-INSTRUCTIONS.md` contains the keystore and key password
in plaintext, and `github.com/Catskill909/kpfk-app` is confirmed **PUBLIC**.

This was raised before and the decision was to leave it. Resurfacing once
because this is a production-release audit and signing is in scope — then
dropping it.

**Actual exposure:** the password alone is not the credential. The `.jks`/
`key.properties` files are correctly gitignored and **not tracked** (verified),
so an attacker needs the keystore file too. But the password is permanent in
public git history, so it is one half of a signing credential that can never be
un-published.

**If you want it remedied:** rotating means a new upload key. With Play App
Signing that is a supported reset (request an upload-key reset in Play Console),
not a new listing. Redacting the file alone does nothing — the history keeps it.

**No action required if the earlier decision stands.**

---

## A1 — App Transport Security fully disabled (App Store friction)

`Info.plist` sets `NSAllowsArbitraryLoads = true`, disabling ATS globally.

**It appears unnecessary.** Every production URL in the app is HTTPS — verified
across the full host list (streams.pacifica.org, docs.pacifica.org,
confessor.kpfk.org, kpfk.org, archive/podcasts, social links, starkey.digital).
The only `http://` URLs are `10.255.255.1` and `127.0.0.1`, which are
**debug-only outage presets**, inert in release.

Apple asks submitters to justify a blanket ATS exemption, and it weakens
transport security for no benefit.

**Caution — do not simply delete it.** The app embeds WebViews (donate,
schedule, archive), and third-party content inside those pages can still be
HTTP. Removing ATS entirely could break the donate flow.

**Recommended:** replace the blanket exemption with the scoped one:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
</dict>
```
This keeps ATS enforced for the app's own networking (including the stream)
while leaving WebView content unrestricted. **Then retest donate + archive +
schedule WebViews**, which is the only way to know it holds.

---

## A2 — `ITSAppUsesNonExemptEncryption` missing (App Store friction)

Not present in `Info.plist`, so App Store Connect prompts the export-compliance
question on **every** upload.

The app uses only standard HTTPS, which is exempt. Add:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

## A3 — Microphone usage description declared, mic never used

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app does not use the microphone</string>
```
No microphone API is used anywhere (verified across Dart and Swift). Declaring a
purpose string for an unused capability — especially one whose text says it is
unused — invites reviewer questions for zero benefit.

**Fix:** remove the key.

---

## A4 — Background task identifier declared, never used

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array><string>com.pacifica.kpfk</string></array>
```
`BGTaskScheduler` / `BGAppRefresh` appear nowhere in the codebase. Same reasoning
as A3 — an unused declared capability.

**Fix:** remove the key. (`UIBackgroundModes: audio` is correct and must stay —
that one is load-bearing.)

---

## H1 — Dead alternate entrypoint shipped in source

`lib/test_lockscreen.dart` (297 lines) declares its own `void main()` and is
referenced nowhere. It is a scratch harness from the lock-screen debugging era
and still contains a hardcoded stream URL (`kpfk.streamguys1.com/live`) that
appears nowhere else in the app.

It is **not** in the release binary — only the real entrypoint's import tree is
compiled — so this is hygiene, not risk.

**Fix:** delete it, or move it under `tool/` so it reads as a dev harness.

---

## H2 — Bundle identifiers differ across platforms (INFORMATIONAL — do not change)

- iOS: `com.pacifica.kpfk`
- Android: `app.pacifica.kpfk`

Both are already published. **Changing either now would create a new store
listing and orphan existing installs.** Recorded so it is not "fixed" by mistake
later. Note the internal channel names use a third prefix (`com.kpfkfm.radio/*`),
inherited from the wpfw fork — harmless, purely internal.

---

## H3 — Dependencies behind latest (RECOMMEND NOT UPGRADING NOW)

| Package | Current | Latest |
|---|---|---|
| just_audio | 0.9.46 | 0.10.6 |
| audio_session | 0.1.25 | 0.2.4 |
| connectivity_plus | 6.1.5 | 7.3.1 |
| google_fonts | 6.3.3 | 8.2.1 |
| xml | 6.6.1 | 7.0.1 |

`just_audio` and `audio_session` are pinned deliberately ("EXACT versions from
working Pacifica app") and are precisely the layer whose behaviour was just
stabilised and device-verified. **Upgrading them immediately before release
would invalidate that verification.** Do it early in the next cycle with a full
device re-test, not now.

No known-vulnerable packages surfaced.

---

## Confirmed correct — no action

- **Debug surfaces are hard-gated.** `DebugStreamOverride.url` returns null
  unless `kDebugMode`, so a release binary resolves to the live stream
  regardless of stored state. The debug bug icon (`home_page.dart:233`) and the
  settings debug section are both `kDebugMode`-wrapped.
- **Release logging is silent.** `Logger.root.level = kDebugMode ? INFO : SEVERE`
  and the `print()` is `kDebugMode`-gated, so release builds emit nothing to the
  console.
- **Android permissions are minimal and justified:** INTERNET, WAKE_LOCK,
  FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK, POST_NOTIFICATIONS.
  Nothing extraneous.
- **Signing files are not tracked.** No `.jks`, `.keystore`, or `key.properties`
  in the index; `.gitignore` covers all three.
- **Fonts are bundled**, with `GoogleFonts.config.allowRuntimeFetching = false`
  — no runtime font fetch on first paint.
- **Privacy manifest present** with 5 declared API reasons.
- **R8/minify disabled deliberately**, with a documented reason (it broke the
  media notification controls on device). The Play "no deobfuscation file"
  notice is a warning, not a requirement.

---

## Recommended order

1. **B1** version bump + `flutter build ios --config-only` — mechanical, blocking.
2. **A2, A3, A4** — three `Info.plist` edits, no behavioural risk, removes review friction.
3. **A1** ATS scoping — needs a WebView retest pass (donate, archive, schedule).
4. **B2** Android 13+ notification permission — the largest piece of real work,
   and it needs an Android 13+ device to verify.
5. **S1** — only if the earlier decision changes.
6. **H1** cleanup; **H2/H3** no action.

**Remaining device testing before submission:** Android matrix in
[audio-play-bug.md](audio-play-bug.md) §13, plus B2 on Android 13+, plus WebView
regression if A1 is applied.
