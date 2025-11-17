# Network Alert System - Ground Plan
## WPFW Radio Streaming App

### Overview
This document outlines the design and implementation plan for a streamlined network alert system that provides the best user experience for a streaming radio app. The new system removes user interaction complexity while ensuring complete audio state reset and clean recovery.

**Note:** This document covers **network connectivity errors** only. For **audio server errors** (when network is available but Icecast server is unreachable), see the separate AudioServerErrorModal system documented in `audio-server-testing-guide.md` and `audio-audit.md`.

### Current State Analysis

#### Existing Components
- **OfflineModal**: Dialog-style alert with Retry/Dismiss buttons
- **OfflineOverlay**: Full-screen overlay with Retry/Dismiss buttons  
- **ConnectivityCubit**: Manages network state and dismissal logic
- **ConnectivityService**: Handles network detection via connectivity_plus and HTTP probes
- **AudioStateManager**: Centralized audio command queue and state management
- **WPFWAudioHandler**: just_audio integration with lockscreen controls
- **StreamRepository**: Coordinates audio, metadata, and native iOS services

#### Current Behavior Issues
1. **User Confusion**: Two buttons (Retry/Dismiss) create decision paralysis
2. **Incomplete Reset**: Audio state not fully reset to startup condition
3. **Lockscreen Persistence**: Transport controls remain visible when offline
4. **Code Duplication**: Two similar alert widgets with overlapping functionality
5. **Manual Intervention**: Requires user action to retry connection

### New Design Requirements

#### Core Principles
1. **Zero User Interaction**: Alert appears and disappears automatically
2. **Complete Audio Reset**: Return to pristine app startup state
3. **Clear Communication**: User understands what's happening and what to expect
4. **Seamless Recovery**: Automatic retry when network returns
5. **Clean Architecture**: Single alert component, no code duplication

#### User Experience Flow
```
Network Lost → Alert Appears → Audio Fully Reset → Wait for Network → Auto-Retry → Alert Disappears
```

## Error Type Distinction

### Network Connectivity Errors vs Audio Server Errors

This system handles **network connectivity errors** only:
- No internet connection (WiFi/cellular down)
- Network unreachable
- DNS resolution failures
- General connectivity issues

**Separate System:** AudioServerErrorModal handles **audio server errors**:
- Icecast server down (connection refused)
- Stream not found (404)
- Server overloaded (503)
- Authentication errors (401/403)
- Connection timeouts to server

### Technical Implementation Plan

#### 1. New Alert Component: `NetworkLostAlert`

**Design Specifications:**
- Single, clean alert widget replacing both existing alerts
- No buttons or user interaction elements
- Auto-dismissing when network recovers
- Clear, reassuring messaging
- Consistent with app's dark theme

**UI Elements:**
- WiFi off icon (existing: `Icons.wifi_off`)
- Primary message: "Connection Lost"
- Secondary message: "This alert will disappear when your connection is restored"
- Subtle loading indicator to show the app is monitoring
- Semi-transparent overlay to prevent interaction with underlying UI

**Implementation:**
```dart
class NetworkLostAlert extends StatelessWidget {
  // Clean, button-free design
  // Auto-dismissing behavior
  // Consistent theming with AppTextStyles
}
```

#### 2. Enhanced ConnectivityCubit

**New Responsibilities:**
- Trigger complete audio reset when network lost
- Automatic retry logic when network recovered
- Simplified state management (remove dismissal complexity)
- Integration with AudioStateManager for coordinated resets

**State Changes:**
```dart
// Remove dismissed field - no longer needed
class ConnectivityState {
  final bool isOnline;
  final bool checking;
  final bool firstRun;
  // Remove: final bool dismissed;
}
```

**Enhanced Network Loss Handler:**
```dart
void _handleNetworkLoss() {
  // 1. Trigger complete audio reset via AudioStateManager
  // 2. Clear all transport controls (lockscreen, notification tray)
  // 3. Reset UI state to startup condition
  // 4. Show network alert
}
```

#### 3. Complete Audio Reset System

**AudioStateManager Enhancements:**
- New `resetToStartupState()` method
- Clear all queued commands
- Reset to `GlobalAudioState.idle`
- Clear any cached metadata or error states

**WPFWAudioHandler Integration:**
- Utilize existing `resetToColdStart()` method
- Ensure lockscreen controls are completely cleared
- Reset playback state to idle
- Clear any cached MediaItem data

**StreamRepository Coordination:**
- Use existing `stopAndColdReset()` method
- Stop metadata fetching
- Clear native lockscreen (iOS)
- Reset to initial state

#### 4. Lockscreen & System Tray Control Removal

