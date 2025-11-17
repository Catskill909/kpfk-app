# Audio Server Error Testing Guide

## Overview

This guide provides comprehensive testing strategies for the WPFW Radio app's audio server error handling system. Since you can't turn off the Icecast server directly, we've implemented sophisticated testing utilities to simulate various server failure scenarios.

## Testing Architecture

### 1. AudioServerTestingStrategy Class
Located at: `/lib/core/testing/audio_server_testing_strategy.dart`

This utility class allows you to simulate server errors without affecting the actual Icecast server:

```dart
// Enable test mode
AudioServerTestingStrategy.enableTestMode();

// Simulate specific errors
AudioServerTestingStrategy.simulateServerDown();
AudioServerTestingStrategy.simulateStreamNotFound();
AudioServerTestingStrategy.simulateServerOverloaded();
AudioServerTestingStrategy.simulateConnectionTimeout();
AudioServerTestingStrategy.simulateAuthError();

// Clear errors and return to normal
AudioServerTestingStrategy.clearForcedErrors();
AudioServerTestingStrategy.disableTestMode();
```

## Manual Testing Scenarios

### Scenario 1: Server Unavailable (Connection Refused)
**Simulate:** Server is completely down or unreachable
```dart
AudioServerTestingStrategy.enableTestMode();
AudioServerTestingStrategy.simulateServerDown();
```

**Expected Behavior:**
- ✅ AudioServerErrorModal appears with "Audio server is temporarily unavailable"
- ✅ Play button resets to initial state (not stuck in loading)
- ✅ iOS lockscreen controls are cleared
- ✅ Android notification controls are removed
- ✅ App bar play button shows play icon (not loading)
- ✅ All audio controls remain synchronized across app and lockscreen

**Test Steps:**
1. Open app and ensure it's working normally
2. Execute the simulation code above
3. Tap the play button
4. Verify modal appears immediately
5. Verify play button is not stuck in loading state
6. Check lockscreen - should have no audio controls
7. Tap "OK" to dismiss modal
8. Clear errors and test normal playback works

### Scenario 2: Stream Not Found (404 Error)
**Simulate:** Stream endpoint doesn't exist
```dart
AudioServerTestingStrategy.simulateStreamNotFound();
```

**Expected Behavior:**
- ✅ AudioServerErrorModal appears with "Stream not found on server"
- ✅ All audio controls reset properly
- ✅ Modal dismisses with "OK" button

### Scenario 3: Server Overloaded (503 Error)
**Simulate:** Server is temporarily overloaded
```dart
AudioServerTestingStrategy.simulateServerOverloaded();
```

**Expected Behavior:**
- ✅ AudioServerErrorModal appears with "Server is temporarily overloaded"
- ✅ User-friendly message suggests trying again later
- ✅ Controls reset properly

### Scenario 4: Connection Timeout
**Simulate:** Server takes too long to respond
```dart
AudioServerTestingStrategy.simulateConnectionTimeout();
```

**Expected Behavior:**
- ✅ AudioServerErrorModal appears with "Connection to server timed out"
- ✅ Play button doesn't get stuck in infinite loading
- ✅ Controls reset after timeout

### Scenario 5: Authentication Error (401/403)
**Simulate:** Access denied by server
```dart
AudioServerTestingStrategy.simulateAuthError();
```

**Expected Behavior:**
- ✅ AudioServerErrorModal appears with "Access denied by server"
- ✅ Controls reset properly

## Network vs Server Error Differentiation

### Test Network Errors (Should NOT show AudioServerErrorModal)
1. **Turn off WiFi and cellular data**
2. **Try to play stream**
3. **Expected:** NetworkLostAlert appears (existing network alert)
4. **Expected:** NO AudioServerErrorModal

### Test Server Errors (Should show AudioServerErrorModal)
1. **Ensure network is connected**
2. **Enable test mode and simulate server error**
3. **Try to play stream**
4. **Expected:** AudioServerErrorModal appears
5. **Expected:** NO NetworkLostAlert

## Lockscreen and App Bar Controls Testing

### iOS Lockscreen Testing
**Before Server Error:**
1. Start playing audio normally
2. Lock phone
3. Verify lockscreen shows: WPFW metadata, play/pause controls
4. Verify controls work properly

**After Server Error:**
1. Simulate server error while audio is playing
2. Lock phone
3. **Expected:** No audio controls on lockscreen
4. **Expected:** No metadata displayed
5. **Expected:** Clean lockscreen (no stuck controls)

### Android Notification Controls Testing
**Before Server Error:**
1. Start playing audio normally
2. Pull down notification shade
3. Verify audio notification with play/pause controls

**After Server Error:**
1. Simulate server error while audio is playing
2. Pull down notification shade
3. **Expected:** No audio notification
4. **Expected:** No stuck controls in notification area

### App Bar Play Button Testing
**Critical Test:** Ensure play button doesn't get stuck in loading state

1. **Normal Operation:**
   - Tap play → Button shows pause icon when playing
   - Tap pause → Button shows play icon when paused

