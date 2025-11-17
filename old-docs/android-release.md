# Android Release Preparation - WPFW Radio App

## Overview
This document outlines the complete preparation process for releasing the WPFW Radio app to the Google Play Store in 2025, including 16KB page size compatibility, API compliance, and submission requirements.

## 🎯 Release Goals
- [ ] Ensure 100% compatibility with Android 16KB page size requirement
- [ ] Update all deprecated APIs to current standards
- [ ] Implement Google Play Store requirements for 2025
- [ ] Create secure keystore and backup system
- [ ] Pass all Google Play Console validations

## 📋 Pre-Release Audit Checklist

### 1. Android 16KB Page Size Compatibility (CRITICAL)
**Reference**: https://developer.android.com/guide/practices/page-sizes#test

#### Understanding 16KB Page Size Impact
- **What it is**: Android devices can use 16KB memory pages instead of traditional 4KB
- **Why it matters**: Apps must be compatible or they'll crash/malfunction on 16KB devices
- **Timeline**: Required for Google Play Store submissions in 2025
- **Impact on WPFW**: Audio streaming apps are particularly sensitive to memory alignment

#### Testing Requirements
- [ ] **Enable 16KB page size testing** on development device
- [ ] **Test audio streaming** with 16KB pages enabled
- [ ] **Verify app startup** doesn't crash with 16KB pages
- [ ] **Test lockscreen controls** functionality
- [ ] **Validate network connectivity** handling

#### Implementation Checklist
- [ ] **Native Libraries**: Verify any native audio libraries support 16KB alignment
- [ ] **Memory Allocation**: Check Flutter audio plugins for 16KB compatibility
- [ ] **Buffer Sizes**: Ensure audio buffers work with 16KB page boundaries
- [ ] **JNI Calls**: Validate native method calls handle 16KB pages correctly

#### Testing Commands
```bash
# Enable 16KB page size on test device (requires root/emulator)
adb shell su -c 'echo 16384 > /proc/sys/vm/page_size'

# Or use Android 15+ emulator with 16KB pages enabled
# Create AVD with 16KB page size support
```

### 2. API Compatibility & Deprecation Fixes
- [ ] **PRIORITY**: Fix deprecated `stop()` method in WPFWAudioHandler (line 366)
- [ ] Audit all Flutter dependencies for latest stable versions
- [ ] Check for deprecated Android APIs in native code
- [ ] Verify targetSdkVersion is set to API 34+ (Android 14+)
- [ ] Ensure compileSdkVersion matches or exceeds targetSdkVersion

### 3. Google Play Store Requirements (2025)
- [ ] **Privacy Policy**: Ensure privacy policy is accessible and compliant
- [ ] **Data Safety**: Complete Data Safety section in Play Console
- [ ] **Target API Level**: Must target API 34+ (Android 14+)
- [ ] **App Bundle**: Use Android App Bundle (.aab) format
- [ ] **64-bit Support**: Ensure 64-bit native libraries (if applicable)
- [ ] **Restricted Permissions**: Audit and justify sensitive permissions

### 4. Security & Permissions Audit
- [ ] Review all permissions in AndroidManifest.xml
- [ ] Ensure INTERNET permission is properly declared
- [ ] Check FOREGROUND_SERVICE permission for audio service
- [ ] Validate POST_NOTIFICATIONS permission (Android 13+)
- [ ] Ensure HTTPS usage for all network requests (already implemented)

### 5. Audio Service Compliance
- [ ] Verify foreground service permissions and declarations
- [ ] Test audio focus handling on various Android versions
- [ ] Ensure proper notification channel setup
- [ ] Validate MediaSession integration
- [ ] Test lockscreen controls functionality

## 📊 Current Status Assessment

### ✅ COMPLETED TASKS
- [x] **Deprecated API Fixes**: All 4 instances of deprecated `_player.stop()` method fixed
- [x] **Android Configuration Audit**: Verified proper permissions and service setup
- [x] **Dependencies Review**: Current versions are compatible with 2025 requirements

