# App Development History

Records of completed work. **These are not current guidance** — they document
what was investigated, tried, and shipped. Where they conflict with the
[current docs](../README.md), the current docs win.

Many carry the enthusiasm of the moment they were written ("THE REAL BUG",
"FINALLY FIXED", "NUCLEAR FIX"). They are kept because they explain *why* the
code looks the way it does, and because the dead ends are worth not repeating.

For the chronological narrative, see the
[development history](../../../docs/CHANGELOG.md).

---

## iOS lockscreen artwork & metadata

The longest-running investigation in the project. Artwork and metadata failing
to appear — or appearing stale — on the iOS lockscreen. Documents are listed in
roughly the order the work happened; **the resolved design is described in
[iOS_LOCKSCREEN_METADATA_MASTER.md](../iOS_LOCKSCREEN_METADATA_MASTER.md)**, not
here.

**Analysis and forensics**

- [lockscreen-image-bug.md](lockscreen-image-bug.md) — the original deep forensic audit
- [LOCKSCREEN_DEEP_AUDIT_V3.md](LOCKSCREEN_DEEP_AUDIT_V3.md) — third-pass audit
- [metadata-feed-lockscreen.md](metadata-feed-lockscreen.md) — metadata feed's role in the image bug
- [lock-screen-image.md](lock-screen-image.md) — image metadata analysis
- [lock-screen-thread-analysis.md](lock-screen-thread-analysis.md) — threading audit
- [CATCH_THE_OVERRIDE.md](CATCH_THE_OVERRIDE.md) — forensic test isolating what was overwriting the artwork
- [gpt-lock.md](gpt-lock.md) — long external expert review (2,154 lines)
- [gpt4-fix1.md](gpt4-fix1.md) — condensed recommendations from that review

**Approaches and fixes, in sequence**

- [LOCKSCREEN_METADATA_FIX_APPROACH.md](LOCKSCREEN_METADATA_FIX_APPROACH.md) — initial approach
- [LOCKSCREEN_ARTWORK_FLOW.md](LOCKSCREEN_ARTWORK_FLOW.md) — before/after flow diagrams
- [LOCKSCREEN_FIX_V2.md](LOCKSCREEN_FIX_V2.md) — second attempt: immediate text display
- [NUCLEAR_FIX_README.md](NUCLEAR_FIX_README.md) — aggressive artwork protection
- [STANDARD_FIX_PLAN.md](STANDARD_FIX_PLAN.md) — the pivot to standard Flutter patterns
- [STANDARD_FLUTTER_FIX_APPLIED.md](STANDARD_FLUTTER_FIX_APPLIED.md) — that plan, applied
- [THE_REAL_BUG_FOUND.md](THE_REAL_BUG_FOUND.md) / [FINALLY_FIXED.md](FINALLY_FIXED.md) — the actual root cause
- [LOCKSCREEN_FIX_FINAL.md](LOCKSCREEN_FIX_FINAL.md) — final fix
- [LOCKSCREEN_ARTWORK_FIX_SUMMARY.md](LOCKSCREEN_ARTWORK_FIX_SUMMARY.md) / [LOCKSCREEN_FIX_README.md](LOCKSCREEN_FIX_README.md) — implementation summaries

**Test guides**

- [LOCKSCREEN_TEST_NOW.md](LOCKSCREEN_TEST_NOW.md), [TEST_LIFECYCLE_FIX.md](TEST_LIFECYCLE_FIX.md)

## Audio & playback reliability

- [streaming-audio-deep-audit.md](streaming-audio-deep-audit.md) — full audit of the streaming audio functions
- [fix-audio-play.md](fix-audio-play.md) — play button reliability audit and fix plan
- [android-play-pause.md](android-play-pause.md) — Android play/pause analysis and ground plan
- [pause-play-cache.md](pause-play-cache.md) — play/pause cache regression analysis
- [android-audio-final-analysis.md](android-audio-final-analysis.md) — final Android audio analysis
- [ANDROID_STREAM_DIAGNOSTICS_AND_DROPOUTS.md](ANDROID_STREAM_DIAGNOSTICS_AND_DROPOUTS.md) — dropout diagnostics
- [ANDROID_LOCKSCREEN_CONTROLS_ISSUE.md](ANDROID_LOCKSCREEN_CONTROLS_ISSUE.md) — Android notification/lockscreen controls investigation
- [audio-aniamtion.md](audio-aniamtion.md) — play/pause control animation responsiveness

## Stream outage notices

- [STREAM_OFFLINE_MODAL_AUDIT.md](STREAM_OFFLINE_MODAL_AUDIT.md) — full flow, fixes, and code audit behind the current notice design
- [DEVICE_TEST_outage_2026-08-14.md](DEVICE_TEST_outage_2026-08-14.md) — iOS device test run
- [alert.md](alert.md) — original connectivity check + offline modal plan
- [NETWORK_ALERT_IMPLEMENTATION.md](NETWORK_ALERT_IMPLEMENTATION.md) — network alert system implementation

## iOS build & configuration

- [ios-warnings.md](ios-warnings.md) — the phased build-warning cleanup (Phases 1–3B)
- [ios-warnings-root.md](ios-warnings-root.md) — categorized warning action plan
- [ios-fixes.md](ios-fixes.md) — required iOS fixes
- [apple-id-update.md](apple-id-update.md) — bundle identifier change to `app.pacifica.kpfk`

## Feature rollouts

- [pacifica_apps_implementation.md](pacifica_apps_implementation.md) — Pacifica apps & services grid
- [FONT_IMPLEMENTATION.md](FONT_IMPLEMENTATION.md) — custom typography plan (Oswald/Poppins)
- [SOCIAL_MEDIA_IMPLEMENTATION.md](SOCIAL_MEDIA_IMPLEMENTATION.md) — social icons
- [UI_REDESIGN.md](UI_REDESIGN.md) — UI redesign specification
- [METADATA_FEED_UPDATE.md](METADATA_FEED_UPDATE.md) — feed change, `sh_photo` → `big_pix`
- [HTML_ENTITY_IMPROVEMENTS.md](HTML_ENTITY_IMPROVEMENTS.md) — entity handling in feed text
- [ICON_UPDATE_LOG.md](ICON_UPDATE_LOG.md) — app icon and adaptive icon work

## Superseded project records

Kept for provenance; the current equivalents are linked in each row.

- [PROJECT_DIRECTORY.md](PROJECT_DIRECTORY.md) — old structure map → see [app README](../../README.md#project-structure)
- [PROJECT_TIMELINE.md](PROJECT_TIMELINE.md) — WPFW-era timeline → see [CHANGELOG](../../../docs/CHANGELOG.md)
- [IMPLEMENTATION_NOTES.md](IMPLEMENTATION_NOTES.md) — early notes and required changes