2. **Server Error Scenario:**
   - Simulate server error
   - Tap play → Modal appears immediately
   - **Expected:** Button returns to play icon (not stuck loading)
   - Dismiss modal → Button remains in play state
   - Clear error simulation → Button should work normally

## Automated Testing Integration

### Widget Tests
```dart
testWidgets('AudioServerErrorModal appears on server error', (tester) async {
  // Enable test mode
  AudioServerTestingStrategy.enableTestMode();
  AudioServerTestingStrategy.simulateServerDown();
  
  // Pump widget and tap play
  await tester.pumpWidget(MyApp());
  await tester.tap(find.byIcon(Icons.play_circle_filled));
  await tester.pump();
  
  // Verify modal appears
  expect(find.byType(AudioServerErrorModal), findsOneWidget);
  expect(find.text('Audio Server Unavailable'), findsOneWidget);
  
  // Cleanup
  AudioServerTestingStrategy.disableTestMode();
});
```

### Integration Tests
```dart
testWidgets('Play button resets after server error', (tester) async {
  // Test play button state transitions during server errors
  // Verify lockscreen controls are cleared
  // Test recovery after error dismissal
});
```

## Real Server Testing (Advanced)

### Mock Server Setup
For advanced testing, you can create a local mock server:

```dart
// Create mock server that returns specific HTTP codes
final server = await AudioServerTestingStrategy.createMockServer(
  port: 8888,
  responseCode: 503, // Server overloaded
  delay: Duration(seconds: 2), // Simulate slow response
);

// Update stream URL to point to mock server for testing
// Test various HTTP response codes and behaviors
```

### Production Server Testing
```dart
// Test actual server health (bypasses simulation)
final result = await AudioServerTestingStrategy.testRealServerHealth();
print('Real server status: ${result.isHealthy}');
```

## Debug Menu Integration

### Add to Debug Build
Create a debug menu in your app with these options:

```dart
// Debug menu options
ElevatedButton(
  onPressed: () => AudioServerTestingStrategy.simulateServerDown(),
  child: Text('Test: Server Down'),
),
ElevatedButton(
  onPressed: () => AudioServerTestingStrategy.simulateStreamNotFound(),
  child: Text('Test: Stream Not Found'),
),
ElevatedButton(
  onPressed: () => AudioServerTestingStrategy.clearForcedErrors(),
  child: Text('Clear Test Errors'),
),
```

## Testing Checklist

### Pre-Testing Setup
- [ ] Ensure app builds and runs normally
- [ ] Verify normal audio playback works
- [ ] Check network connectivity is stable
- [ ] Enable debug logging for detailed error tracking

### Core Functionality Tests
- [ ] Server down simulation shows correct modal
- [ ] Stream not found shows correct modal  
- [ ] Server overloaded shows correct modal
- [ ] Connection timeout shows correct modal
- [ ] Authentication error shows correct modal
- [ ] Modal dismisses with "OK" button
- [ ] Play button resets after error (not stuck loading)
- [ ] Error recovery works after clearing simulation

### Platform-Specific Tests
- [ ] iOS lockscreen controls cleared on server error
- [ ] Android notification controls cleared on server error
- [ ] App bar controls reset properly on both platforms
- [ ] Modal appears correctly on both platforms
- [ ] Accessibility features work with modal

### Edge Case Tests
- [ ] Multiple rapid play button taps during server error
- [ ] Server error while already playing audio
- [ ] Server error during app backgrounding/foregrounding
- [ ] Network change during server error state
- [ ] App restart while in server error state

### Performance Tests
- [ ] Server health checks don't block UI
- [ ] Modal animations are smooth
- [ ] No memory leaks from error handling
- [ ] Proper cleanup of audio resources

## Troubleshooting

### Common Issues
1. **Modal doesn't appear:** Check if test mode is enabled
2. **Play button stuck:** Verify AudioStateManager.handleServerError() is called
3. **Lockscreen not cleared:** Check iOS platform-specific code execution
4. **Network alert instead of server modal:** Verify error classification logic

### Debug Logging
Enable detailed logging to track error flow:
```dart
LoggerService.info('🧪 Test mode enabled');
LoggerService.info('🎵 Server health check failed');
LoggerService.info('🎛️ Audio controls reset');
```

### Log Analysis
Look for these log patterns during testing:
- `🏥 AudioServerHealthChecker: Checking server health`
- `🎵 StreamRepository: Server health check failed`
- `🎛️ AudioStateManager: Handling server error`
- `🎵 StreamRepository: Resetting audio controls`

## Conclusion

This testing strategy provides comprehensive coverage of audio server error scenarios without requiring control of the actual Icecast server. The simulation system allows thorough testing of:

- Error detection and classification
- UI feedback and modal presentation
- Audio controls reset (play button, lockscreen, notifications)
- Recovery mechanisms
- Platform-specific behavior

Use this guide to ensure robust audio server error handling before release.
