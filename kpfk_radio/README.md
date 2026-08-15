# KPFK Radio Streaming App

A Flutter radio streaming app for KPFK 90.7 FM, with background audio playback,
lockscreen and notification controls, a sleep timer, and screen-reader support.

This is the **app-level engineering reference**: what each feature does and how
it is put together. For the front-facing overview and install instructions see
the [project README](../README.md); for the dated record of what changed and
when, see the [development history](../docs/CHANGELOG.md).

**Current version:** `1.0.1+12`

## Features

- **Streaming audio with background playback**
  - Powered by `just_audio`, `audio_service`, and `audio_session`.
  - Playback continues when the app is backgrounded or the screen is off.
  - Source: `lib/services/audio_service/kpfk_audio_handler.dart`, `lib/data/repositories/stream_repository.dart`

- **Lockscreen and notification controls**
  - Play/pause, station artwork, and current show metadata on the iOS lockscreen
    and the Android media notification, synchronized with in-app state.
  - iOS uses native `MPNowPlayingInfoCenter` updates and `MPRemoteCommandCenter`
    handlers over platform channels; updates are debounced to avoid churn.
  - Source: `lib/services/ios_lockscreen_service.dart`, `lib/services/metadata/lockscreen_service.dart`, `lib/services/android_notification_service.dart`
  - Reference: [docs/iOS_LOCKSCREEN_METADATA_MASTER.md](docs/iOS_LOCKSCREEN_METADATA_MASTER.md)

- **Now-playing metadata**
  - Current and upcoming show information fetched from the station feed, adapted
    for both the UI and the OS media controls.
  - Source: `lib/services/metadata_service.dart`, `lib/services/metadata_service_native.dart`

- **Sleep timer (overlay)**
  - Full-screen dark overlay with presets (15/30/45/60m) and a minute slider.
  - Countdown with pause/resume and cancel.
  - On completion, performs a cold-start audio reset — stop, dispose the player,
    clear the iOS lockscreen, return to idle — so no residual state is left behind.
  - Entry: bottom-right Alarm button on `HomePage`.
  - Source: `lib/presentation/widgets/sleep_timer_overlay.dart`, `lib/presentation/bloc/sleep_timer_cubit.dart`

- **Donate modal WebView**
  - In-app modal sheet built on `flutter_inappwebview`.
  - External links are handed off to the system browser.
  - Accessible close control, with announcements for page load and external launches.
  - Source: `lib/presentation/widgets/donate_webview_sheet.dart`

- **Pacifica apps & services**
  - Grid of Pacifica posts, apps, and services fetched from the WordPress API.
  - Opens from the top-right icon on `HomePage`.
  - Source: `lib/presentation/pages/pacifica_apps_page.dart`, `lib/presentation/bloc/pacifica_bloc.dart`, `lib/data/repositories/pacifica_repository.dart`

- **Offline awareness & recovery**
  - Connectivity monitoring with a network-lost alert, bounded automatic
    reconnect, and manual retry.
  - Source: `lib/presentation/widgets/network_lost_alert.dart`, `lib/presentation/bloc/connectivity_cubit.dart`, `lib/core/services/connectivity_service.dart`

- **Stream outage and connection notices**
  - One persistent, acknowledged modal surface — no transient snackbars or
    duplicate inline cards.
  - Distinguishes a confirmed station outage from a listener-side connection
    problem, and offers **Try again** only when a retry can help.
  - The notice appears as soon as detection finishes, ahead of platform-audio
    cleanup, so the listener is never left watching a dead spinner.
  - Source: `lib/presentation/widgets/stream_notice_modal.dart`, `lib/core/services/audio_server_health_checker.dart`, `lib/domain/models/stream_notice.dart`
  - Reference: [feature design](docs/FEATURE_stream_offline_notice.md)

- **Accessibility**
  - Dynamic screen-reader labels and hints for the play/pause control.
  - Live announcements for playback transitions (Loading, Buffering, Playing,
    Paused) and error states.
  - Donate modal: labeled close button, with announcements for page load and
    external browser handoff.
  - Dynamic Type support and a dark theme.

- **Debug outage tooling** *(debug builds only)*
  - A home-header icon opens a panel of deterministic outage presets that drive
    real failures through the playback pipeline, plus direct notice previews.
  - Compiled out of release builds entirely.
  - Source: `lib/core/testing/debug_stream_override.dart`, `lib/presentation/pages/debug_outage_page.dart`
  - Reference: [testing scenarios](docs/TESTING_outage_scenarios.md)

---

## Architecture Overview

- **Framework**: Flutter (Dart)
- **State management**: `flutter_bloc` + `get_it` service locator
- **Audio playback**: `just_audio` with `audio_service` and `audio_session`
- **Networking**: `dio` and `http`
- **Storage/Device**: `shared_preferences`, `path_provider`, `device_info_plus`
- **Web content**: `flutter_inappwebview`
- **UI**: Material 3 theme, bundled Oswald/Poppins fonts, SVG, cached images

High-level flow:

