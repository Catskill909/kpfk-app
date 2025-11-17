# WPFW Radio App

A Flutter-based radio streaming application for WPFW 89.3 FM - Jazz & Justice Radio.

## ✅ CURRENT STATUS

**FULLY WORKING** on both iOS and Android with expert streaming implementation.
**16KB READY** - Complete Google Play 2025 compliance achieved 7+ months ahead of deadline.

## 🎯 EXPERT AUDIO SOLUTION

**Industry Standard M3U Parsing** - Same approach as Spotify, Apple Music, etc.

### The Solution:
```dart
// Expert M3U Resolution Process:
1. Fetch M3U playlist: https://docs.pacifica.org/wpfw/wpfw.m3u
2. Parse content to extract: https://streams.pacifica.org:9000/wpfw_128  
3. Use direct stream URL with AudioSource.uri() ✅
```

### Why This Works:
- **Android Compatibility**: Direct stream URLs work with AudioSource.uri()
- **iOS Preservation**: Zero changes to working App Store version
- **Industry Standard**: Same approach used by major streaming apps
- **Secure**: HTTPS throughout, no cleartext traffic

## Features

- 🎵 **Live Audio Streaming** - Professional M3U playlist parsing
- 📱 **Cross-Platform** - iOS (App Store) and Android support  
- 🔒 **iOS Lockscreen Integration** - Native controls and metadata
- 📊 **Real-time Metadata** - Show information and host details
- 🌐 **Network Resilience** - Automatic reconnection and error handling
- ⏰ **Sleep Timer** - Auto-stop functionality
- 🎨 **Modern UI** - Responsive design with accessibility support

## Technical Architecture
  - Full-screen dark-themed overlay with presets (15/30/45/60m) and a minute slider.
  - Countdown, pause/resume, and cancel.
  - On completion: performs a cold-start audio reset (stop, dispose player, clear iOS lockscreen, return to idle) to avoid residual state.
  - Entry: Bottom-right Alarm button on `HomePage`.
  - Docs: [timer.md](timer.md)
  - Source: `wpfw_radio/lib/presentation/widgets/sleep_timer_overlay.dart`, `wpfw_radio/lib/presentation/bloc/sleep_timer_cubit.dart`

- Donate Modal WebView
  - In-app modal sheet with `flutter_inappwebview`.
  - Handles external links by opening the system browser.
  - Accessible close control and announcements for page load/external launches.
  - Source: `wpfw_radio/lib/presentation/widgets/donate_webview_sheet.dart`

- Pacifica Apps & Services
  - Grid of Pacifica posts/apps/services fetched from WordPress API.
  - Replaces Settings when tapping the top-right icon on `HomePage`.
  - Source: `wpfw_radio/lib/presentation/pages/pacifica_apps_page.dart`, `wpfw_radio/lib/presentation/bloc/pacifica_bloc.dart`, `wpfw_radio/lib/data/repositories/pacifica_repository.dart`

- Offline awareness & recovery
  - Connectivity monitoring with graceful offline overlays and retry controls.
  - Source: `wpfw_radio/lib/presentation/widgets/offline_modal.dart`, `offline_overlay.dart`, `presentation/bloc/connectivity_cubit.dart`

- Accessibility baseline (Sep 5, 2025)
  - Screen-reader labels for core playback and donate flows, live announcements for playback states and errors.
  - Plan and next steps documented in [accessibity.md](accessibity.md).

### ✅ RESOLVED: iOS Lockscreen Metadata
- Resolved: Stable lockscreen metadata and working remote controls on iOS.
- Fix summary: Implemented native `MPNowPlayingInfoCenter` updates via platform channel, debounced updates to avoid churn, and wired `MPRemoteCommandCenter` handlers to Flutter (play/pause/toggle) so taps control the `WPFWAudioHandler`.
- Verification: VoiceOver reads current show/song on lockscreen; controls operate playback reliably without flicker.

### 🎉 RESOLVED: Android Lockscreen Controls (Samsung J7) - PRODUCTION READY
- **VICTORY**: Samsung J7 (Android 6.0-8.0) lockscreen controls now working perfectly!
- **Root cause**: Multiple competing MediaItem sources + missing AudioService.init() + 5-second metadata delay
- **Core fixes**: Single source of truth for MediaItem, proper AudioService.init(), eliminated package conflicts
- **Polish fixes**: Fixed 5-second delay, yellow color, generic flash, optimized controls (play/pause/close)
- **Status**: ✅ **PRODUCTION READY** - Professional lockscreen experience with stable metadata
- **Final result**: Clean, instant metadata display with appropriate streaming controls
- **Documentation**: [LOCKSCREEN-VICTORY-MASTER-TRUTH.md](LOCKSCREEN-VICTORY-MASTER-TRUTH.md) | [metadata-lock.md](metadata-lock.md)

