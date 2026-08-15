# KPFK — Android notice/debug handoff

**Updated:** 2026-08-15

**Current version:** `1.0.1+12`

The notification/notice preparatory audit is complete. Start with
[`docs/ANDROID_NOTICE_DEBUG_AUDIT_2026-08-15.md`](docs/ANDROID_NOTICE_DEBUG_AUDIT_2026-08-15.md);
it contains the architecture trace, fixes, command evidence, known risks, and
the exact Android device/emulator matrix still required.

## Completed in the 2026-08-15 audit

- `flutter analyze`: clean.
- `flutter test`: 59 passed, 1 intentional device-only skip.
- Debug APK: built successfully.
- Release App Bundle: built and debug-only labels/URLs were absent.
- Android release lint: improved from 5 errors / 24 warnings to
  **0 errors / 24 warnings**.
- Private runtime receiver now uses `RECEIVER_NOT_EXPORTED`; its broadcasts are
  package-scoped.
- Launch-style API levels are explicitly annotated for the API-24 minimum.

## Next session—do these in order

1. Review `git status` and this audit's diff; do not mix dependency/toolchain
   upgrades into the notice fix.
2. Re-run analyzer, tests, Android release lint, and the final App Bundle build
   if anything has changed.
3. Run the debug matrix from the audit on Android devices/emulators, including
   TalkBack, Back/predictive Back, font scaling, no-network recovery, and the
   media notification tray during every outage transition.
4. Run the release matrix and prove the bug icon/menu/preset strings are absent.
5. Record results in a dated device-test document linked from the audit.
6. Commit/push the Android compatibility fixes and documentation only after
   the final diff and physical results are accepted.

## Deliberately deferred

- The dormant native Samsung media fallback is compiled but is not the active
  `audio_service` notification owner. Remove it only in a separate,
  device-verified cleanup.
- Kotlin/Gradle/AndroidX upgrades, portrait-policy changes, resource cleanup,
  and exported media-service hardening are separate workstreams.
- 16 KB native-library/Play artifact certification remains tracked by the
  Android API/16 KB documentation; a successful build is not that proof.
