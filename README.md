# KPFK Radio App

The official mobile app for **KPFK 90.7 FM**, Pacifica Radio's Los Angeles
station — live streaming with background playback, lockscreen controls, a sleep
timer, and screen-reader support on iOS and Android.

| | |
| --- | --- |
| **Version** | `1.0.1+12` |
| **Package / Bundle ID** | `app.pacifica.kpfk` |
| **Platforms** | iOS 13+ · Android 7.0+ (API 24), targeting API 36 |
| **Built with** | Flutter (Dart) |
| **Station** | https://www.kpfk.org |

> **This is the repository root.** The Flutter app itself lives in
> [`kpfk_radio/`](kpfk_radio/) and has its own
> [engineering README](kpfk_radio/README.md). This page covers the repository as
> a whole — what's in it, how to get building, and where every document lives.

---

## 📦 What's in this Repository

| Folder | Contents |
| --- | --- |
| [`kpfk_radio/`](kpfk_radio/) | **The Flutter app** — Dart source, iOS and Android projects, tests, and app-level engineering docs |
| [`docs/`](docs/) | Project-level documentation, including the [development history](docs/CHANGELOG.md) |
| [`android-signing/`](android-signing/) | Release keystore and signing instructions. **Delivered separately — the keystore and credentials are gitignored and not in this repo** |
| [`info/`](info/) | A standalone PHP CORS proxy and HTML "now playing" page for the station metadata feed. Server-side helper, not part of the app build |
| [`old-docs/`](old-docs/) | Archived notes from earlier development, kept for reference |

---

## ✨ Features

Live streaming · background playback · iOS lockscreen and Android notification
controls with station artwork · now-playing show metadata · sleep timer with
presets · outage vs. connection notices · offline detection with automatic
reconnect · in-app donate · Pacifica network directory · screen-reader support.

Each feature, with its implementation and source paths, is documented in the
[app README](kpfk_radio/README.md#features).

---

## 🚀 Getting Started

**Prerequisites** — Flutter SDK (stable channel; last verified on 3.44.3),
Xcode + CocoaPods for iOS, Android Studio / Android SDK for Android. Run
`flutter doctor` to confirm.

```bash
git clone https://github.com/Catskill909/kpfk-app.git
cd kpfk-app/kpfk_radio

flutter pub get   # install dependencies
flutter run       # run on a connected device

flutter test      # unit, widget, and golden tests
flutter analyze   # static analysis
```

Debug builds include an outage-testing panel for rehearsing failure states
without touching the live stream; it is compiled out of release builds.

---

## 🔐 Building a Signed Release

### Android

The release keystore is **not in this repository** — `*.jks` and
`key.properties` are gitignored. You need the `android-signing/` folder
delivered separately before you can produce a Play Store build.

```bash
# with android-signing/ present at the repo root:
cp android-signing/key.properties kpfk_radio/android/key.properties

cd kpfk_radio
flutter build appbundle --release   # Play Store upload (.aab)
flutter build apk --release         # direct install / testing
```

`versionCode` is derived automatically from the git commit count, so build
numbers cannot collide or regress. Full details, keystore facts, and recovery
guidance: [android-signing/SIGNING-INSTRUCTIONS.md](android-signing/SIGNING-INSTRUCTIONS.md).

> ⚠️ Use the **existing** keystore. Generating a new one produces an app the
> Play Store will not accept as an update to the published listing.

### iOS

Open `kpfk_radio/ios/Runner.xcworkspace` in Xcode and set the development team,
signing certificate, and provisioning profile.

> **Build numbers:** Xcode's Archive step does *not* bump the build number.
> After editing `version:` in `pubspec.yaml`, run
> `flutter build ios --config-only` so the archive picks up the new value.

---

## 🔧 Station Configuration

All station-specific values live in one file —
[`kpfk_radio/lib/core/constants/stream_constants.dart`](kpfk_radio/lib/core/constants/stream_constants.dart):

| Setting | Value |
| --- | --- |
| Stream | `https://docs.pacifica.org/kpfk/kpfk.m3u` |
| Station logo | `https://confessor.kpfk.org/pix/KPFK.png` |
| Website | https://www.kpfk.org |
| Feedback | feedback@kpfk.org |
| Facebook | https://www.facebook.com/KPFK90.7/ |
| Twitter/X | https://x.com/KPFK/ |
| Instagram | https://www.instagram.com/kpfk/ |
| YouTube | https://www.youtube.com/@KPFKTV/videos/ |

This app shares a codebase lineage with the other Pacifica station apps (WPFW,
WBAI) — it was built from that template and re-skinned, so fixes often port
between them.

---

## 📚 Documentation

**Start here**

- [kpfk_radio/README.md](kpfk_radio/README.md) — app features, architecture, and project structure
- [docs/CHANGELOG.md](docs/CHANGELOG.md) — development history and release record
- [docs/QUICK-START.md](docs/QUICK-START.md) — detailed setup and configuration

**Current work in flight**

- [kpfk_radio/RELEASE-TODO.md](kpfk_radio/RELEASE-TODO.md) — Android notice/debug handoff and next-session order
- [kpfk_radio/docs/ANDROID_NOTICE_DEBUG_AUDIT_2026-08-15.md](kpfk_radio/docs/ANDROID_NOTICE_DEBUG_AUDIT_2026-08-15.md) — Android audit and pending device matrix

**Doc indexes** — every document is catalogued in one of these

- [docs/README.md](docs/README.md) — project-level docs: setup, build guides, and recurring-issue master records
- [kpfk_radio/docs/README.md](kpfk_radio/docs/README.md) — app engineering docs: lockscreen system, feature design, testing, platform notes

**Frequently needed**

- [kpfk_radio/docs/TROUBLESHOOTING.md](kpfk_radio/docs/TROUBLESHOOTING.md) — stream, lockscreen, and WebView diagnostics
- [kpfk_radio/docs/iOS_LOCKSCREEN_METADATA_MASTER.md](kpfk_radio/docs/iOS_LOCKSCREEN_METADATA_MASTER.md) — iOS lockscreen and metadata system
- [kpfk_radio/docs/TESTING_outage_scenarios.md](kpfk_radio/docs/TESTING_outage_scenarios.md) — rehearsing failure states
- [docs/lock-screen-bug.md](docs/lock-screen-bug.md) · [docs/main-screen-layout-fix.md](docs/main-screen-layout-fix.md) — **read before touching lockscreen playback or home layout**; both bugs have regressed more than once

**Completed work** (records, not current guidance)

- [docs/history/](docs/history/) — WPFW→KPFK transformation and closed post-mortems
- [kpfk_radio/docs/history/](kpfk_radio/docs/history/) — lockscreen investigation, audio audits, feature rollouts
- [old-docs/](old-docs/) — archived legacy notes

---

## 📄 License

Copyright © 2026 Pacifica Radio — KPFK 90.7 FM
