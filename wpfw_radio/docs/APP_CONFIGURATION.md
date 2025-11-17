# App Configuration Notes

## Application ID
The application ID for both platforms will be: `app.pacifica.wpfw`

### Android Configuration
Required changes in `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        applicationId "app.pacifica.wpfw"
        ...
    }
}
```

And in `android/app/src/main/AndroidManifest.xml`:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="app.pacifica.wpfw">
```

### iOS Configuration
Required changes in `ios/Runner.xcodeproj/project.pbxproj`:
```
PRODUCT_BUNDLE_IDENTIFIER = app.pacifica.wpfw;
```

And in `ios/Runner/Info.plist`:
```xml
<key>CFBundleIdentifier</key>
<string>app.pacifica.wpfw</string>
```

## Implementation Steps
1. Update Android configuration files
2. Update iOS configuration files
3. Test building on both platforms
4. Verify app signing settings

## Notes
- Ensure consistency across all platform-specific files
- Update any existing references to the bundle ID
- Consider adding app signing configurations