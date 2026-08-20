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

## A3 — Microphone usage description — ❌ MY RECOMMENDATION WAS WRONG, REVERSED

**What this section originally said:** remove `NSMicrophoneUsageDescription`,
because no microphone API is used anywhere.

**That was wrong and it caused a rejected upload.** Build `1.0.2+13` came back
with:

> **ITMS-90683: Missing purpose string in Info.plist** — Your app's code
> references one or more APIs that access sensitive user data… should contain a
> `NSMicrophoneUsageDescription` key… If you're using external libraries or SDKs,
> they may reference APIs that require a purpose string. **While your app might
> not use these APIs, a purpose string is still required.**

**Why the check was insufficient.** I grepped the main `Runner` binary for
microphone symbols and found none. Apple scans **every linked binary, including
embedded frameworks**. Scanning `Runner.app/Frameworks/` finds two:

| Framework | Why it references mic APIs |
|---|---|
| `audio_session` | AVAudioSession category / record APIs |
| `flutter_inappwebview_ios` | WebView `getUserMedia` support |

**The key is therefore MANDATORY for as long as those plugins ship**, regardless
of what the app does.

**Resolution:** restored in both apps with an explanatory purpose string.

### Why this keeps recurring — read before touching this key

The key sits in a trap with a failure mode on *both* sides:

- **Remove it** (it looks unused, the app has no mic feature) → **ITMS-90683**,
  upload rejected.
- **Restore it with a dismissive string** like *"This app does not use the
  microphone"* → satisfies the scanner, but invites an App Review **5.1.1**
  question about why microphone access is declared. This bit another project.

Both directions look wrong, which is why it has flip-flopped repeatedly. The
correct state is: **key present, with a string that honestly explains why the
permission can be requested at all.**

**Guarded now:** `test/info_plist_required_keys_test.dart` (both apps) fails the
build if the key is missing, if the string is dismissive/too short, if
`ITSAppUsesNonExemptEncryption` is absent, or if `UIBackgroundModes` is not
declared exactly once.

**If a future release genuinely drops both plugins**, verify properly before
removing — scan the frameworks, not the main binary:
```bash
for f in build/ios/iphoneos/Runner.app/Frameworks/*.framework; do
  n=$(basename "$f" .framework)
  strings -a "$f/$n" | grep -qiE "requestRecordPermission|AVAudioRecorder|AVCaptureDevice|microphone" \
    && echo "$n references mic APIs"
done
```

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

## H4 — Audio session activated at startup, logs paramErr (-50) every launch

Observed in the Xcode console on 2026-08-19:

```
[AUDIO] Session configuration error: Error Domain=NSOSStatusErrorDomain Code=-50
SessionCore.mm:546  Failed to set properties, error: 4294967246
```

`kpfk_audio_handler.dart` `_init()` calls `session.setActive(true)` at app
startup, before iOS permits foreground audio, so the activation fails with
`paramErr`.

**Not a blocker, and deliberately not fixed for 1.0.2+13.** `play()` calls
`setActive(true)` again, and that call succeeds because it is user-initiated and
in the foreground — which is why playback works and device testing passed. The
startup failure is a noisy log line, not a functional fault. Changing audio
session initialisation immediately before an archive would invalidate the device
verification for no user-visible gain.

**The fix already exists in WBAI**, which does not activate at startup:

> `// Configure audio session category - do NOT activate until user presses play`
> `// Activating at startup causes iOS paramErr (-50) before foreground audio is allowed`

**Next cycle:** port WBAI's `_init()` pattern to KPFK (configure only, activate
on play) and re-verify lock-screen controls on device — the startup activation
was originally added as a "Samsung fix" for lock-screen controls, so that claim
needs re-testing on Android before removing it.

---

## H5 — `MinimumOSVersion` 13.0, must be 15.0+ by Spring 2027

App Store Connect warned on the `1.0.2+13` upload:

> This app has a MinimumOSVersion of 13.0. Starting in Spring 2027, all iOS apps
> must have a MinimumOSVersion of 15.0 or later in order to be uploaded to App
> Store Connect or submitted for distribution.

**A warning, not a rejection — the upload proceeds.** Deliberately not changed
for `1.0.2+13`: it touches both `ios/Runner.xcodeproj` (`IPHONEOS_DEPLOYMENT_
TARGET = 13.0`) and `ios/Podfile` (`platform :ios, '13.0'`), requires
`pod install`, a rebuild, and device re-verification. The project's own workflow
doc classes a deployment-target change as stop-and-review, never a pre-archive
edit.

**When you do it, the cost is near zero.** iOS 15 supports the same hardware as
iOS 13 (iPhone 6s and later), so raising the minimum drops no devices — only
users who declined to update the OS on a phone that can run 15.

**Applies to WBAI identically** — also 13.0 in both files.

**Next cycle:** bump both files to 15.0, `pod install`, rebuild, re-verify on
device. Well before Spring 2027.

---

## Sister app (WBAI)

WBAI has received every fix from this work and was audited alongside KPFK on
2026-08-19. Its findings, test matrices, and outstanding items live in
`docs/RELEASE-TESTING-HANDOFF.md` in the WBAI repo.

Differences worth knowing:
- **B2 (Android 13+ notification permission) affects WBAI identically** — it is
  unfixed in both apps.
- **S1 does not apply.** WBAI has no signing credentials in its repo.
- **A1 does not apply.** WBAI has no `NSAppTransportSecurity` block, so it is
  already on Apple's defaults.
- WBAI additionally had a **duplicate `UIBackgroundModes` key** (now fixed),
  which KPFK did not — so WBAI's background playback needs an explicit retest.

---

## Non-technical release gate — Apple agreement (RESOLVED 2026-08-20)

> **Status: cleared.** The Pacifica ED signed the agreement, and `1.0.2 (15)`
> reached **external** TestFlight on 2026-08-20. Kept as a record because it
> recurs — agreements lapse and new ones appear (banking/tax updates, program
> renewals), and the symptom looks like a build problem when it is not.

Hit on 2026-08-19 when adding `1.0.2 (14)` to external TestFlight: distribution
failed because a pending Apple agreement (Developer Program License / Paid Apps)
had not been accepted.

**Only the Account Holder can accept it** — for these apps that is the Pacifica
ED, not the developer account doing the build. No amount of rebuilding fixes it.

**What is blocked:** external TestFlight and App Store release. Internal
TestFlight generally still works, so device testing can continue while waiting.

**The fix:** Account Holder signs in at appstoreconnect.apple.com → **Business**
(shown as *Agreements, Tax, and Banking* on some accounts) → accept the pending
agreement. A click-through, a few minutes.

**Plan for the lead time.** This is an external dependency on someone else's
calendar, so raise it *before* the build is ready rather than at submission.
Uploaded builds stay valid for 90 days, so a signed-off build waits comfortably.

---

## Recommended order

1. **B1** version bump + `flutter build ios --config-only` — mechanical, blocking.
2. ~~**A2, A3, A4** — three `Info.plist` edits, no behavioural risk~~ — **A3 was wrong; see above.** A2 and A4 were correct and are applied. `NSMicrophoneUsageDescription` must stay.
3. **A1** ATS scoping — needs a WebView retest pass (donate, archive, schedule).
4. **B2** Android 13+ notification permission — the largest piece of real work,
   and it needs an Android 13+ device to verify.
5. **S1** — only if the earlier decision changes.
6. **H1** cleanup; **H2/H3** no action.

**Remaining device testing before submission:** Android matrix in
[audio-play-bug.md](audio-play-bug.md) §13, plus B2 on Android 13+, plus WebView
regression if A1 is applied.
