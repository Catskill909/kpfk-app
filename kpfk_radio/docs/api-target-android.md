# Android Target API 36 Compliance — Audit & Plan

**Date:** 2026-07-22 · **Status: Applied** (targetSdk 36 + Java 8 warning fix landed in both repos, verified with clean release builds; on-device run done for WBAI, KPFK pending a free device)
**Trigger:** Google Play Console warning — apps not targeting Android 16 (API 36) can no longer be updated after **Oct 31, 2026**. Current highest non-compliant target on both KPFK and WBAI: API 35.
**Scope:** KPFK (`kpfk_radio`) and WBAI (`wbai_radio`) — same codebase lineage, same toolchain, audited together. This copy of the doc lives in the KPFK repo; the canonical audit also lives at `wbai_radio/docs/api-target-android.md`.

## TL;DR

The bump was safe and cheap. Both apps already compiled against `compileSdk 36`; only `targetSdkVersion` (was hardcoded to `35`) was holding them back. Setting it to `36` and building both apps end-to-end succeeded with **zero errors on the first try** — no dependency bumps, no manifest surgery, no Gradle/AGP changes required beyond the fix below.

While test-running WBAI on a real Samsung device, a separate, pre-existing issue surfaced (`source/target value 8 is obsolete` javac warnings) and was fixed alongside the targetSdk bump in both repos.

## What changed

1. `android/app/build.gradle:56` — `targetSdkVersion 35` → `36` (KPFK); same at `:54` in WBAI.
2. `android/build.gradle` (both repos) — added a scoped `subprojects` block forcing `audio_session` and `just_audio` to compile against Java 11 instead of AGP's silent Java 8 default. See "Java 8 warning fix" below.

## Current toolchain (identical across both apps)

| Component | Version |
|---|---|
| Flutter | 3.44.3 stable |
| Dart | 3.12.2 |
| AGP | 8.12.2 |
| Kotlin | 2.2.20 |
| Gradle wrapper | 8.14.2 (KPFK) / 8.14.3 (WBAI) |
| NDK | 28.2.13676358 |
| compileSdk | 36 |
| targetSdkVersion | **36** (was 35) |

Local machine already has `android-36` platform + `build-tools 36.1.0` installed.

## Java 8 warning fix

Real device testing (`flutter run --release` on a Samsung SM-S737TL, running the WBAI build) surfaced this on every build, unrelated to the targetSdk bump:

```
warning: [options] source value 8 is obsolete and will be removed in a future release
warning: [options] target value 8 is obsolete and will be removed in a future release
```

Root cause, found by forcing a clean rebuild and grepping for which Gradle task emitted it: two plugin AAR modules — **`audio_session`** and **`just_audio`** — don't declare their own `compileOptions`, so they silently fall back to AGP's Java 8 default, which javac flags as obsolete under our JDK 21 toolchain. Since KPFK shares the exact same `pubspec.lock` versions of both plugins, a clean KPFK build was checked too and hit the identical warning from the identical two modules.

