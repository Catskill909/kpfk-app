# Troubleshooting

Diagnostic notes for developers. Feature documentation lives in the
[app README](../README.md); the record of past fixes is in the
[development history](../../docs/CHANGELOG.md).

## Stream fails to start, or buffers frequently

- Check connectivity first. Connection notices offer **Try again**; a confirmed
  station outage instead asks the listener to check back later — the two are
  distinct states, not one generic error.
- Review logs via `LoggerService` in `lib/core/services/logger_service.dart`.
- To reproduce a specific failure without waiting for a real one, use the
  debug-only outage panel — see
  [TESTING_outage_scenarios.md](TESTING_outage_scenarios.md).
- Server-side 5xx responses must classify as a station outage, not a listener
  connectivity problem. `audio_server_health_checker_test.dart` covers this.

## iOS lockscreen shows stale or missing metadata

- Confirm the native integration is present and the platform channels are wired
  through to `KPFKAudioHandler`.
- The lockscreen "Now Playing" slot must be reclaimed on play; a gap between the
  play action and `setAudioSource` lets a previously-playing app's artwork show
  through.
- Full system reference:
  [iOS_LOCKSCREEN_METADATA_MASTER.md](iOS_LOCKSCREEN_METADATA_MASTER.md).

## Android media notification issues

- Blank artwork on play usually means the MediaSession is reporting
  `STATE_NONE` during an audio-source rebuild.
- A notification stuck in the tray after closing while paused usually means the
  service is not running in the foreground.
- Diagnose with `adb logcat`, not `flutter` logs — the relevant transitions
  happen in native code.
- See [ANDROID_LOCKSCREEN_CONTROLS_ISSUE.md](history/ANDROID_LOCKSCREEN_CONTROLS_ISSUE.md)
  and [ANDROID_STREAM_DIAGNOSTICS_AND_DROPOUTS.md](history/ANDROID_STREAM_DIAGNOSTICS_AND_DROPOUTS.md).

## WebView links not opening externally

- Verify `url_launcher` is configured for both iOS and Android.
- In the donate modal, unsupported URL schemes are handed off to the system
  browser rather than loaded in-app.

## iOS build number not incrementing

Xcode's Archive step does not bump the build number on its own. After editing
`version:` in `pubspec.yaml`, regenerate `Generated.xcconfig`:

```bash
flutter build ios --config-only
```

See [VERSION_MANAGEMENT.md](VERSION_MANAGEMENT.md) and
[XCODE_RECOMMENDED_SETTINGS_WORKFLOW.md](XCODE_RECOMMENDED_SETTINGS_WORKFLOW.md).
