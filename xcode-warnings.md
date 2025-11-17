# Xcode Warnings — Tracking & Remediation Guide

Last updated: 2025-09-05
Scope: iOS build/archive for `wpfw_radio`

This document categorizes current Xcode warnings into:
- Quick fixes (project-level changes we can apply immediately)
- Plugin-origin warnings (require upstream updates or a local fork/patch)
- Active issue: iOS lockscreen metadata refresh behavior

Referenced sources:
- Build log snapshot in `xcode_warnings.txt`
- Current package versions in `wpfw_radio/pubspec.yaml`

---

## Quick Fixes (Project-level)

1) Runner — Ignoring duplicate libraries: '-lswiftCoreGraphics'
- Symptom: Linker emits "Ignoring duplicate libraries" for `-lswiftCoreGraphics`.
- Likely cause: Duplicate entries in Build Settings → Other Linker Flags or in Build Phases → Link Binary With Libraries.
- Action:
  - In Xcode, open `ios/Runner.xcworkspace` → Target `Runner`.
  - Check Build Settings → Other Linker Flags for repeated `-lswiftCoreGraphics`. Remove duplicates.
  - Also check Build Phases → Link Binary With Libraries for duplicate frameworks.
- Impact: Warning only; safe to clean up.
- Status: Pending.

2) Assets — App Icon set has 6 unassigned children
- Path: `wpfw_radio/ios/Runner/Assets.xcassets/AppIcon.appiconset`
- Symptom: "The app icon set 'AppIcon' has 6 unassigned children" and a note about `76x76@1x` applying only to old iPad targets.
- Action:
  - Open Xcode → Assets → AppIcon.
  - Either fill required sizes or remove deprecated/unneeded slots in `Contents.json` via the editor.
  - Ensure `flutter_launcher_icons` config aligns with required sizes. See `pubspec.yaml` → `flutter_launcher_icons`.
- Impact: Cosmetic; App Store may still accept if primary icons are valid. Best to resolve.
- Status: Pending.

3) Orientation policy — "All interface orientations must be supported unless the app requires full screen"
- Symptom: Global warning during build.
- Action (choose one):
  - If the app is iPhone-only portrait: set `Requires full screen` = YES (General tab) and limit `UISupportedInterfaceOrientations` to needed ones in `Info.plist`.
  - Or explicitly support all device orientations as per Apple guidance.
- Impact: Warning; clarify UI policy before submission.
- Status: Pending.

4) Storyboard deployment target older than app deployment target (from flutter_inappwebview_ios)
- Symptom: `WebView.storyboard` is set to build for version older than deployment target (iOS 12.0+ project).
- Action:
  - In Xcode, open Pods project → the `flutter_inappwebview_ios` storyboard file and set it to match the project's deployment target (if Xcode allows), or ignore (plugin-managed).
- Impact: Warning; safe to ignore if functionality is unaffected.
- Status: Pending/Low priority.

5) Build scripts always run (Run Script, Thin Binary)
- Symptom: Xcode notes that the Run Script and Thin Binary phases will run every build because "Based on dependency analysis" is unchecked.
- Action:
  - In Xcode, target `Runner` → Build Phases → expand each script phase.
  - Check the box "Based on dependency analysis" for:
    - Run Script (Flutter)
    - Thin Binary
  - If present, ensure input/output file lists are set to enable incremental behavior.
- Impact: Speeds up builds and removes notes/warnings.
- Status: Pending.

---

## Plugin-origin Warnings (Upstream or fork/patch)

These originate within `.pub-cache` plugin sources and generally require waiting for upstream fixes or applying a temporary fork with a patch.

A) audio_service
- Example: `'initWithImage:' is deprecated` (iOS 10 deprecation in `AudioServicePlugin.m`).
- Current version in cache: 0.18.18 (resolved from `^0.18.12`).
- Notes:
  - Deprecation warnings are expected; functionality is fine. Track upstream for modernization.
- Action: Check for a newer `audio_service` release; otherwise ignore.
- Status: Monitor.

B) flutter_inappwebview / flutter_inappwebview_ios
- Examples:
  - `spotlightSuggestion` deprecated → use `WKDataDetectorTypes.lookupSuggestion`.
  - `clearCache` deprecated in favor of `InAppWebViewManager.clearAllCache`.
  - `SFAuthenticationSession` deprecated → `ASWebAuthenticationSession`.
  - Unnecessary `#available(iOS ...)` guard.
  - Storyboard deployment target mismatch (see Quick Fix 4).
- Current version: `flutter_inappwebview: ^6.1.8` with iOS submodule `flutter_inappwebview_ios-1.2.0-beta.2`.
- Notes:
  - Many are deprecations; plugin likely maintains backward compatibility across iOS versions.
