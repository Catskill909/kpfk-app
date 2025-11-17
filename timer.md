# Sleep Timer: Deep Plan and Architecture

This document plans a robust, dark-mode "Sleep Timer" overlay triggered from the bottom-right Alarm icon on the main screen (`wpfw_radio/lib/presentation/pages/home_page.dart`). The design prioritizes a beautiful, minimal UI and bulletproof audio reset behavior that returns the app to the same cold-start state when the timer completes.

---

## 1) Product Goals

- Provide an intuitive sleep timer that lets listeners stop playback after a chosen duration.
- Ensure that when the timer completes, all audio is fully stopped and reset so the app behaves like a fresh launch (no residual buffers, no dangling sessions, no lockscreen metadata).
- Fit the app’s dark theme, with elegant motion and clear affordances.

---

## 2) UX / UI Design (Dark Mode Overlay)

- Entry: Tap bottom-right Alarm icon on `HomePage`.
- Presentation: Full-screen modal overlay using `showGeneralDialog` with fade + slight scale or a `PageRouteBuilder` for smooth Material motion.
- Visuals:
  - Dimmed scrim over content.
  - Center card (Material 3) with rounded corners, elevated 6–8 dp.
  - Title: "Sleep Timer".
  - Time selector:
    - Quick presets: 15m, 30m, 45m, 60m.
    - A slider (5–120 minutes) with labeled value.
  - Active state:
    - Large circular progress ring around a timer countdown.
    - Pause/Resume and Cancel actions.
  - Actions row at bottom: Start / Cancel (contextual).
  - Haptics on key interactions.
- Accessibility:
  - Minimum 44x44 dp touch targets.
  - High contrast in dark theme.
  - VoiceOver semantics for countdown and controls.

---

## 3) State Model and Flows

- Timer States:
  - `inactive`: no timer set.
  - `scheduled`: timer value defined, countdown not yet started.
  - `running`: countdown active.
  - `paused`: countdown paused.
  - `completed`: reached zero -> triggers audio shutdown flow.

- Events:
  - `SelectPreset(minutes)`
  - `AdjustSlider(minutes)`
  - `StartTimer`
  - `PauseTimer`
  - `ResumeTimer`
  - `CancelTimer`
  - `CompleteTimer`

- Data:
  - `totalDuration` (Duration)
  - `remaining` (Duration)
  - `startEpoch` / `pauseEpoch` for accurate resume
  - `ticker` (1s timer)

---

## 4) Audio Reset: Deep Examination and Requirements

We must guarantee the app returns to a "fresh launch" audio state. Current stack reveals:

- `WPFWAudioHandler` (`wpfw_radio/lib/services/audio_service/wpfw_audio_handler.dart`)
  - Primary playback via `just_audio` `AudioPlayer` with a permanent dummy `MediaItem`.
  - Methods: `play()`, `pause()`, `stop()`, `customAction('dispose')`.
  - `_reconnect()` can reset source and play.
  - Lock screen metadata intentionally decoupled from `MediaItem` updates.

- `StreamBloc` (`wpfw_radio/lib/presentation/bloc/stream_bloc.dart`)
  - Events: `StartStream`, `PauseStream`, `StopStream`, `RetryStream`.
  - Delegates to `StreamRepository` (not shown here) for actual handler calls.

- `AudioStateManager` (`wpfw_radio/lib/core/services/audio_state_manager.dart`)
  - Global coordination with `AudioCommand` queue and `GlobalAudioState`.
  - Supports a `reset` command that clears timers, error state, and returns to `idle`.

- Native/iOS services (`ios_lockscreen_service.dart`, `lockscreen_service.dart`)
  - `IOSLockscreenService.clearLockscreen()` is available to clear Now Playing.

Required "cold-start" reset on timer completion:

1. Stop playback fully via audio handler.
2. Dispose the `AudioPlayer` to release buffers and sessions (handler `customAction('dispose')`).
3. Clear iOS lockscreen metadata.
4. Reset `AudioStateManager` to `idle` and clear errors.
5. Recreate/rehydrate the audio handler (or repository) to the initial state so that pressing Play behaves like first launch.
6. Ensure any reconnection loops or buffering retries are canceled.

Proposed reset sequence:

- `AudioStateManager.enqueueCommand(reset)`
- Repository:
  - await `audioHandler.stop()`
  - await `audioHandler.customAction('dispose')`
  - iOS: `IOSLockscreenService().clearLockscreen()` (safe no-op on Android)
  - Recreate handler: `WPFWAudioHandler.create()` and rebind to repository streams
  - Emit `StreamState.initial` to `StreamBloc`
  - AudioStateManager returns to `idle`

