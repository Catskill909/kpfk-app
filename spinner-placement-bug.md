# Spinner Placement Bug — Root Cause Audit

## Problem
The loading spinner renders OUTSIDE the play/pause button's dark circular background, no matter what size we set the spinner to.

## Root Cause
**`IconButton` with Material 3 styling separates icon size from button background size.**

- `iconSize: 120` sets the **icon widget** to 120px
- `IconButton.styleFrom(backgroundColor, shape: CircleBorder())` creates a button background whose size is governed by **M3 default minimums (~48px)**, NOT by `iconSize`
- `padding: EdgeInsets.zero` removes padding but does NOT force the background to match iconSize

### Why it looked fine with play/pause icons
`Icons.play_circle_filled` is a **filled white circle** at 120px. It completely covers and overflows the tiny ~48px dark background. You never see the mismatch because the white icon is always larger.

### Why the spinner breaks
The `CircularProgressIndicator` inside a `SizedBox` is NOT a filled shape — it's a thin ring. At any size, the dark background circle doesn't match, so the spinner visually floats outside or misaligns with the expected button boundary.

## Fix
Replace `IconButton` with explicit `Material` + `InkWell` + `SizedBox` so we control:
1. **Background circle size** = exactly `iconSize` (90/120/150)
2. **Spinner size** = proportional to background (~42% of iconSize)
3. **Icon size** = same as background (filled circle covers it)

This guarantees the dark circular background, the spinner, and the play/pause icons all share the same coordinate space with explicit dimensions.

## Files Changed
- `lib/presentation/pages/home_page.dart` — lines ~466-572 (playback control widget)

## What's NOT affected
- BLoC events/state (`stream_bloc.dart`) — untouched
- `_showLocalLoading` state management — same setState/clear logic
- Lock screen / media controls (`AudioStateManager`, `KPFKAudioHandler`) — untouched
- Metadata service — untouched
- `onPressed` play/pause dispatch — identical logic, just moved to `InkWell.onTap`