Fix: a `subprojects` block in the root `android/build.gradle`, scoped **only** to those two module names, forcing `sourceCompatibility`/`targetCompatibility` to `VERSION_11` (matching the app module's own Java target):

```gradle
def legacyJavaModules = ['audio_session', 'just_audio']
subprojects {
    if (project.name in legacyJavaModules) {
        afterEvaluate { project ->
            if (project.hasProperty('android')) {
                project.android {
                    compileOptions {
                        sourceCompatibility JavaVersion.VERSION_11
                        targetCompatibility JavaVersion.VERSION_11
                    }
                }
            }
        }
    }
}
```

**Why scoped, not a blanket override for all subprojects:** the first attempt applied this to every subproject unconditionally, which broke the build — `share_plus` already sets its own Kotlin `jvmTarget` to 17, and forcing its Java `compileOptions` down to 11 created an "Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks" failure (Java 11 vs Kotlin 17 in the same module). Scoping to just the two modules that actually have no explicit Java version — and confirmed via the build log to have `NO-SOURCE` Kotlin compile tasks (i.e., they're pure Java, no Kotlin to conflict with) — avoids touching anything that was already configured correctly. (KPFK doesn't depend on `share_plus`, but the same scoping was applied for consistency with WBAI and future-proofing.)

Verified with a full `./gradlew clean assembleRelease`: zero instances of "source value 8" in the output, build succeeds.

## On-device verification

Ran `flutter run --release` on a real device — **Samsung SM-S737TL, Android 8.1.0 (API 27)** — but only the WBAI build was installed (it was the app already set up on that device). Result: clean release build, no Java 8 warnings, `adb logcat` showed steady climbing `TrafficStats` RxBytes for ~58 seconds (actively streaming) and an alive `MediaSessionService` entry the whole time — no crash, cleanly torn down when the test session ended.

**KPFK still needs its own on-device pass** before shipping — it shares 100% of the same native plugin code paths and passed the identical clean `assembleRelease`, so the same result is expected, but hasn't been directly confirmed on hardware yet.

## Dependency compatibility

Locked versions (`pubspec.lock`) that touch native Android code, both apps:

| Package | Locked version |
|---|---|
| audio_service | 0.18.19 |
| audio_session | 0.1.25 |
| just_audio | 0.9.46 |
| flutter_inappwebview | 6.2.0-beta.3 |
| connectivity_plus | 6.1.5 |
| cached_network_image | 3.4.1 |
| dio | 5.10.0 |
| flutter_native_splash | 2.4.8 |
| flutter_launcher_icons | 0.13.1 |
| url_launcher | 6.3.2 |

`flutter pub outdated` shows newer majors available (audio_session 0.2.4, connectivity_plus 7.3.0, just_audio 0.10.6, google_fonts 8.2.0, xml 7.0.1, flutter_launcher_icons 0.14.4) — none of these are *required* for API 36; the currently locked versions already build and run against `compileSdk`/`targetSdk 36`. Treat the upgrades as separate, optional maintenance, not part of this compliance fix.

## Why it's already this easy

Prior work already cleared the hard parts of the Android 15/16 runway:

- **16KB page size** packaging (`useLegacyPackaging false`, NDK 28.2) — done, see `docs/16kb-warning-fix.md`.
- **Foreground service type** for media playback (`FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `POST_NOTIFICATIONS`) — already declared in both manifests, satisfies the API 34 requirement that API 36 still enforces.
- **compileSdk 36** — already bumped ahead of targetSdk.

## Non-blocking risk items — still worth a QA pass before shipping

These didn't fail a build; they're Android 16 behavior changes worth checking manually:

1. **Large-screen orientation/resizability enforcement.** Google's policy to ignore orientation/resizability/aspect-ratio locks on large screens (tablets, foldables, ChromeOS) for apps targeting SDK 36 has been announced and delayed more than once — status should be re-checked at ship time. **KPFK's** `AudioServiceActivity` hardcodes `android:screenOrientation="portrait"`; **WBAI's** does not lock orientation. If enforcement is live, KPFK could get forced into free rotation/landscape on a tablet or foldable — this is the one item specific to KPFK. Test on a tablet emulator before shipping.
2. **Predictive back gesture.** The manifest doesn't set `android:enableOnBackInvokedCallback="true"` on `<application>`. Not required to ship, but Android continues pushing predictive back; consider adding it for the system back animation and confirm the WebView (`flutter_inappwebview`) screens still back-navigate correctly with it on.
3. **Edge-to-edge.** Already mandatory since targetSdk 35 and handled by Flutter's embedding automatically — no code expected to change, but worth a glance at status/nav bar contrast on both light and dark splash themes.

## Remaining steps before shipping

1. **Run KPFK on a real device** (phone at minimum; tablet if the orientation-lock enforcement above is a concern) — the one verification WBAI has and KPFK doesn't yet.
2. **Ship to internal/closed testing first** (Play's own recommendation), not straight to production.
3. **Bump versionCode/versionName** per the normal release process.
4. **Ship to production well ahead of Oct 31, 2026.**

## Rollback

Trivial — `targetSdkVersion` is a single line per app (revert `36` → `35`); the Java-8 fix is a self-contained, additive block in `android/build.gradle` that can be deleted independently if it ever needs to be undone.
