# Project Documentation

Project-level docs for the KPFK Radio app. App-internal engineering docs live in
[`../kpfk_radio/docs/`](../kpfk_radio/docs/).

## Current

| Doc | What it's for |
| --- | --- |
| [CHANGELOG.md](CHANGELOG.md) | **Development history and release record** — start here to see what changed and when, plus open items |
| [QUICK-START.md](QUICK-START.md) | Detailed setup and configuration walkthrough |
| [android-build.md](android-build.md) | Android build guide — toolchain, gradle config, release steps |

## Recurring-issue master records

These describe bugs that have come back more than once. Read the relevant one
*before* touching that area — each records the root cause and the fix that
actually holds.

| Doc | Guards against |
| --- | --- |
| [audio-play-bug.md](audio-play-bug.md) | **Live stream must ALWAYS play live, NEVER the cache.** `play()` rebuilds unconditionally — no resume path, no staleness window. Also: `completed` on a live stream is always a failure, never a clean stop. Includes the Android notification/MediaSession audit |
| [lock-screen-bug.md](lock-screen-bug.md) | iOS lockscreen "previous app flashes on play" — caused by the gap during `setAudioSource`. **The fix is the native `reassertNowPlaying` pre-claim, NOT resume-in-place** (reversed 2026-08-18 — resume-in-place caused stale-audio playback) |
| [main-screen-layout-fix.md](main-screen-layout-fix.md) | Home station image must be sized by **width**. Sizing it from leftover vertical space shrinks it — this has regressed repeatedly |

## Cross-app

| Doc | What it's for |
| --- | --- |
| [wbai-handoff.md](wbai-handoff.md) | Porting layout, responsive sizing, and portrait lock to the sister WBAI app |

The KPFK, WBAI, and WPFW apps share a codebase lineage — fixes in one usually
need porting to the others.

## [history/](history/)

Completed work: the WPFW→KPFK transformation records and closed bug
post-mortems. Kept for reference, not current guidance. See
[history/README.md](history/README.md).