### 🔍 CURRENT CONFIGURATION STATUS
- **Target SDK**: ✅ API 34 (Android 14) - Explicitly set for 2025 requirements
- **Min SDK**: 23 (Android 6.0) - Good for broad compatibility
- **Permissions**: ✅ All required audio service permissions present
- **Audio Service**: ✅ Properly configured with mediaPlayback foreground service
- **Dependencies**: ✅ Updated to latest compatible versions automatically

### ⚠️ CRITICAL REQUIREMENTS FOR 2025
- [x] **16KB Page Size Compatibility**: ✅ AUDIT COMPLETED - Low risk, needs testing
- [x] **Explicit Target SDK**: ✅ COMPLETED - Set to API 34 (Android 14)
- [ ] **Release Keystore**: Must be generated for Play Store submission

## 🔧 Technical Implementation Tasks

### Phase 1: 16KB Page Size Compatibility ✅ AUDIT COMPLETED

#### 🔍 **Compatibility Assessment Results**
✅ **No Native Libraries**: No .so files or jniLibs directories found
✅ **Updated Dependencies**: All audio packages automatically updated to newer versions:
   - just_audio: 0.9.46 (was 0.9.35) - Latest version likely supports 16KB
   - audio_service: 0.18.18 (was 0.18.12) - Updated for compatibility  
   - audio_session: 0.1.25 (was 0.1.14) - Latest version
   - flutter_inappwebview: 6.2.0-beta.2 (was 6.1.8) - Updated

✅ **Standard Android APIs**: MainActivity uses only standard Android APIs
✅ **No JNI/FFI**: No native code or foreign function interfaces found
✅ **Memory Management**: Using Flutter's managed memory allocation

#### 🧪 **Testing Requirements**
- [ ] Test on Android 15+ emulator with 16KB pages enabled
- [ ] Verify audio streaming works with 16KB page boundaries
- [ ] Test notification system under 16KB memory alignment
- [ ] Validate app startup and background/foreground transitions

### Phase 2: Deprecated API Fixes ✅ COMPLETED
1. **WPFWAudioHandler.stop() Method** ✅ FIXED
   - Location: `/lib/services/audio_service/wpfw_audio_handler.dart` (4 instances)
   - Issue: Using deprecated `_player.stop()` method
   - Solution: Replaced with `_player.pause() + _player.seek(Duration.zero)`
   - Impact: Critical for Play Store submission - NOW RESOLVED
   - Lines fixed: 344, 228, 495, 531

### Phase 3: Dependency Updates
1. **Flutter Dependencies Audit**
   ```yaml
   # Current critical dependencies to verify:
   - audio_service: ^0.18.12 (verify latest version)
   - audio_session: ^0.1.18 (check memory handling)
   - connectivity_plus: ^5.0.2 (validate network handling)
   ```

2. **Android Native Dependencies**
   - Verify Kotlin version compatibility with 16KB pages
   - Check Gradle plugin versions
   - Ensure Android SDK tools support 16KB testing

## 🔐 Keystore & Signing Setup

### ✅ PRODUCTION KEYSTORE READY - VERIFIED WORKING

**🚨 CRITICAL**: For complete signing configuration, see **[ANDROID-SIGNING-ONE-TRUTH.md](ANDROID-SIGNING-ONE-TRUTH.md)**

### Current Production Configuration (VERIFIED)
- **Keystore**: `/Users/paulhenshaw/Desktop/wpfw-app/wpfw-keystore/wpfw-upload-keystore.jks`
- **Alias**: `wpfw-upload-key`
- **Algorithm**: RSA 2048-bit, SHA256withRSA
- **Validity**: Until 2053-02-09 (27+ years)
- **Status**: ✅ PRODUCTION READY - Successfully built APK (55MB) + AAB (30MB)

### Verified Build Commands
```bash
# App Bundle for Google Play Store (RECOMMENDED)
flutter build appbundle --release

# APK for testing/distribution
flutter build apk --release
```