- Actions:
  - Check for non-beta `flutter_inappwebview_ios` release corresponding to `6.1.8+`.
  - If warnings are noisy, consider pinning to a version whose iOS submodule is stable (non-beta) or accept warnings.
- Status: Monitor/Optional fork if needed.

C) flutter_native_splash
- Warning: `no rule to process ... PrivacyInfo.xcprivacy of type 'text.xml' for architecture 'arm64'`.
- Current version: `flutter_native_splash: ^2.3.10` (cache shows 2.4.4 used during iOS build).
- Notes:
  - Related to Apple Privacy Manifest support in Xcode 15+.
- Actions:
  - Update `flutter_native_splash` to the latest (2.4.6+ typically addresses processing rules).
  - After `flutter pub upgrade`, run `flutter pub run flutter_native_splash:create` to regenerate iOS assets.
  - If persists, remove any stray `.xcprivacy` from Runner target's "Compile Sources" and keep it under "Copy Bundle Resources" only, or exclude via file patterns in Pods (advanced).
- Status: Recommend update.

D) radio_player
- Warning: `Coercion of implicitly unwrappable value of type 'String?' to 'Any' does not unwrap optional` at `RadioPlayer.swift:23` for `streamTitle`.
- Current version: `radio_player: ^1.7.1`.
- Notes:
  - Code sets `MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: streamTitle, ]` where `streamTitle` is `String!`.
- Actions:
  - Upstream PR suggestion: change to `[MPMediaItemPropertyTitle: streamTitle as Any]` or provide default `streamTitle ?? ""`.
  - Temporary local fork if we adopt `radio_player` long-term. Otherwise, warning is benign.
- Status: Monitor/Patch if we keep plugin.

---

## App-owned Swift warnings (we can fix)

1) `AppDelegate.swift` — use `let` for non-mutated vars and remove unused `[weak self]`
- Examples:
  - `var nowPlayingInfo` should be `let nowPlayingInfo` when not mutated.
  - Closures with `[weak self]` where `self` is unused → remove capture list.
- Paths:
  - `wpfw_radio/ios/Runner/AppDelegate.swift` (lines ~107, 125 in snapshot)
- Action: Update code to silence warnings.
- Status: Pending.

2) `MetadataController.swift` — same cleanups
- Examples:
  - `var nowPlayingInfo` → `let`
  - Remove `[weak self]` in `addTarget` closures if unused.
  - `updatedNowPlayingInfo` is never mutated → `let`.
- Path: `wpfw_radio/ios/Runner/MetadataController.swift` (lines ~101, 105, 109, 273, 292 in snapshot)
- Action: Update code.
- Status: Pending.

---

## Active Issue: iOS Lockscreen Metadata Refresh (Flicker)

- Problem: iOS lockscreen metadata appears correctly but refreshes/flickers every 1–2 seconds.
- Root Cause: Multiple competing update cycles in iOS native code causing constant refreshes.
- Solution Direction: Implement a singleton `MetadataController` in Swift with strict update debouncing and a single source of truth for `MPNowPlayingInfoCenter` updates.
- Integration Notes:
  - Ensure only one update pipeline writes to `MPNowPlayingInfoCenter.default().nowPlayingInfo`.
  - Debounce network/metadata changes and ignore no-op updates.
  - Connect `MPRemoteCommandCenter` handlers to Flutter through a `MethodChannel` to control playback (play/pause/toggle), per the design in our documentation.
- Documentation: See internal docs for plan and status (LOCK_SCREEN_FIX_V3, comprehensive metadata analysis).
- Status: In progress.

---

## Recommendations & Next Steps

- Apply Quick Fixes 1–3 in Xcode and commit the settings changes.
- Clean up Swift warnings in `AppDelegate.swift` and `MetadataController.swift`.
- Attempt plugin updates:
  - `flutter_native_splash` → latest. Regenerate assets.
  - Re-run `flutter pub upgrade` to pull latest compatible `audio_service` and `flutter_inappwebview` minor fixes.
- Decide on `radio_player` usage. If we keep it, consider a small PR/fork to address the `streamTitle` optional warning.
- Continue implementing the debounced singleton metadata path to stop lockscreen flicker.

---

## Appendix: Current dependency snapshot (pubspec.yaml)

- just_audio: ^0.9.34
- audio_service: ^0.18.12 (resolved to 0.18.18 at build time)
- audio_session: ^0.1.25
- flutter_inappwebview: ^6.1.8 (iOS submodule 1.2.0-beta.2)
- flutter_native_splash: ^2.3.10 (cache shows 2.4.4 during build; recommend upgrade)
- radio_player: ^1.7.1
