# Outage device test — 2026-08-14

Device: physical iPhone, iOS 26.6  
Build: Flutter debug build  
Source: attached `flutter run` device logs plus on-device visual/audio checks

## Results

| Scenario | Result | Device-log evidence | Follow-up |
|---|---|---|---|
| Server refuses connection | Pass | Play at 10:53:55; watchdog classified `serverUnavailable` and raised the outage flow at 10:54:03 (~8s) | None |
| Server times out | Pass after fix | Original run: Play at 10:54:19; classification at 10:54:32 (~13s), followed by an unwanted ~82s reset. Retest: Play at 11:08:32; modal path emitted at 11:08:45 (~13s), with audio controls cleared by 11:08:45 | Fixed: notice precedes cleanup and cleanup does not reload the broken URL |
| Playlist 404 | Pass with classification gap | Play at 10:56:51; outage flow raised at 10:56:59 (~8s), internally classified as `unknownError` | Preserve HTTP 404 as `streamNotFound` if practical |
| Playlist has no stream | Partial | Play at 10:57:14; host health probe returned 206, reconnect exhausted, then a `connection` notice was raised at 10:57:28 | Detect invalid/no-stream playlist as an outage, matching the documented expectation |

## Timeout follow-up

Implemented after this run: confirmed outages are now emitted to the UI before
audio cleanup begins, and server-error cleanup no longer calls
`resetToColdStart()`. That method tried to resolve and load the already-confirmed
broken endpoint again, accounting for the additional ~82-second delay above.
The next explicit Play already rebuilds an idle source. The physical-device
retest confirmed the modal path at ~13 seconds with cleanup completing in the
same second; the additional ~82-second wait is gone.

## Test-panel correction made during the run

Selecting a preset originally left the previously loaded iOS live source alive,
so Play resumed the real stream regardless of the selected override. Preset
selection now dispatches `StopStream`, forcing the next Play to cold-load the
selected URL. The home-screen debug bug icon also opens Outage Testing directly.
Preset confirmation uses a branded, acknowledged modal rather than a fleeting
snackbar. It offers **Go to player** or **Keep testing** and remains visible
until the tester chooses.

## Unrelated diagnostic observed

The outage cleanup attempted `clearNowPlaying` on the WPFW channel
`com.wpfwfm.radio/now_playing`, producing a `MissingPluginException` in KPFK.
The outage flow continued, but the channel identifier should be audited
separately.