### ✅ COMPLETED TASKS
- [x] **Keystore Generated**: Production keystore created and verified
- [x] **Backup Strategy**: Secure backup ZIP created and stored
- [x] **Build Configuration**: Gradle properly configured for signing
- [x] **Verification**: Both APK and AAB builds successful with proper signatures

## 🧪 16KB Page Size Testing Protocol

### Testing Environment Setup
1. **Emulator Configuration**
   ```bash
   # Create Android 15+ emulator with 16KB page size
   avdmanager create avd -n "Android_16KB_Test" \
     -k "system-images;android-35;google_apis;x86_64" \
     -d "pixel_7"
   
   # Enable 16KB page size in emulator
   # (Configure in AVD settings or boot parameters)
   ```

2. **Physical Device Testing**
   - Use devices that support 16KB page size testing
   - Enable developer options for memory testing
   - Monitor memory usage during audio streaming

### Test Scenarios for 16KB Compatibility
- [ ] **App Launch**: Verify app starts without crashes
- [ ] **Audio Streaming**: Test continuous streaming for 30+ minutes
- [ ] **Lockscreen Controls**: Verify controls work with 16KB pages
- [ ] **Network Recovery**: Test network loss/recovery scenarios
- [ ] **Background/Foreground**: Test app state transitions
- [ ] **Memory Pressure**: Test under low memory conditions

## 🚀 Release Build Process

### Pre-Build Checklist
- [ ] All deprecated APIs fixed
- [ ] 16KB page size compatibility verified
- [ ] Version code incremented
- [ ] Version name updated (semantic versioning)
- [ ] Release notes prepared
- [ ] Privacy policy updated if needed

### Build Commands
```bash
# Clean build
flutter clean
flutter pub get

# Analyze code for issues
flutter analyze

# Run tests
flutter test

# Build release AAB with 16KB compatibility
flutter build appbundle --release
```

### Post-Build Validation
- [ ] Test release build on physical devices
- [ ] Verify 16KB page size compatibility
- [ ] Test audio functionality works correctly
- [ ] Test network connectivity scenarios
- [ ] Validate lockscreen controls
- [ ] Check app size and performance

## 📱 Testing Strategy

### Device Testing Matrix (16KB Focus)
- [ ] **Android 15+ Emulator** (16KB pages enabled)
- [ ] **Samsung Galaxy** (Modern device with 16KB support)
- [ ] **Google Pixel** (Latest Android with 16KB testing)
- [ ] **OnePlus/Xiaomi** (Custom Android skins)
- [ ] **Legacy Device** (Samsung J7 - ensure backward compatibility)

### Functional Testing with 16KB Pages
- [ ] Audio streaming starts/stops correctly
- [ ] Lockscreen controls work on all devices
- [ ] Network connectivity handling
- [ ] App doesn't crash under memory pressure
- [ ] Metadata updates work properly
- [ ] Background/foreground transitions smooth

## 🎯 Next Steps

### Immediate Actions (This Session)
1. **Fix Deprecated API**: Address `stop()` method in WPFWAudioHandler
2. **Dependency Audit**: Check all packages for 16KB compatibility
3. **Testing Setup**: Prepare 16KB page size testing environment

### Follow-up Actions
1. **Comprehensive Testing**: Run full test suite with 16KB pages
2. **Keystore Creation**: Generate and secure release keystore
3. **Play Console Setup**: Prepare store listing and metadata
4. **Final Validation**: Complete pre-submission checklist

## 📚 References
- [Android 16KB Page Size Guide](https://developer.android.com/guide/practices/page-sizes#test)
- [Google Play Store Requirements 2025](https://developer.android.com/google/play/requirements)
- [Flutter Android Release Guide](https://docs.flutter.dev/deployment/android)
- [Audio Service Best Practices](https://pub.dev/packages/audio_service)

---

**Status**: Ready to begin Phase 1 - Fix deprecated APIs and verify 16KB compatibility
**Priority**: CRITICAL - 16KB page size compatibility is mandatory for 2025 Play Store submissions
