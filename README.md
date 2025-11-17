# KPFK Radio App

A Flutter-based radio streaming application for KPFK 90.7 FM Pacifica Radio with advanced features including background audio playback, lockscreen controls, sleep timer, and accessibility support.

## 📱 App Information

- **App Name**: KPFK Radio
- **Package Name**: `kpfk_radio`
- **Android Package ID**: `app.pacifica.kpfk`
- **iOS Bundle ID**: `app.pacifica.kpfk`
- **Station**: KPFK 90.7 FM
- **Network**: Pacifica Radio
- **Website**: https://www.kpfk.org

## 🚀 Quick Start

```bash
# Navigate to the app directory
cd kpfk_radio

# Install dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Build for release
flutter build apk --release    # Android
flutter build ios --release    # iOS
```

## 📁 Project Structure

```
kpfk-app/
├── kpfk_radio/              # Main Flutter app directory
│   ├── android/             # Android native code
│   ├── ios/                 # iOS native code
│   ├── lib/                 # Dart/Flutter source code
│   │   ├── core/            # Constants, DI, utilities
│   │   ├── data/            # Repositories, models
│   │   ├── presentation/    # UI (pages, widgets, bloc)
│   │   └── services/        # Audio, metadata services
│   ├── pubspec.yaml         # Flutter dependencies
│   └── README.md            # Detailed app documentation
├── old-docs/                # Legacy documentation
└── README.md                # This file
```

## ✨ Features

- **Live Audio Streaming**: High-quality audio playback with buffering optimization
- **Background Playback**: Continue listening with the app in background
- **Lockscreen Controls**: Full iOS/Android lockscreen integration with metadata
- **Sleep Timer**: Customizable sleep timer with presets (15/30/45/60 minutes)
- **Offline Detection**: Automatic network monitoring with retry functionality
- **Donate Integration**: In-app donation modal with WebView
- **Pacifica Network**: Access to other Pacifica stations and services
- **Accessibility**: Screen reader support with live announcements

## 🔧 Configuration

### Stream URLs

Current stream configuration (in `lib/core/constants/stream_constants.dart`):
- **Stream URL**: `https://docs.pacifica.org/kpfk/kpfk.m3u`
- **Station Logo**: `https://confessor.kpfk.org/pix/KPFK.png`
- **Website**: `https://www.kpfk.org`

### Social Media

- **Facebook**: https://www.facebook.com/KPFK90.7/
- **Twitter/X**: https://x.com/KPFK/
- **Instagram**: https://www.instagram.com/kpfk/
- **YouTube**: https://www.youtube.com/@KPFKTV/videos/
- **Email**: gm@kpfk.org

## 🏗️ Architecture

- **Framework**: Flutter (Dart)
- **State Management**: `flutter_bloc` + `get_it` service locator
- **Audio Engine**: `just_audio` with `audio_service` and `audio_session`
- **Networking**: `dio` and `http`
- **WebView**: `flutter_inappwebview`
- **UI**: Material 3 theme with Google Fonts (Oswald & Poppins)

## 📦 Key Dependencies

- `just_audio` - Audio playback
- `audio_service` - Background audio & notifications
- `flutter_bloc` - State management
- `get_it` - Dependency injection
- `flutter_inappwebview` - In-app web content
- `connectivity_plus` - Network monitoring
- `google_fonts` - Custom typography

See `kpfk_radio/pubspec.yaml` for complete dependency list.

## 🔐 Release Build Setup

### Android Keystore

Generate a new keystore for release builds:

```bash
cd kpfk_radio/android
mkdir -p ../../kpfk-keystore
keytool -genkey -v -keystore ../../kpfk-keystore/kpfk-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias kpfk-upload-key
```

Create `kpfk_radio/android/key.properties`:

```properties
storePassword=YOUR_PASSWORD_HERE
keyPassword=YOUR_PASSWORD_HERE
keyAlias=kpfk-upload-key
storeFile=../../kpfk-keystore/kpfk-upload-keystore.jks
```

### iOS Signing

Open `kpfk_radio/ios/Runner.xcworkspace` in Xcode and configure:
- Development team
- Signing certificates
- Provisioning profiles

## 🧪 Testing

```bash
cd kpfk_radio

# Run tests
flutter test

# Analyze code
flutter analyze

# Check for issues
flutter doctor
```

## 📚 Additional Documentation

- **QUICK-START.md** - Detailed setup and configuration guide
- **FINAL-STATUS.md** - Project transformation status
- **kpfk_radio/README.md** - In-depth app documentation
- **old-docs/** - Legacy documentation for reference

## 🛠️ Development

### Prerequisites

- Flutter SDK (stable channel)
- Xcode (for iOS development)
- Android Studio / Android SDK (for Android development)

### Running the App

```bash
# Check Flutter installation
flutter doctor

# Navigate to app directory
cd kpfk_radio

# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Run on specific device
flutter run -d <device-id>
```

## 📝 Notes

- This app was transformed from a WPFW Radio app to KPFK Radio
- All WPFW references have been updated to KPFK
- Stream URLs and social media links are configured for KPFK
- Keystore signing must be configured before release builds
- iOS lockscreen controls are fully functional
- Accessibility features include screen reader support

## 📄 License

Copyright © 2025 Pacifica Radio - KPFK 90.7 FM
