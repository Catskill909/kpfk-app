# TestFlight Audio Testing Checklist
## WPFW Radio App - Production Readiness Verification

### Pre-Distribution Setup

#### 1. Build Configuration
- [ ] Ensure release build configuration
- [ ] Verify app version and build number incremented
- [ ] Confirm all debug logging is appropriate for production
- [ ] Test on both iOS and Android release builds

#### 2. Audio Server Testing Strategy Integration
```dart
// Add to debug menu for TestFlight testers
class DebugAudioMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            AudioServerTestingStrategy.enableTestMode();
            AudioServerTestingStrategy.simulateServerDown();
          },
          child: Text('Test: Server Down'),
        ),
        ElevatedButton(
          onPressed: () {
            AudioServerTestingStrategy.simulateStreamNotFound();
          },
          child: Text('Test: Stream Not Found'),
        ),
        ElevatedButton(
          onPressed: () {
            AudioServerTestingStrategy.simulateServerOverloaded();
          },
          child: Text('Test: Server Overloaded'),
        ),
        ElevatedButton(
          onPressed: () {
            AudioServerTestingStrategy.clearForcedErrors();
            AudioServerTestingStrategy.disableTestMode();
          },
          child: Text('Clear Test Errors'),
        ),
      ],
    );
  }
}
```

### Core Audio Functionality Testing

#### ✅ Basic Playback
- [ ] **App Launch**: App opens without crashes
- [ ] **Initial State**: Play button shows play icon (not loading)
- [ ] **Stream Start**: Tap play → audio begins within 5 seconds
- [ ] **Stream Stop**: Tap pause → audio stops immediately
- [ ] **Metadata Display**: Current show information appears
- [ ] **Background Play**: Audio continues when app backgrounded

#### ✅ Audio Controls Responsiveness
- [ ] **Play Button States**: 
  - Idle → Play icon
  - Connecting → Loading spinner
  - Playing → Pause icon
  - Paused → Play icon
- [ ] **No Stuck States**: Button never remains in loading indefinitely
- [ ] **Rapid Taps**: Multiple quick taps don't break state
- [ ] **State Persistence**: Correct state after app backgrounding/foregrounding

### Server Error Handling Testing

#### ✅ AudioServerErrorModal Functionality
**Test Scenario 1: Server Down**
```
1. Enable test mode: AudioServerTestingStrategy.enableTestMode()
2. Simulate server down: AudioServerTestingStrategy.simulateServerDown()
3. Tap play button
4. Expected Results:
   ✅ AudioServerErrorModal appears immediately
   ✅ Modal shows "Audio Server Unavailable" message
   ✅ Play button resets to play icon (not stuck loading)
   ✅ Modal has single "OK" button
   ✅ Tapping "OK" dismisses modal
```

**Test Scenario 2: Stream Not Found (404)**
```
1. Simulate 404: AudioServerTestingStrategy.simulateStreamNotFound()
2. Tap play button
3. Expected Results:
   ✅ Modal shows "Stream not found on server"
   ✅ All controls reset properly
```

**Test Scenario 3: Server Overloaded (503)**
```
1. Simulate overload: AudioServerTestingStrategy.simulateServerOverloaded()
2. Tap play button
3. Expected Results:
   ✅ Modal shows "Server is temporarily overloaded"
   ✅ User-friendly message suggests trying again later
```

**Test Scenario 4: Connection Timeout**
```
1. Simulate timeout: AudioServerTestingStrategy.simulateConnectionTimeout()
2. Tap play button
3. Expected Results:
   ✅ Modal shows "Connection to server timed out"
   ✅ Play button doesn't get stuck in loading
```

#### ✅ Error Recovery Testing
- [ ] **Clear Errors**: `AudioServerTestingStrategy.clearForcedErrors()`
- [ ] **Normal Playback**: Verify stream works after clearing simulation
- [ ] **Multiple Cycles**: Test error → recovery → error → recovery
- [ ] **State Consistency**: UI state remains consistent through cycles