### ✅ RESOLVED: Android Play/Pause Button Issues - REAL CULPRIT FOUND
- **VICTORY**: Samsung J7 caching bug completely eliminated after deep investigation!
- **Root cause**: AudioSource not being cleared on pause - remained set with cached stream data
- **Solution**: Use `_player.stop()` to clear AudioSource + re-set fresh AudioSource on play
- **Implementation**: Simple, standard approach - exactly like Spotify and Apple Music
- **Status**: ✅ **WORKING PERFECTLY** - Verified on Samsung J7 (Android 8.1.0 API 27)
- **Result**: Play starts fresh, pause resets completely, no cached audio confusion
- **Documentation**: [android-play-pause.md](android-play-pause.md) - Complete struggle and solution story

### 🎉 MAJOR ACHIEVEMENT: 16KB Page Size Compatibility - GOOGLE PLAY 2025 READY
- **VICTORY**: Successfully implemented complete 16KB page size support for Google Play Store 2025 requirements!
- **Critical deadline**: Google Play mandatory 16KB support by May 30, 2026 - **WE'RE READY 7+ MONTHS EARLY**
- **Toolchain modernization**: Flutter 3.27.4 → **3.35.4**, AGP 8.2.2 → **8.12.2**, Gradle 8.4 → **8.13**, Kotlin 1.9.22 → **2.1.0**
- **Build system**: Complete migration to declarative plugins block for Flutter 3.35.4 compatibility
- **16KB configuration**: Proper JNI packaging (`useLegacyPackaging = false`), multi-ABI support (arm64-v8a, armeabi-v7a, x86_64)
- **Status**: ✅ **PRODUCTION READY** - AAB built successfully (v1.0.1+4) with all 16KB requirements
- **Result**: App now meets all Google Play 2025 requirements, ensuring continued update capability beyond May 2026
- **Trade-off**: ~8% device support reduction (12,310+ phones still supported) for future-proofing compliance
- **Documentation**: [16kb-warning-fix.md](wpfw_radio/16kb-warning-fix.md) - Complete implementation journey

---

## Architecture Overview

- **Framework**: Flutter (Dart)
- **State management**: `flutter_bloc` + `get_it` service locator
- **Audio playback**: `just_audio` with `audio_service` and `audio_session`
- **Networking**: `dio` and `http`
- **Storage/Device**: `shared_preferences`, `path_provider`, `device_info_plus`
- **Web content**: `flutter_inappwebview`
- **UI**: Material 3 theme, Google Fonts, SVG, cached images

### Audio System Architecture (Updated January 2025)

**Single Source of Truth Design:**
```
┌─────────────────────────────────────────────────────────┐
│                    StreamRepository                     │
│                 (SINGLE SOURCE OF TRUTH)               │
│                                                         │
│  ┌─────────────────┐    ┌─────────────────────────────┐ │
│  │  StreamState    │    │    WPFWAudioHandler        │ │
│  │  - initial      │◄───┤    - Actual audio control  │ │
│  │  - loading      │    │    - Playback state        │ │
│  │  - playing      │    │    - Error handling        │ │
│  │  - paused       │    └─────────────────────────────┘ │
│  │  - error        │                                    │
│  └─────────────────┘                                    │
└─────────────────────────────────────────────────────────┘
            ▲                           ▲
            │                           │
    ┌───────────────┐          ┌─────────────────┐
    │   StreamBloc  │          │ NativeMetadata  │
    │   (UI Layer)  │          │ Service (iOS)   │
    │               │          │                 │
    └───────────────┘          └─────────────────┘
            ▲                           ▲
            │                           │
    ┌───────────────┐          ┌─────────────────┐
    │   HomePage    │          │ iOS Lockscreen  │
    │  (Play/Pause  │          │ Controls        │
    │   Buttons)    │          │                 │
    └───────────────┘          └─────────────────┘
```

**High-level flow:**
- `HomePage` renders the main experience with a single large play/pause control
- `StreamBloc` orchestrates playback via `StreamRepository` (single source of truth)
- `AudioStateManager` routes commands through `StreamRepository` for actual execution
- `WPFWAudioHandler` wraps `just_audio` and integrates with `audio_service`
- `NativeMetadataService` handles iOS lockscreen integration via platform channels
- All audio commands converge at `StreamRepository` ensuring perfect synchronization

## Project Structure

- `wpfw_radio/lib/presentation/pages/`
  - `home_page.dart`, `pacifica_apps_page.dart`