**iOS Implementation:**
```swift
// Clear MPNowPlayingInfoCenter completely
MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
MPNowPlayingInfoCenter.default().playbackState = .stopped
```

**Android Implementation:**
```dart
// Clear MediaSession state
playbackState.add(PlaybackState(
  controls: [], // Empty controls array
  systemActions: {}, // Empty system actions
  processingState: AudioProcessingState.idle,
  playing: false,
));
```

#### 5. Network Recovery & Auto-Retry

**Automatic Recovery Flow:**
1. ConnectivityService detects network restoration
2. ConnectivityCubit receives network change event
3. Automatic metadata service restart
4. Alert automatically dismisses
5. UI returns to ready state (play button enabled)
6. No automatic playback - user must manually start

**Implementation:**
```dart
void _handleNetworkRecovery() {
  // 1. Restart metadata service
  // 2. Reset audio state to ready/idle
  // 3. Alert auto-dismisses via state change
  // 4. Enable play button
  // Note: Do NOT auto-start playback
}
```

### Code Architecture Improvements

#### 1. Eliminate Duplication
- **Remove**: `OfflineModal` and `OfflineOverlay`
- **Replace with**: Single `NetworkLostAlert` component
- **Consolidate**: All network alert logic in one place

#### 2. Clean State Management
- Simplify ConnectivityState (remove dismissal logic)
- Clear separation of concerns between connectivity and audio management
- Unified error handling and recovery

#### 3. Improved Integration Points
```dart
// ConnectivityCubit → AudioStateManager
void _handleNetworkLoss() {
  AudioStateManager().enqueueCommand(AudioCommand(
    type: AudioCommandType.reset,
    source: AudioCommandSource.networkLoss,
  ));
}

// AudioStateManager → StreamRepository  
Future<void> _executeNetworkResetCommand() async {
  await _streamRepository.stopAndColdReset();
}
```

### Implementation Steps

#### Phase 1: Core Alert Component
1. Create `NetworkLostAlert` widget
2. Implement clean, button-free UI
3. Add to widget tree with proper positioning

#### Phase 2: Audio Reset Integration
1. Add network loss command type to AudioStateManager
2. Implement complete reset flow
3. Integrate with existing StreamRepository methods
4. Test lockscreen control removal

#### Phase 3: Connectivity Logic Update
1. Simplify ConnectivityCubit state
2. Remove dismissal logic and buttons
3. Implement automatic retry on recovery
4. Update network loss/recovery handlers

#### Phase 4: Code Cleanup
1. Remove old alert components
2. Clean up unused state management
3. Update imports and dependencies
4. Comprehensive testing

### Testing Strategy

#### Unit Tests
- ConnectivityCubit state transitions
- AudioStateManager command processing
- Network detection accuracy

#### Integration Tests
- Complete network loss → recovery flow
- Audio reset verification
- Lockscreen control clearing
- UI state consistency

#### User Experience Tests
- Network interruption scenarios
- Recovery timing and smoothness
- Alert appearance/disappearance
- Audio state verification

### Success Metrics

#### Technical Metrics
- Zero code duplication in alert system
- Complete audio state reset (verified via logging)
- Lockscreen controls fully cleared
- Automatic recovery within 2 seconds of network restoration

#### User Experience Metrics
- No user interaction required
- Clear understanding of app state
- Smooth transition back to normal operation
- No stuck states or manual intervention needed

### Risk Mitigation

#### Potential Issues
1. **Network Detection Delays**: Use existing ConnectivityService timeout logic
2. **iOS Lockscreen Persistence**: Leverage existing native implementation
3. **Audio State Corruption**: Utilize robust AudioStateManager command queue
4. **Race Conditions**: Maintain existing sequential command processing

#### Fallback Strategies
- Maintain existing audio reset methods as fallbacks
- Keep network detection probe system
- Preserve logging for debugging
- Gradual rollout with feature flags if needed

### Future Enhancements

#### Potential Improvements
1. **Smart Retry Logic**: Exponential backoff for repeated failures
2. **Offline Mode**: Cache last known metadata for display
3. **Network Quality Indicators**: Show connection strength
4. **Accessibility**: Enhanced screen reader support

#### Monitoring & Analytics
- Network interruption frequency tracking
- Recovery time measurements
- User behavior analysis post-recovery
- Error rate monitoring

---

### Conclusion

This ground plan creates a superior network alert experience by:
- Eliminating user decision fatigue
- Providing complete audio state reset
- Ensuring clean recovery
- Maintaining code quality and efficiency
- Leveraging existing robust architecture

The implementation builds upon the app's existing audio management system while streamlining the user experience for network interruptions - a common occurrence in mobile streaming applications.