### Network vs Server Error Distinction

#### ✅ Network Error Testing (Should NOT show AudioServerErrorModal)
**Test Scenario: No Internet Connection**
```
1. Turn off WiFi and cellular data
2. Tap play button
3. Expected Results:
   ✅ NetworkLostAlert appears (existing network alert)
   ✅ NO AudioServerErrorModal
   ✅ Alert auto-dismisses when network restored
```

#### ✅ Server Error Testing (Should show AudioServerErrorModal)
**Test Scenario: Network Available, Server Down**
```
1. Ensure network is connected (WiFi/cellular working)
2. Enable test mode and simulate server error
3. Tap play button
4. Expected Results:
   ✅ AudioServerErrorModal appears
```

### iOS Lockscreen Integration Testing

#### Critical iOS Lockscreen Bug Verification 
**STATUS: RESOLVED - Bug has been fixed in current build**

### The Bug (RESOLVED)
- **Issue**: When app is inactive and user presses play on iOS lockscreen, audio starts but then immediately stops
- **Symptom**: Main app play button gets stuck in spinning/loading state and becomes unresponsive
- **Root Cause**: AudioStateManager was only updating state without triggering actual audio playback
- **Fix Applied**: Rerouted lockscreen commands directly through StreamRepository singleton
- **Impact**: Core audio functionality now works seamlessly

### Verification Steps (Updated for Fixed Implementation)
1. **Setup**: Ensure app is installed with latest build containing the fix
2. **Background Test**: Put app in background or close completely
3. **Lockscreen Play**: Press play button on iOS lockscreen controls
4. **Expected**: Audio starts immediately and continues playing
5. **App Sync Check**: Open app - play button should show pause state (not spinning)
6. **Control Sync**: Tap app play button - should pause audio immediately
7. **Resume Test**: Tap app play button again - should resume audio
8. **Toggle Test**: Use lockscreen pause/play - should sync with app controls

### Pass Criteria 
- Lockscreen play starts audio and keeps playing
- App play button shows correct state (pause icon when playing)
- App controls remain responsive and synchronized
- No stuck loading/spinning states
- Seamless transition between lockscreen and app controls
- Perfect state synchronization across all control interfaces

### Architecture Verification
- Lockscreen commands route through StreamRepository
- App controls route through StreamRepository
- Both paths use same singleton for synchronization
- No circular dependencies or state conflicts

**READY FOR TESTFLIGHT - Critical bug has been resolved** from lockscreen

**Test Scenario: Lockscreen Toggle Command**
```
1. Test toggle play/pause from lockscreen multiple times
2. Expected Results:
   Each toggle works correctly
   App UI stays in sync
   No desynchronization between lockscreen and app
   AudioStateManager properly routes commands
```

#### Normal Lockscreen Behavior
**Before Server Error:**
```
1. Start playing audio normally
2. Lock iPhone/iPad
3. Expected Results:
   Lockscreen shows WPFW metadata
   Play/pause controls visible and functional
   VoiceOver reads metadata correctly
   No metadata flicker or "Not Playing" cycling
```

#### Server Error Lockscreen Behavior
2. Expected Results:
   ✅ Each toggle works correctly
   ✅ App UI stays in sync
   ✅ No desynchronization between lockscreen and app
   ✅ AudioStateManager properly routes commands
```

#### ✅ Server Error Lockscreen Behavior
**After Server Error:**
```
1. Simulate server error while audio is playing
2. Lock device
3. Expected Results:
   ✅ No audio controls on lockscreen
   ✅ No metadata displayed
   ✅ Clean lockscreen (no stuck controls)
   ✅ VoiceOver doesn't read stale audio info
```

#### ✅ Lockscreen Recovery Testing
```
1. Clear server error simulation
2. Start normal playback
3. Lock device
4. Expected Results:
   ✅ Lockscreen controls return properly
   ✅ Metadata displays correctly
   ✅ Controls function normally