- `wpfw_radio/lib/presentation/widgets/`
  - `sleep_timer_overlay.dart`, `donate_webview_sheet.dart`, `app_drawer.dart`, `offline_modal.dart`, `offline_overlay.dart`, `sliding_panel.dart`, `station_webview.dart`
- `wpfw_radio/lib/presentation/bloc/`
  - `stream_bloc.dart`, `sleep_timer_cubit.dart`, `connectivity_cubit.dart`, `pacifica_bloc.dart`
- `wpfw_radio/lib/services/`
  - `audio_service/wpfw_audio_handler.dart`
  - `metadata_service.dart`, `metadata_service_native.dart`, `metadata/lockscreen_service.dart`, `ios_lockscreen_service.dart`
- `wpfw_radio/lib/data/`
  - `repositories/` (stream, pacifica, affiliate)
  - `models/` and `domain/models/`
- `wpfw_radio/lib/core/`
  - `di/` service locator, `services/` (connectivity, audio state manager, logger), `constants/`, `utils/`
- Docs: `wpfw_radio/docs/` (architecture notes, platform specifics, timelines)

## Packages / Dependencies

From `wpfw_radio/pubspec.yaml`:
- Audio: `just_audio`, `audio_service`, `audio_session`, `radio_player` (experimental)
- WebView: `flutter_inappwebview`
- State: `flutter_bloc`, `get_it`
- Network/Storage: `dio`, `http`, `connectivity_plus`, `path_provider`, `shared_preferences`, `device_info_plus`, `url_launcher`
- UI: `flutter_svg`, `cached_network_image`, `google_fonts`, `cupertino_icons`, `equatable`, `flutter_native_splash`
- Dev: `flutter_test`, `flutter_lints`, `flutter_launcher_icons`

See: `wpfw_radio/pubspec.yaml` for version pins.

## Setup & Build

Prereqs:
- Flutter SDK (stable) and platform toolchains (Xcode for iOS, Android SDK/NDK for Android)

Install dependencies:
```bash
flutter pub get
```

Run (Android):
```bash
flutter run -d android
```

Run (iOS Simulator):
```bash
flutter run -d ios
```

Build:
```bash
flutter build apk --release      # Android APK (signed with production keystore)
flutter build appbundle --release # Android AAB for Google Play Store (RECOMMENDED - 16KB READY)
flutter build ios                # iOS (requires Xcode signing)
```

**🎯 16KB Ready**: Current build (v1.0.1+4) includes complete 16KB page size support for Google Play 2025 requirements.

**🔐 Android Signing**: See **[ANDROID-SIGNING-ONE-TRUTH.md](ANDROID-SIGNING-ONE-TRUTH.md)** for complete keystore configuration and build instructions.

## Usage

- Open the app to the main `HomePage`.
- Tap the large play/pause button to start/stop the WPFW stream.
- Bottom-right Alarm button opens the Sleep Timer overlay.
- Bottom-left Donate button opens the in-app Donate modal WebView; external links open in the system browser.
- Tap the top-right icon to open the Pacifica Apps & Services grid.

## Accessibility

Basic screen reader support (Sep 5, 2025):
- Dynamic labels/hints for the play/pause control.
- Announcements for playback transitions (Loading, Buffering, Playing, Paused) and errors.
- Donate modal: labeled close button; announcements for page load and external browser opening.

Planned next steps (non-visual): focus traps in modals, `MergeSemantics` for metadata blocks, contrast/tap-target audits, and dev-only a11y tooling. See: [accessibity.md](accessibity.md).

## Platform specifics: iOS lockscreen metadata

- Background: iOS lockscreen metadata currently exhibits refresh/flicker and "Not Playing" alternation in some states.
- Approach: Implement native `MPNowPlayingInfoCenter` updates and `MPRemoteCommandCenter` handlers via platform channels from Flutter to Swift.
- Status: Documented; platform channel and native integration in progress.
- Docs:
  - `wpfw_radio/docs/iOS_LOCKSCREEN_METADATA_MASTER.md`
  - `wpfw_radio/docs/LOCKSCREEN_METADATA_FIX_APPROACH.md`
  - `wpfw_radio/docs/archive/iOS_LOCKSCREEN_COMPREHENSIVE.md`
  - Related issue notes: `wpfw_radio/docs/ANDROID_LOCKSCREEN_CONTROLS_ISSUE.md`

## Troubleshooting

- **Spinner stuck on loading (RESOLVED)**
  - ✅ **Fixed**: Automatic spinner timeout (10-second maximum) prevents stuck states
  - ✅ **Fixed**: Single source of truth architecture eliminates race conditions
  - ✅ **Fixed**: All commands now execute actual audio operations (no phantom state)

