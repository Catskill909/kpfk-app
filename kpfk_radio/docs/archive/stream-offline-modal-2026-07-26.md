# Stream-Offline Modal Redesign — KPFK

**2026-07-26.** Ported from the WBAI sister app (see WBAI's
`stream-offline-modal.md`). Reworked the "audio server unavailable" experience
into a friendly, high-contrast notice.

## Why
The old modal surfaced the raw technical string ("Stream not found on server")
as its headline. KPFK is a **dark-only** app, so it did *not* have WBAI's
black-on-dark contrast bug (its `bodyMedium` is white) — but the UX was still
technical and the transient snackbar re-stated the same raw error.

## What changed
| File | Change |
|---|---|
| `presentation/widgets/audio_server_error_modal.dart` | Full rebuild, self-styled for KPFK's dark surface: `0xFF1C1413` card, white ink, **KPFK brand-red accent** (`0xFFE53935`) badge (`wifi_tethering_off`) + button. Friendly headline **"We'll be right back"** + "check back in a little while" copy, full-width "Got it" button. Raw `customMessage` kept only as a tiny muted detail line, never the headline. |
| `presentation/pages/home_page.dart` | Snackbar copy/style upgraded to match: dark `0xFF1C1413` bg, white friendly copy ("Stream unavailable — please try again shortly"), red Retry action; `hideCurrentSnackBar()` first to avoid stacking. (The `!state.showServerErrorModal` guard that prevents double-notification was already present.) |

## 2026-07-26 (later) — real-outage fixes (ported from WBAI)
Two bugs a real outage exposed, fixed in both apps:

- **Modal/snackbar wouldn't clear.** `StreamBlocState.copyWith` used
  `errorMessage ?? this.errorMessage`, so `copyWith(errorMessage: null)` kept
  the stale message → after "Got it" the snackbar re-fired. Fixed with a
  `_noUpdate` sentinel default so an explicit `null` truly clears.
- **Snackbar stranded behind the modal.** The generic `UpdatePlaybackState(error)`
  bridge can arrive before `ServerErrorOccurred` raises the modal. `home_page.dart`
  now calls `hideCurrentSnackBar()` whenever `state.showServerErrorModal` is true.

(Pressing play again during a still-live outage *should* re-show the modal.)

## Notes
- Invoked from `home_page.dart` on `state.showServerErrorModal`; dismiss
  dispatches `ClearServerError`.
- Preview via `ServerErrorOccurred(msg)` on the `StreamBloc` — never hardcode
  `showServerErrorModal: true` into the initial state (undismissable on launch).
- `flutter analyze` clean on both changed files.

---

**Superseded 2026-08-14.** This changelog describes the snackbar-based design
that has since been removed. See `docs/FEATURE_stream_offline_notice.md` for the
current behaviour and `docs/STREAM_OFFLINE_MODAL_AUDIT.md` §v4 for why.