```

### Android Notification Controls Testing

#### ✅ Normal Notification Behavior
**Before Server Error:**
```
1. Start playing audio normally
2. Pull down notification shade
3. Expected Results:
   ✅ Audio notification with play/pause controls
   ✅ WPFW metadata displayed
   ✅ Controls respond correctly
```

#### ✅ Server Error Notification Behavior
**After Server Error:**
```
1. Simulate server error while audio is playing
2. Pull down notification shade
3. Expected Results:
   ✅ No audio notification
   ✅ No stuck controls in notification area
   ✅ Clean notification shade
```

### Platform-Specific Testing

#### ✅ iOS Specific Tests
- [ ] **iPhone Testing**: Test on iPhone 12+, iPhone SE
- [ ] **iPad Testing**: Test on iPad Air, iPad Pro
- [ ] **iOS Versions**: Test on iOS 15+, iOS 16+, iOS 17+
- [ ] **VoiceOver**: Enable VoiceOver and test all interactions
- [ ] **Control Center**: Verify audio controls in Control Center
- [ ] **AirPods**: Test with Bluetooth headphones
- [ ] **CarPlay**: Test if CarPlay integration works (if applicable)

#### ✅ Android Specific Tests
- [ ] **Phone Testing**: Test on various Android devices
- [ ] **Android Versions**: Test on Android 10+, Android 12+, Android 14+
- [ ] **TalkBack**: Enable TalkBack and test accessibility
- [ ] **Notification Controls**: Verify notification audio controls
- [ ] **Bluetooth**: Test with Bluetooth headphones
- [ ] **Android Auto**: Test if Android Auto works (if applicable)

### Edge Case Testing

#### ✅ App Lifecycle Testing
- [ ] **Backgrounding**: App backgrounded during playback
- [ ] **Foregrounding**: App foregrounded after being backgrounded
- [ ] **Memory Pressure**: Test under low memory conditions
- [ ] **Battery Saver**: Test with battery saver mode enabled
- [ ] **Do Not Disturb**: Test with DND mode active

#### ✅ Network Transition Testing
- [ ] **WiFi to Cellular**: Switch networks during playback
- [ ] **Cellular to WiFi**: Switch networks during server error
- [ ] **Airplane Mode**: Toggle airplane mode during various states
- [ ] **Poor Signal**: Test in areas with weak signal
- [ ] **Network Interruption**: Brief network outages during playback

#### ✅ Multitasking Testing
- [ ] **Phone Calls**: Incoming calls during playback
- [ ] **Other Audio Apps**: Spotify, Apple Music interaction
- [ ] **Video Apps**: YouTube, Netflix interaction
- [ ] **Split Screen**: iPad split screen usage (if applicable)
- [ ] **Picture in Picture**: Other apps using PiP during audio

### Performance Testing

#### ✅ Memory and CPU Usage
- [ ] **Memory Leaks**: Monitor memory usage over extended periods
- [ ] **CPU Usage**: Verify reasonable CPU consumption
- [ ] **Battery Drain**: Test battery usage during long sessions
- [ ] **Heat Generation**: Monitor device temperature during use

#### ✅ Network Efficiency
- [ ] **Data Usage**: Monitor data consumption
- [ ] **Connection Pooling**: Verify efficient network usage
- [ ] **Health Check Frequency**: Ensure reasonable server polling
- [ ] **Cache Behavior**: Verify metadata caching works properly

### User Experience Testing

#### ✅ Error Message Quality
- [ ] **Clear Language**: Error messages are user-friendly
- [ ] **Actionable Information**: Users understand what to do
- [ ] **Consistent Tone**: Messages match app's voice
- [ ] **Accessibility**: Screen readers can read messages clearly

#### ✅ Modal Behavior
- [ ] **Appearance Animation**: Smooth fade-in animation
- [ ] **Dismissal Animation**: Smooth fade-out animation
- [ ] **Touch Interaction**: Modal blocks interaction with background
- [ ] **Keyboard Navigation**: Accessible via keyboard/switch control

#### ✅ Visual Consistency
- [ ] **Dark Theme**: Modal matches app's dark theme
- [ ] **Typography**: Uses Oswald font consistently
- [ ] **Icon Usage**: Musical note icon displays correctly
- [ ] **Button Styling**: "OK" button matches app design

### Real-World Scenario Testing

#### ✅ Actual Server Downtime
- [ ] **Monitor Real Issues**: Watch for actual Icecast server problems
- [ ] **Verify Modal Appears**: AudioServerErrorModal shows during real downtime
- [ ] **Recovery Testing**: Confirm recovery when server returns
- [ ] **User Feedback**: Collect feedback on real error experiences

#### ✅ Extended Usage Patterns
- [ ] **Long Sessions**: 2+ hour listening sessions
- [ ] **Daily Usage**: Multiple sessions throughout the day
- [ ] **Weekend Usage**: Extended weekend listening
- [ ] **Commute Testing**: Usage during daily commutes

### TestFlight Beta Tester Instructions

#### For Beta Testers:
```
1. BASIC TESTING:
   - Open app and tap play button
   - Verify audio starts and metadata appears
   - Test pause/play functionality
   - Lock device and test lockscreen controls

