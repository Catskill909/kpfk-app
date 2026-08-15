# KPFK App Transformation - Verification Checklist

## ✅ Completed Transformations

### Project Structure
- [x] Folder renamed: `wpfw_radio` → `kpfk_radio`
- [x] All `.md` files moved to `old-docs/`
- [x] New `README.md` created
- [x] `TRANSFORMATION-SUMMARY.md` created

### Package & App IDs
- [x] Flutter package: `wpfw_radio` → `kpfk_radio` (pubspec.yaml)
- [x] Android package: `app.pacifica.wpfw` → `app.pacifica.kpfk`
- [x] iOS bundle ID: `com.pacifica.wpfw` → `app.pacifica.kpfk`
- [x] Android namespace updated in build.gradle
- [x] AndroidManifest.xml package updated
- [x] iOS project.pbxproj updated

### Android Native Code
- [x] Kotlin package structure: `app/pacifica/wpfw/` → `app/pacifica/kpfk/`
- [x] MainActivity.kt - package and references updated
- [x] SamsungMediaSessionManager.kt - package and references updated
- [x] Notification channel IDs: `com.wpfwfm.radio.audio` → `com.kpfkfm.radio.audio`
- [x] Broadcast intents: `wpfw_media_action` → `kpfk_media_action`
- [x] App label: `WPFW` → `KPFK`

### Flutter/Dart Code
- [x] Audio handler renamed: `wpfw_audio_handler.dart` → `kpfk_audio_handler.dart`
- [x] Class renamed: `WPFWAudioHandler` → `KPFKAudioHandler`
- [x] App class renamed: `WPFWRadioApp` → `KPFKRadioApp`
- [x] Logger name: `WPFWRadio` → `KPFKRadio`
- [x] Method channels updated: `app.pacifica.wpfw/...` → `app.pacifica.kpfk/...`
- [x] All import statements updated

### Station Information
- [x] Station name: `WPFW` → `KPFK`
- [x] Frequency: `89.3 FM` → `90.7 FM`
- [x] Slogan: `Jazz and Justice` → `Pacifica Radio`
- [x] Default metadata updated throughout codebase

### URLs & Endpoints
- [x] Stream URL: `wpfw.m3u` → `kpfk.m3u`
- [x] Website: `wpfwfm.org` → `kpfk.org`
- [x] Logo URLs: `confessor.wpfwfm.org` → `confessor.kpfk.org`
- [x] Donate URL updated
- [x] Schedule, playlist, archive URLs updated
- [x] Social media links updated

### UI Text Updates
- [x] Drawer menu: "WPFW Website" → "KPFK Website"
- [x] Donate sheet: "Support WPFW" → "Support KPFK"
- [x] Accessibility announcements updated
- [x] Color comments updated

### Security & Signing
- [x] Old keystores removed (wpfw-keystore, wpfw-keystore 2, wpfw-keystore.zip)
- [x] android/key.properties deleted
- [x] Signing configs removed from build.gradle
- [x] Ready for new keystore generation

### Dependencies
- [x] `flutter pub get` runs successfully
- [x] No package name conflicts
- [x] All imports resolve correctly

## 🔍 Final Verification Results

### Code Search Results
- Total WPFW references remaining: **545** (all in iOS Pods and generated files - safe to ignore)
- All source code files (.dart, .kt, .xml, .gradle) updated ✅
- No WPFW references in user-editable code ✅

### Build Status
- [x] Dependencies resolved successfully
- [ ] Debug build tested (pending)
- [ ] Android APK build tested (pending)
- [ ] iOS build tested (pending)

## ⚠️ Action Items Before Release

### 1. Generate New Android Keystore
```bash
cd kpfk_radio/android
mkdir -p ../../kpfk-keystore
keytool -genkey -v -keystore ../../kpfk-keystore/kpfk-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias kpfk-upload-key
```

### 2. Create android/key.properties
```properties
storePassword=<your-secure-password>
keyPassword=<your-secure-password>
keyAlias=kpfk-upload-key
storeFile=../../kpfk-keystore/kpfk-upload-keystore.jks
```

### 3. Update build.gradle Signing Config
Uncomment and update the signing configuration in:
`kpfk_radio/android/app/build.gradle`

### 4. Verify Stream URLs
- [ ] Test KPFK stream URL: `https://docs.pacifica.org/kpfk/kpfk.m3u`
- [ ] Verify metadata endpoints work
- [ ] Test fallback stream URLs

### 5. Update Assets
- [ ] Replace app icons with KPFK branding
- [ ] Update splash screen images
- [ ] Verify notification icon
- [ ] Update lockscreen artwork URLs

### 6. iOS Configuration
- [ ] Set up Apple Developer account for KPFK
- [ ] Create App ID: `app.pacifica.kpfk`
- [ ] Generate provisioning profiles
- [ ] Configure signing certificates in Xcode

### 7. Test Functionality
- [ ] Stream playback works
- [ ] Metadata updates correctly
- [ ] Lockscreen controls work (Android)
- [ ] Lockscreen controls work (iOS)
- [ ] Notifications display correctly
- [ ] All menu links work
- [ ] Donate page loads
- [ ] Social media links work
- [ ] Sleep timer functions
- [ ] Network recovery works

### 8. Verify URLs
- [ ] Schedule page loads
- [ ] Playlist page loads
- [ ] Archive page loads
- [ ] About page loads
- [ ] Privacy policy page loads
- [ ] All social media links valid

## 📝 Notes

### Known Placeholders
The following URLs are placeholders and should be verified:
- Stream URL: `https://docs.pacifica.org/kpfk/kpfk.m3u`
- Logo: `https://confessor.kpfk.org/playlist/images/kpfk_logo.png`
- Schedule: `https://www.kpfk.org/schedule/`
- Playlist: `https://www.kpfk.org/playlist/`
- Archive: `https://archive.kpfk.org/?mob=1`

### Social Media Accounts
Verify these are the correct KPFK accounts:
- Facebook: `https://www.facebook.com/kpfkradio/`
- Twitter: `https://x.com/kpfk_fm`
- Instagram: `https://www.instagram.com/kpfk_fm/`
- YouTube: `https://www.youtube.com/user/kpfkradio`
- Email: `contact@kpfk.org`

### iOS Pods
The grep search found 545 WPFW references, but these are all in:
- `ios/Pods/` - Third-party dependencies (safe to ignore)
- Generated files that will be recreated on build
- No action needed for these

## ✅ Transformation Complete

The app has been successfully transformed from WPFW to KPFK. All source code, configuration files, and user-facing text have been updated. The app is ready for keystore generation, asset updates, and testing.

**Status**: Ready for development and testing phase
**Next Step**: Generate Android keystore and test debug build
