# Xcode Archive Warnings — Baseline

**Baseline captured:** 2026-08-19, archiving `1.0.2 (14)` — **validation passed.**

## The short version

**None of these are actionable, and none are show-stoppers.** Every warning
produced by an archive of this project lives in **third-party code**:

- `~/.pub-cache/hosted/pub.dev/...` — plugin sources (`audio_service`,
  `audio_session`, `flutter_inappwebview_ios`)
- `ios/Pods/swift-collections/...` — a transitive dependency

**Zero warnings come from `lib/` or `ios/Runner/`.** They are deprecation
notices — code that still compiles and runs — not errors. App Store validation
passes with all of them present.

## Why this document exists

Reviewing ~40 warnings on every archive is unsustainable, and the instinct to
"clean them up" leads nowhere: they can only be fixed by the package authors.

The useful thing is a **baseline**. If a future archive produces a warning that
is *not* on this list — especially one pointing at `lib/` or `ios/Runner/` —
that is new, it is yours, and it deserves attention. Everything below is noise
to be skipped.

## The baseline

### `audio_service` 0.18.18
| Warning | Since |
|---|---|
| `initWithImage:` deprecated — use `-initWithBoundsSize:requestHandler:` | iOS 10 |

### `audio_session` 0.1.25
| Warning | Since |
|---|---|
| `AVAudioSessionInterruptionWasSuspendedKey` deprecated — see `AVAudioSessionInterruptionReasonKey` | iOS 14.5 |

### `flutter_inappwebview_ios` 1.2.0-beta.3
The bulk of the output (~35 warnings). All deprecations:

| Theme | Examples | Since |
|---|---|---|
| WebView config | `javaScriptEnabled`, `selectionGranularity`, `clearCache`, `processPool` / `WKProcessPool` | iOS 11–15 |
| Window access | `keyWindow`, `windows` — "should not be used for apps supporting multiple scenes" | iOS 13–15 |
| Security | `SecTrustEvaluate`, `SecTrustGetCertificateAtIndex` | iOS 13–15 |
| Auth | `SFAuthenticationSession` → `ASWebAuthenticationSession` | iOS 12 |
| Misc | `spotlightSuggestion`, `closeAllMediaPresentations()`, `onFindResultReceived`, `SafariViewController.init(url:entersReaderIfAvailable:)` | iOS 10–15 |
| Code smell | "Comparing non-optional value of type `[Any]` to nil always returns true"; "Unnecessary check for 'iOS'" | — |

> **Note on the version:** `pubspec.yaml` declares `flutter_inappwebview: ^6.1.8`
> (stable). The `1.2.0-beta.3` in the paths is the plugin's **federated iOS
> implementation package**, which upstream versions separately. This is what
> `^6.1.8` resolves to — it is not a beta that was opted into here.

### `swift-collections`
| Warning | Status |
|---|---|
| `Stored property '_storage' of 'Sendable'-conforming struct 'Iterator' has non-Sendable type` — "an error in the Swift 6 language mode" | **Already mitigated.** `ios/Podfile` `post_install` pins `SWIFT_VERSION = '5.0'` for the `swift-collections` target specifically so this stays a warning rather than an error. Do not remove that pin. |

## The one with a real horizon

Several `flutter_inappwebview_ios` warnings — `keyWindow`, `windows`,
"applications that support multiple scenes" — are the same underlying issue as
the notice Flutter prints on every build:

> To ensure your app continues to launch on upcoming iOS versions, UIScene
> lifecycle support will soon be required.

That is a **Flutter-framework-level migration**, not something to hand-patch in
this app. It will arrive via a Flutter upgrade. Track it; do not chase it here.

## What to do on a future archive

1. If validation **passes** — ship. Warnings above are expected.
2. If a warning appears that is **not** on this list, check its path first:
   - `~/.pub-cache/` or `ios/Pods/` → third-party, note it, move on
   - `lib/` or `ios/Runner/` → **yours, investigate**
3. If the warning count jumps dramatically, a dependency moved. Check
   `Podfile.lock` and `pubspec.lock` before assuming it is a real problem.
4. Never silence these by disabling deprecation warnings project-wide — that
   would also hide warnings in your own code, which are the ones that matter.