This mirrors a cold boot and avoids subtle plugin residual states.

---

## 5) Implementation Plan (Timer)

- Add new timer module:
  - File: `wpfw_radio/lib/presentation/widgets/sleep_timer_overlay.dart`
  - Contains UI + internal `Ticker` logic or uses a lightweight BLoC/Cubit `SleepTimerCubit`.

- State management option A (simple, local):
  - Local `StatefulWidget` with a `Timer.periodic(const Duration(seconds: 1))`.
  - On `dispose`, cancel timer.

- State management option B (scalable):
  - `SleepTimerCubit` at `wpfw_radio/lib/presentation/bloc/sleep_timer_cubit.dart`
  - States: inactive/scheduled/running/paused/completed with remaining time.
  - Benefits: survives overlay rebuilds and testable.

- Actions mapping:
  - Start: transition to `running`, start ticker.
  - Pause: stop ticker, go to `paused`.
  - Resume: restart ticker.
  - Cancel: stop ticker, go to `inactive`.
  - Complete: invoke Audio Reset Sequence.

- UI behaviors:
  - While `running`, show countdown and progress ring.
  - If overlay is dismissed while running, keep timer running in background and show a small in-app indicator (snackbar/toast) with remaining time when returning.

---

## 6) Integration Points

- Hook Alarm button in `home_page.dart` to open the overlay instead of the placeholder sheet.
- The overlay’s "Start" button kicks off the timer and closes the overlay (optional) or stays open to show live countdown.
- On completion, call a new repository method `stopAndColdReset()` implementing the reset sequence.

Repository signature (plan):
```dart
abstract class StreamRepository {
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> retry();

  // New
  Future<void> stopAndColdReset();
}
```

Implementation steps inside repository:
- `await audioHandler.stop();`
- `await audioHandler.customAction('dispose');`
- `await IOSLockscreenService().clearLockscreen();`
- `audioHandler = await WPFWAudioHandler.create(); // rebind listeners`
- Emit `StreamState.initial` to any consumers.
- Inform `AudioStateManager().enqueueCommand(AudioCommand(type: AudioCommandType.reset, source: AudioCommandSource.system))`.

---

## 7) Edge Cases & Safety

- If not playing when timer completes, perform reset anyway to guarantee clean state.
- If user taps Play while the overlay is open and timer running:
  - Keep timer running; completion still triggers reset.
- If app is offline when timer completes:
  - Reset path must be purely local (no network I/O) and should still succeed.
- Prevent double-dispose:
  - Guard `customAction('dispose')` so it’s safe to call multiple times.
- Cancel all reconnection attempts before dispose (`_reconnect` scheduling).
- Ensure background/foreground transitions do not pause the countdown unintentionally (use `Ticker` independent of frames).

---

## 8) Visual Details (Dark Mode)

- Card Corner Radius: 20–24
- Card Elevation: 8
- Colors:
  - Background: `Color(0xFF0F0404)` (app’s surface background)
  - Card: `Theme.of(context).colorScheme.surface`
  - Text: `Theme.of(context).colorScheme.onSurface`
  - Accent: `Theme.of(context).colorScheme.primary`
- Preset Chips: `ChoiceChip` with filled selected style.
- Slider: Material 3 with value label (e.g., "45 min").
- Buttons: `FilledButton` (Start) and `TextButton` (Cancel), full width.
- Animations: `AnimatedSwitcher` for state changes; gentle scale-in for card.

---

## 9) Telemetry & Logging

- Log timer start/cancel/complete with chosen duration.
- Log audio reset sequence steps to `LoggerService` for diagnostics.

---

## 10) Testing Plan

- Unit Tests:
  - SleepTimerCubit transitions and edge cases (pause/resume/cancel/complete).
  - Repository `stopAndColdReset()` ensures handler is disposed and recreated.

- Integration/Manual:
  - Start 15m -> cancel -> verify no audio reset.
  - Start 1m -> allow completion -> verify audio fully stops, lockscreen cleared, play acts like first launch.
  - Offline state -> completion -> reset still succeeds locally.
  - Repeated cycles of start/complete -> no leaks or stuck states.

---

## 11) Implementation Breakdown (Next Steps)

1. Create `SleepTimerCubit` and states.
2. Build `sleep_timer_overlay.dart` UI using the design above.
3. Wire Alarm button to open the overlay.
4. Add `StreamRepository.stopAndColdReset()` and implement the reset sequence.
5. On timer completion, call the repository method and show a confirmation snackbar.
6. Add logs and basic unit tests.

This plan ensures a polished UX and a dependable audio reset that returns the app to a pristine state after the timer completes.