- `HomePage` (`lib/presentation/pages/home_page.dart`) renders the main experience: station artwork, metadata, and a single large play/pause control that dispatches events to `StreamBloc`.
- `StreamBloc` (`lib/presentation/bloc/stream_bloc.dart`) orchestrates playback via `StreamRepository` (`lib/data/repositories/stream_repository.dart`).
- `KPFKAudioHandler` (`lib/services/audio_service/kpfk_audio_handler.dart`) wraps `just_audio` and integrates with `audio_service` for background and notification control.
- Metadata services (`lib/services/metadata_service*.dart`) fetch and adapt current/next show info and song data for the UI and the iOS lockscreen.
- iOS lockscreen integration goes through native `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` over platform channels.

## Project Structure

- `lib/presentation/pages/`
  - `home_page.dart`, `pacifica_apps_page.dart`, `settings_page.dart`, `debug_outage_page.dart` (debug builds only)
- `lib/presentation/widgets/`
  - `sleep_timer_overlay.dart`, `donate_webview_sheet.dart`, `app_drawer.dart`, `stream_notice_modal.dart`, `network_lost_alert.dart`, `show_info_modal.dart`, `affiliate_buttons_section.dart`, `sliding_panel.dart`, `station_webview.dart`
- `lib/presentation/bloc/`
  - `stream_bloc.dart`, `sleep_timer_cubit.dart`, `connectivity_cubit.dart`, `pacifica_bloc.dart`
- `lib/services/`
  - `audio_service/kpfk_audio_handler.dart`
  - `metadata_service.dart`, `metadata_service_native.dart`, `metadata/lockscreen_service.dart`, `ios_lockscreen_service.dart`, `android_notification_service.dart`
- `lib/data/`
  - `repositories/` (stream, pacifica, affiliate)
  - `models/` and `domain/models/`
- `lib/core/`
  - `di/` service locator, `services/` (connectivity, audio state manager, health checker, logger), `constants/`, `utils/`, `testing/`
- `test/` — unit, widget, and golden tests; goldens in `test/goldens/`
- `docs/` — architecture notes and platform specifics

## Packages / Dependencies

From `pubspec.yaml`:

- Audio: `just_audio`, `audio_service`, `audio_session`
- WebView: `flutter_inappwebview`
- State: `flutter_bloc`, `get_it`
- Network/Storage: `dio`, `http`, `connectivity_plus`, `path_provider`, `shared_preferences`, `device_info_plus`, `url_launcher`
- UI: `flutter_svg`, `cached_network_image`, `google_fonts`, `cupertino_icons`, `equatable`, `flutter_native_splash`
- Dev: `flutter_test`, `flutter_lints`, `flutter_launcher_icons`

See `pubspec.yaml` for version pins.

## Setup & Build

Prerequisites: Flutter SDK (stable) and platform toolchains — Xcode for iOS,
Android SDK/NDK for Android.

```bash
flutter pub get         # install dependencies

flutter run -d android  # run on Android
flutter run -d ios      # run on iOS Simulator

flutter test            # unit, widget, and golden tests
flutter analyze         # static analysis

flutter build apk       # Android
flutter build ios       # iOS (requires Xcode signing)
```

Xcode maintenance and archive safety:
[recommended-settings workflow](docs/XCODE_RECOMMENDED_SETTINGS_WORKFLOW.md).

## Usage

- The app opens to `HomePage`.
- The large play/pause button starts and stops the KPFK stream.
- Bottom-right Alarm button opens the sleep timer overlay.
- Bottom-left Donate button opens the in-app donate modal; external links open
  in the system browser.
- Top-right icon opens the Pacifica Apps & Services grid.
- In debug builds only, the bug icon opens the outage testing panel.

## Station Information

- **Station**: KPFK 90.7 FM
- **Network**: Pacifica Radio
- **Website**: https://www.kpfk.org
- **Stream URL**: https://docs.pacifica.org/kpfk/kpfk.m3u
- **Email**: feedback@kpfk.org

### Social Media

- **Facebook**: https://www.facebook.com/KPFK90.7/
- **Twitter/X**: https://x.com/KPFK/
- **Instagram**: https://www.instagram.com/kpfk/
- **YouTube**: https://www.youtube.com/@KPFKTV/videos/

## Configuration Files

- `lib/core/constants/stream_constants.dart` — stream URLs, station info, social links
- `pubspec.yaml` — dependencies and app metadata
- `android/app/build.gradle` — Android build configuration
- `ios/Runner.xcodeproj/project.pbxproj` — iOS build configuration

## Further Reading

- [docs/README.md](docs/README.md) — **index of every app engineering doc**, current and historical
- [Development history](../docs/CHANGELOG.md) — releases, fixes, and open items
- [Troubleshooting](docs/TROUBLESHOOTING.md) — diagnosing stream, lockscreen, and WebView problems
- [RELEASE-TODO.md](RELEASE-TODO.md) — Android notice/debug handoff and next-session order
- [docs/history/](docs/history/) — records of completed work, grouped by topic
