# KPFK Radio App - Quick Start Guide

## 🎉 Transformation Complete!

Your WPFW app has been successfully transformed into a **brand new KPFK Radio app**.

## 📁 Project Structure

```
kpfk-app/
├── kpfk_radio/              # Main Flutter app (renamed from wpfw_radio)
│   ├── android/             # Android native code
│   ├── ios/                 # iOS native code
│   ├── lib/                 # Dart/Flutter source code
│   └── pubspec.yaml         # Dependencies (updated to kpfk_radio)
├── old-docs/                # Original WPFW documentation (33 files)
├── README.md                # Project overview
├── history/                  # Completed transformation and testing records
│   ├── TRANSFORMATION-SUMMARY.md
│   └── VERIFICATION-CHECKLIST.md
└── QUICK-START.md           # This file
```

## ✅ What's Been Done

### Complete Rebranding
- ✅ All WPFW references changed to KPFK
- ✅ Station info: WPFW 89.3 FM → KPFK 90.7 FM
- ✅ Package IDs updated to `app.pacifica.kpfk`
- ✅ All URLs updated to KPFK endpoints
- ✅ Social media links updated

### Clean Slate
- ✅ Old keystores removed
- ✅ Signing configs cleared
- ✅ Ready for new certificates
- ✅ Dependencies verified (`flutter pub get` works)

## 🚀 Next Steps

### 1. Test the App (5 minutes)
```bash
cd kpfk_radio
flutter run
```

This will run the app in debug mode on a connected device/emulator.

### 2. Generate Android Keystore (when ready for release)
```bash
cd kpfk_radio/android
mkdir -p ../../kpfk-keystore
keytool -genkey -v -keystore ../../kpfk-keystore/kpfk-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias kpfk-upload-key
```

Follow the prompts to create your keystore. **Save the password securely!**

### 3. Configure Signing
Create `kpfk_radio/android/key.properties`:
```properties
storePassword=YOUR_PASSWORD_HERE
keyPassword=YOUR_PASSWORD_HERE
keyAlias=kpfk-upload-key
storeFile=../../kpfk-keystore/kpfk-upload-keystore.jks
```

Then uncomment the signing configuration in `android/app/build.gradle`.

## 🔧 Important Configuration

### Stream URLs to Verify
These are currently set to KPFK defaults - verify they work:
- **Stream**: `https://docs.pacifica.org/kpfk/kpfk.m3u`
- **Logo**: `https://confessor.kpfk.org/playlist/images/kpfk_logo.png`

Update in: `lib/core/constants/stream_constants.dart`

### Social Media Links
Verify these are correct KPFK accounts:
- Facebook: kpfkradio
- Twitter: kpfk_fm
- Instagram: kpfk_fm
- YouTube: kpfkradio

Update in: `lib/core/constants/stream_constants.dart`

## 📱 Build Commands

### Debug Build
```bash
cd kpfk_radio
flutter run
```

### Android Release APK
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS Release (requires Mac)
```bash
flutter build ios --release
```
Then open in Xcode to archive and upload to App Store.

## 🎨 Customization Needed

### 1. App Icons
Replace these with KPFK branding:
- `assets/icons/app_icon.png` - Main app icon
- `android/app/src/main/res/drawable/ic_notification.xml` - Notification icon

Then run:
```bash
flutter pub run flutter_launcher_icons
```

### 2. Splash Screen
Replace:
- `assets/icons/splash_icon_fixed.png`

Then run:
```bash
flutter pub run flutter_native_splash:create
```

### 3. Colors (optional)
Update brand colors in:
- `lib/presentation/theme/app_theme.dart`

## 📋 Testing Checklist

Before releasing, test:
- [ ] App launches successfully
- [ ] Stream plays audio
- [ ] Metadata updates (song/show info)
- [ ] Play/pause buttons work
- [ ] Lockscreen controls work
- [ ] Notifications display correctly
- [ ] All menu items open correct pages
- [ ] Donate page loads
- [ ] Sleep timer works
- [ ] App survives network interruption

## 🆘 Troubleshooting

### Build Errors
```bash
# Clean and rebuild
cd kpfk_radio
flutter clean
flutter pub get
flutter run
```

### Signing Errors (Android)
- Verify `key.properties` exists and has correct paths
- Check keystore file exists at specified location
- Ensure passwords match

### iOS Signing Errors
- Open `ios/Runner.xcworkspace` in Xcode
- Select your development team
- Let Xcode manage signing automatically (for development)

## 📚 Documentation

- **history/TRANSFORMATION-SUMMARY.md** - Complete list of transformation changes
- **history/VERIFICATION-CHECKLIST.md** - Historical testing checklist
- **old-docs/** - Original WPFW app documentation for reference

## 🎯 Key Files to Know

### Configuration
- `pubspec.yaml` - Dependencies and app metadata
- `lib/core/constants/stream_constants.dart` - All URLs and station info
- `android/app/build.gradle` - Android build config
- `ios/Runner.xcodeproj/project.pbxproj` - iOS build config

### Main Code
- `lib/main.dart` - App entry point
- `lib/presentation/pages/home_page.dart` - Main UI
- `lib/services/audio_service/kpfk_audio_handler.dart` - Audio playback
- `lib/data/repositories/stream_repository.dart` - Stream management

## 💡 Tips

1. **Always test on real devices** - Emulators don't show all issues
2. **Test lockscreen controls** - Critical for radio apps
3. **Monitor network recovery** - Users will lose connection
4. **Check notification behavior** - Should not show app badge
5. **Verify metadata updates** - Show/song info should update

## 🚀 Ready to Go!

Your KPFK app is ready for development and testing. Start with:

```bash
cd kpfk_radio
flutter run
```

Good luck with your KPFK Radio app! 📻