2. ERROR TESTING (if debug menu available):
   - Use "Test: Server Down" button
   - Verify modal appears with clear message
   - Tap "OK" to dismiss
   - Use "Clear Test Errors" to return to normal

3. NETWORK TESTING:
   - Turn off WiFi/cellular
   - Try to play - should see network alert (not server modal)
   - Turn network back on - alert should disappear

4. REPORT ISSUES:
   - Any stuck play buttons
   - Missing or incorrect error messages
   - Lockscreen control problems
   - App crashes or freezes
```

### Success Criteria

#### ✅ Must Pass Before App Store Release
- [ ] **Zero Stuck States**: Play button never remains in loading indefinitely
- [ ] **100% Error Coverage**: All server error types show appropriate modals
- [ ] **Platform Integration**: Lockscreen/notification controls work correctly
- [ ] **Accessibility**: VoiceOver/TalkBack users can use all features
- [ ] **Performance**: No memory leaks or excessive resource usage
- [ ] **Recovery**: All error states can recover to normal operation

#### ✅ Quality Metrics
- **Error Response Time**: <1 second from server error to modal display
- **Play Button Reset**: <500ms from error to button state reset
- **Modal Dismissal**: <300ms animation for smooth UX
- **Memory Usage**: <50MB additional memory during error states
- **Battery Impact**: <5% additional battery drain from error handling

### Post-TestFlight Analysis

#### Data Collection Points
- [ ] **Error Frequency**: How often do server errors occur?
- [ ] **User Behavior**: Do users understand the error messages?
- [ ] **Recovery Success**: Do users successfully recover from errors?
- [ ] **Platform Differences**: Any iOS vs Android behavioral differences?

#### Feedback Categories
- [ ] **Functionality**: Does everything work as expected?
- [ ] **Usability**: Are error messages clear and helpful?
- [ ] **Performance**: Any lag, crashes, or resource issues?
- [ ] **Accessibility**: Can all users access all features?

---

## ✅ Final Verification Checklist

Before submitting to App Store:
- [ ] All TestFlight feedback addressed
- [ ] No critical bugs reported
- [ ] Performance metrics within acceptable ranges
- [ ] Accessibility compliance verified
- [ ] Platform-specific features working correctly
- [ ] Error handling robust and user-friendly
- [ ] Documentation updated with any changes

**TestFlight Ready**: ✅ / ❌

**App Store Ready**: ✅ / ❌

---

*This checklist ensures comprehensive testing of the WPFW Radio app's audio streaming and error handling capabilities before production release.*
