# 🔐 ANDROID SIGNING - ONE TRUTH REFERENCE

## ⚠️ CRITICAL: THIS IS THE SINGLE SOURCE OF TRUTH FOR ALL ANDROID SIGNING

**Last Updated**: September 26, 2025  
**Status**: ✅ PRODUCTION READY - VERIFIED WORKING  
**Builds Completed**: APK (55MB) + AAB (30MB) - Both signed successfully

---

## 🎯 ONE TRUTH KEYSTORE CONFIGURATION

### 📁 Keystore Location
```
/Users/paulhenshaw/Desktop/wpfw-app/wpfw-keystore/wpfw-upload-keystore.jks
```

### 🔑 Keystore Properties (key.properties)
```properties
storePassword=pacifica
keyPassword=pacifica
keyAlias=wpfw-upload-key
storeFile=/Users/paulhenshaw/Desktop/wpfw-app/wpfw-keystore/wpfw-upload-keystore.jks
```

### 🏢 Certificate Information
- **Common Name (CN)**: WPFW Radio
- **Organizational Unit (OU)**: Pacifica Foundation
- **Organization (O)**: Pacifica Foundation
- **City/Locality (L)**: Washington
- **State/Province (ST)**: DC
- **Country (C)**: US

### 🔧 Technical Specifications
- **Algorithm**: RSA
- **Key Size**: 2048 bits
- **Signature**: SHA256withRSA
- **Validity**: Until 2053-02-09 (27+ years)
- **Created**: September 24, 2025
- **Serial**: 6887ddb0b57f9ea3

---

## 🚀 VERIFIED BUILD COMMANDS

### App Bundle (Google Play Store - RECOMMENDED)
```bash
cd /Users/paulhenshaw/Desktop/wpfw-app/wpfw_radio
flutter build appbundle --release
```
**Output**: `build/app/outputs/bundle/release/app-release.aab` (30MB)

### APK (Testing/Distribution)
```bash
cd /Users/paulhenshaw/Desktop/wpfw-app/wpfw_radio
flutter build apk --release
```
**Output**: `build/app/outputs/flutter-apk/app-release.apk` (55MB)

---

## 📋 GRADLE CONFIGURATION (VERIFIED WORKING)

### build.gradle Path Configuration
```gradle
// Load keystore properties for release signing
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('../../wpfw-keystore/key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

### Signing Configuration
```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
```

---

## ✅ VERIFICATION COMMANDS

### Verify APK Signature
```bash
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk
```

### Check Keystore Details
```bash
keytool -list -v -keystore /Users/paulhenshaw/Desktop/wpfw-app/wpfw-keystore/wpfw-upload-keystore.jks -storepass pacifica
```

---

## 🔒 SECURITY & BACKUP

### File Structure
```
wpfw-keystore/
├── wpfw-upload-keystore.jks           # THE KEYSTORE (2826 bytes)
├── key.properties                     # Build configuration
├── KEYSTORE-INFO.md                   # Documentation
├── wpfw-keystore-COMPLETE-backup.zip  # SECURE BACKUP (5472 bytes)
└── complete-setup.sh                  # Setup script
```

### Critical Security Rules
1. **NEVER** commit keystore to version control
2. **NEVER** share keystore passwords in plain text
3. **ALWAYS** use secure channels for sharing
4. **BACKUP** keystore in multiple secure locations

---

## 📤 SECURE FILE SHARING METHODS

### For Team Members
1. **Encrypted USB Drive**: Physical transfer of keystore folder
2. **Secure Cloud Storage**: 
   - Use encrypted services (1Password, Bitwarden vaults)
   - Share backup ZIP with separate password communication
3. **Secure File Transfer**:
   - Use services like Firefox Send, WeTransfer (password protected)
   - Share password via separate secure channel (Signal, encrypted email)

### Sharing Checklist
- [ ] Share `wpfw-keystore-COMPLETE-backup.zip` (contains all files)
- [ ] Communicate passwords via separate secure channel
- [ ] Verify recipient can extract and use keystore
- [ ] Document who has access and when

---

## 🚨 TROUBLESHOOTING - NEVER STRUGGLE AGAIN

### If Build Fails with Signing Errors:

1. **Verify keystore exists**:
   ```bash
   ls -la /Users/paulhenshaw/Desktop/wpfw-app/wpfw-keystore/wpfw-upload-keystore.jks
   ```

2. **Check key.properties path**:
   ```bash
   cat /Users/paulhenshaw/Desktop/wpfw-app/wpfw-keystore/key.properties
   ```

3. **Verify build.gradle path**:
   - Must be: `rootProject.file('../../wpfw-keystore/key.properties')`
   - From android directory: `../../wpfw-keystore/key.properties`

4. **Test keystore access**:
   ```bash
   keytool -list -keystore /Users/paulhenshaw/Desktop/wpfw-app/wpfw-keystore/wpfw-upload-keystore.jks -storepass pacifica
   ```

### Common Issues & Solutions:
- **"storeFile not found"**: Check absolute path in key.properties
- **"NullPointerException"**: Usually path resolution issue
- **"Invalid keystore"**: Verify keystore file integrity

---

## 🎯 GOOGLE PLAY APP SIGNING

### How It Works
1. **Upload Key**: Our keystore signs app bundles for upload
2. **App Signing Key**: Google generates and manages the actual signing key
3. **Distribution**: Google re-signs with their managed key for users

### Benefits
- ✅ Google manages app signing key securely
- ✅ Key recovery if upload key is lost
- ✅ Optimized APKs for different devices
- ✅ Enhanced security

---

## 📞 EMERGENCY CONTACTS

### If Keystore is Lost/Corrupted:
1. Check backup locations immediately
2. Contact Google Play Console support
3. Use Google Play App Signing recovery (if enrolled)

### Team Access:
- **Primary**: Paul Henshaw
- **Backup Access**: [Add team members who have keystore access]

---

## 🔄 MAINTENANCE SCHEDULE

### Monthly:
- [ ] Verify keystore file integrity
- [ ] Test build process
- [ ] Update backup locations

### Before Each Release:
- [ ] Verify signing configuration
- [ ] Test both APK and AAB builds
- [ ] Confirm file sizes and signatures

---

**🚨 REMEMBER: THIS IS THE ONE TRUTH - ALL OTHER DOCS MUST REFERENCE THIS FILE**

**Last Successful Build**: September 26, 2025 12:28 PM EDT  
**Next Review Date**: October 26, 2025
