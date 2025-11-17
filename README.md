# KPFK Radio App

This is a brand new Flutter application for KPFK 90.7 FM Pacifica Radio.

## App Information

- **App Name**: KPFK Radio
- **Package Name**: `kpfk_radio`
- **Android Package ID**: `app.pacifica.kpfk`
- **iOS Bundle ID**: `app.pacifica.kpfk`
- **Station**: KPFK 90.7 FM
- **Network**: Pacifica Radio

## Project Structure

```
kpfk-app/
├── kpfk_radio/          # Main Flutter app directory
│   ├── android/         # Android-specific code
│   ├── ios/             # iOS-specific code
│   ├── lib/             # Dart source code
│   └── pubspec.yaml     # Flutter dependencies
└── old-docs/            # Documentation from original cloned app
```

## Setup Status

✅ **Completed**:
- Removed old WPFW keystores and signing configurations
- Renamed project folder from `wpfw_radio` to `kpfk_radio`
- Updated Android package ID to `app.pacifica.kpfk`
- Updated iOS bundle identifier to `app.pacifica.kpfk`
- Updated all code references from WPFW to KPFK
- Updated station information (KPFK 90.7 FM)
- Moved legacy documentation to `old-docs/`

⚠️ **TODO - Before Building**:
1. Generate new Android keystore for app signing
2. Create and configure `android/key.properties` file
3. Update signing configuration in `android/app/build.gradle`
4. Verify KPFK stream URLs are correct
5. Update app icons and splash screens
6. Configure iOS signing certificates

## Next Steps

### Android Keystore Generation

When ready to build release versions, generate a new keystore:

```bash
cd kpfk_radio/android
keytool -genkey -v -keystore ../kpfk-keystore/kpfk-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias kpfk-upload-key
```

Then create `android/key.properties`:

```properties
storePassword=<your-password>
keyPassword=<your-password>
keyAlias=kpfk-upload-key
storeFile=../kpfk-keystore/kpfk-upload-keystore.jks
```

### Build Commands

```bash
cd kpfk_radio

# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Build Android APK
flutter build apk --release

# Build iOS (requires Mac)
flutter build ios --release
```

## Important Notes

- This is a **BRAND NEW APP** - all old WPFW configurations have been removed
- Keystore signing is currently disabled - must be configured before release builds
- Stream URLs and metadata endpoints need verification for KPFK
- Social media links and website URLs have been updated to KPFK defaults

## Documentation

Legacy documentation from the cloned WPFW app is available in the `old-docs/` folder for reference.