- **Play button unresponsive after network recovery (RESOLVED)**
  - ✅ **Fixed**: Simple solution - reset audio when network is lost, not recovered
  - ✅ **Fixed**: Clean separation of concerns - modal only handles appearance
  - ✅ **Fixed**: Play button works immediately after network recovery
  - Documentation: [NETWORK_RECOVERY_BUG_FINAL_SOLUTION.md](NETWORK_RECOVERY_BUG_FINAL_SOLUTION.md)

- Stream fails to start or frequently buffers
  - Check connectivity; see `connectivity_plus` status and retry from Snackbar.
  - Review logs via `LoggerService` in `wpfw_radio/lib/core/services/logger_service.dart`.
  - Note: Spinner will automatically reset after 10 seconds if stuck

- iOS lockscreen shows stale or no metadata
  - ✅ **Status**: iOS lockscreen functionality fully operational
  - Images and metadata display correctly with proper state synchronization
  - Remote controls (play/pause/toggle) work reliably

- WebView links not opening externally
  - Ensure `url_launcher` is properly configured for iOS/Android.
  - In Donate modal, unsupported schemes are handed off to the system browser.

## 📋 Documentation

For complete project documentation, see **[DOCUMENTATION-INDEX.md](DOCUMENTATION-INDEX.md)** - organized reference to all project docs.

### 🎯 Key Implementation Docs:
- **16KB Compatibility**: [16kb-warning-fix.md](wpfw_radio/16kb-warning-fix.md) - Complete Google Play 2025 requirements implementation
- **Android Lockscreen**: [LOCKSCREEN-VICTORY-MASTER-TRUTH.md](LOCKSCREEN-VICTORY-MASTER-TRUTH.md) - Samsung J7 lockscreen controls solution
- **Audio Architecture**: [android-play-pause.md](android-play-pause.md) - Play/pause button caching bug resolution
- **Network Recovery**: [NETWORK_RECOVERY_BUG_FINAL_SOLUTION.md](NETWORK_RECOVERY_BUG_FINAL_SOLUTION.md) - Network connectivity handling

## 🎯 Lockscreen Controls - Quick Reference

### CRITICAL SUCCESS FACTORS (DO NOT CHANGE):
1. **Single MediaItem Source**: Only `_broadcastState()` calls `mediaItem.add()`
2. **AudioService.init()**: Must have `androidStopForegroundOnPause: true`
3. **Package Dependencies**: No `get_it` or `radio_player` conflicts
4. **Service Locator**: Preserve `WPFWAudioHandler.create()` pattern
5. **Audio Focus**: `AudioSession.setActive(true)` for Samsung devices

### ENHANCEMENT AREAS:
- 🎨 **Styling**: Improve lockscreen control appearance
- 🖼️ **Album Art**: Add WPFW logo display
- 📊 **Metadata**: Enhanced title/artist formatting
- 🎛️ **Controls**: Additional playback options

### DEBUGGING:
- Look for "🎯 ONE TRUTH" logs to trace MediaItem flow
- Monitor for oscillation patterns in logs
- Verify AudioService.init() completion logs

---

## Roadmap / Backlog

### ✅ Completed (September 2025)
- ✅ **Spinner bug resolution**: Complete architectural fix with timeout protection
- ✅ **Audio state management**: Single source of truth implementation
- ✅ **iOS lockscreen functionality**: Stable metadata and working remote commands
- ✅ **Android lockscreen controls**: Samsung J7 lockscreen controls working
- ✅ **Pause behavior enhancement**: Clear play/pause semantics
- ✅ **Network recovery bug resolution**: Simple, elegant solution with clean separation of concerns
- ✅ **Android play/pause button fix**: Real culprit found and fixed - AudioSource clearing issue resolved (Samsung J7)
- ✅ **16KB page size compatibility**: Complete Google Play 2025 requirements implementation (Flutter 3.35.4, AGP 8.12.2, Gradle 8.13)
- ✅ **Build system modernization**: Declarative plugins migration, Kotlin 2.1.0 update, multi-ABI support
- ✅ **Future-proofing**: 7+ months ahead of Google Play May 2026 deadline

### 🎯 Future Enhancements
- 🎨 **Lockscreen styling improvements**: Enhanced visual appearance and metadata display
- 🖼️ **Album art integration**: WPFW logo and dynamic artwork on lockscreen
- Add focus management and semantics grouping for overlays/modals
- Introduce CI a11y checks (e.g., `accessibility_lint`) and basic widget tests for semantics
- Improve contrast and typography in dark theme as needed (AA level)
- Performance optimizations and memory usage improvements
- Enhanced error recovery and network resilience