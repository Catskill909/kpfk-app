# App Engineering Docs

Documentation for the KPFK Radio Flutter app. Feature and architecture overview
is in the [app README](../README.md); project-level docs are in
[`../../docs/`](../../docs/).

## Current reference

Docs describing how the app works **now**.

| Doc | What it covers |
| --- | --- |
| [iOS_LOCKSCREEN_METADATA_MASTER.md](iOS_LOCKSCREEN_METADATA_MASTER.md) | **The master reference** for the iOS lockscreen and metadata system — `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`, and the platform-channel bridge |
| [FEATURE_stream_offline_notice.md](FEATURE_stream_offline_notice.md) | Design of the stream notice: how a station outage is distinguished from a listener connection problem |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Diagnosing stream, lockscreen, notification, and WebView problems |
| [APP_CONFIGURATION.md](APP_CONFIGURATION.md) | App configuration notes |

## Testing

| Doc | What it covers |
| --- | --- |
| [TESTING_outage_scenarios.md](TESTING_outage_scenarios.md) | Rehearsing failure states with the debug-only outage panel, without touching the live stream |

## Build, release & platform

| Doc | What it covers |
| --- | --- |
| [VERSION_MANAGEMENT.md](VERSION_MANAGEMENT.md) | Version and build-number management with `cider` |
| [XCODE_RECOMMENDED_SETTINGS_WORKFLOW.md](XCODE_RECOMMENDED_SETTINGS_WORKFLOW.md) | Applying Xcode's recommended settings without breaking the archive |
| [api-target-android.md](api-target-android.md) | Android API 36 target compliance — audit and plan |
| [16kb-warning-fix.md](16kb-warning-fix.md) | 16 KB memory page size warning: background and fix |

## Work in flight

| Doc | Status |
| --- | --- |
| [ANDROID_NOTICE_DEBUG_AUDIT_2026-08-15.md](ANDROID_NOTICE_DEBUG_AUDIT_2026-08-15.md) | Android notice/debug audit. Static checks pass; **the device/emulator matrix is still outstanding**. Paired with [../RELEASE-TODO.md](../RELEASE-TODO.md) |

## Process

| Doc | What it covers |
| --- | --- |
| [AI_ASSISTED_DEV_GUIDELINES.md](AI_ASSISTED_DEV_GUIDELINES.md) | Working agreements for AI-assisted development on this codebase |

---

## [history/](history/)

47 documents recording completed work — the lockscreen artwork investigation,
audio reliability audits, iOS build cleanup, and feature rollouts. Kept because
they explain *why* the code looks the way it does. See
[history/README.md](history/README.md).

## [archive/](archive/)

Dead-end explorations and superseded attempts, retained only for provenance.
Do not treat anything here as current.
