# Android Signing — KPFK Radio (app.pacifica.kpfk)

This folder contains the release signing keystore for the KPFK Radio Android app.
Keep this folder secure. Do not commit `key.properties` or `*.jks` files to a public repository.

---

## Contents

| File | Description |
|------|-------------|
| `kpfk-release.jks` | Release keystore (PKCS12 format) |
| `key.properties` | Signing credentials — **never commit to git** |
| `SIGNING-INSTRUCTIONS.md` | This file |

---

## Keystore Details

| Field | Value |
|-------|-------|
| File | `kpfk-release.jks` |
| Format | PKCS12 |
| Algorithm | RSA 2048-bit |
| Validity | 10,000 days (~27 years) |
| Key alias | `pacifica-kpfk` |
| CN | Pacifica Foundation |
| Organization | Pacifica Foundation |
| Org Unit | Engineering |
| City | Los Angeles |
| State | CA |
| Country | US |

---

## Credentials

| Field | Value |
|-------|-------|
| Keystore password | `4QPDlnY*^3pXXrH5gFI!va3k` |
| Key password | `4QPDlnY*^3pXXrH5gFI!va3k` |

> **Note:** PKCS12 keystores use a single password for both the keystore and the key.
> Both values above are identical and intentional.

Store these credentials in a password manager (1Password, Bitwarden, etc.).
The `key.properties` file in this folder already has them pre-filled.

---

## One-Time Setup (per machine)

Do this once on any machine that will build a release APK or App Bundle.

**1. Copy `key.properties` to the Flutter Android project:**

```bash
cp android-signing/key.properties kpfk_radio/android/key.properties
```

The path `kpfk_radio/android/key.properties` is gitignored — it will not be committed.

**2. Verify the keystore path in `key.properties` is correct.**

The `storeFile` value uses a path relative to `kpfk_radio/android/app/`:

```
storeFile=../../../android-signing/kpfk-release.jks
```

This resolves to `kpfk-app/android-signing/kpfk-release.jks` — correct as long as
the repo is cloned with the standard `kpfk-app` folder name. If your local folder name
differs, update the `storeFile` path to match.

---

## Building a Signed Release

**App Bundle (for Play Store upload):**

```bash
cd kpfk_radio
flutter build appbundle --release
```

Output: `kpfk_radio/build/app/outputs/bundle/release/app-release.aab`

**APK (for direct install / testing):**

```bash
cd kpfk_radio
flutter build apk --release
```

Output: `kpfk_radio/build/app/outputs/flutter-apk/app-release.apk`

---

## Verifying the Keystore

To confirm the keystore is valid and show its fingerprint:

```bash
keytool -list -v \
  -keystore android-signing/kpfk-release.jks \
  -alias pacifica-kpfk \
  -storepass '4QPDlnY*^3pXXrH5gFI!va3k'
```

---

## How Signing Works in This Project

`kpfk_radio/android/app/build.gradle` loads credentials at build time:

```groovy
def keystorePropertiesFile = rootProject.file('key.properties')
def keystoreProperties = new Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

The `release` build type uses `signingConfigs.release`. If `key.properties` is missing,
the signing config fields are null and the build will fail with a signing error —
a safe failure that prevents unsigned release builds from being shipped accidentally.

---

## Google Play — First Upload

When uploading to the Play Store for the first time:

1. Build an App Bundle (`.aab`) as shown above.
2. Go to Google Play Console → `app.pacifica.kpfk` → Production (or Internal Testing).
3. Upload the `.aab` file.
4. Google Play will extract your signing certificate fingerprint from the bundle.

**App Signing by Google Play (recommended):** Google re-signs the APK it delivers to
users with a Google-managed key. Your upload key (`pacifica-kpfk`) is what you use
to sign the bundle you upload — Google handles the rest. If you ever lose the upload
key, Google can issue a new one.

---

## If the Keystore Is Lost

The keystore in this folder is the upload key for the Play Store.

- If lost before any Play Store upload: regenerate a new keystore and start fresh.
- If lost after a Play Store upload with App Signing enabled: contact Google Play
  support — they can reset your upload key.
- If lost after upload without App Signing: **you cannot update the app** on the
  Play Store. This is why keeping this keystore backed up is critical.

**Recommended backups:**
- Password manager (1Password, Bitwarden) — attach the `.jks` file as a secure note
- Encrypted cloud storage
- A second offline copy with a trusted team member

---

## Troubleshooting

**`key.properties` not found / signing error at build time:**
Make sure you copied `key.properties` to `kpfk_radio/android/key.properties`.

**`storeFile not found` error:**
The path in `storeFile` is relative to `kpfk_radio/android/app/`. Check that your
local repo folder is named `kpfk-app`. If not, update the `storeFile` path.

**Wrong password error:**
The keystore and key password are both: `4QPDlnY*^3pXXrH5gFI!va3k`

**`keytool` not found:**
Install the JDK: `brew install openjdk` (macOS) or install Android Studio (includes JDK).
