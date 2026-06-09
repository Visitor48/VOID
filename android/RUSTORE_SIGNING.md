# Android release signing for RuStore (VOID)

This project is configured for release signing via `android/key.properties`.
Application ID: `ru.voidapp.focus`

If `key.properties` is missing, release builds fall back to the debug key (local testing only). RuStore requires a properly signed release build.

---

## 1. Generate a keystore

Run once on your machine. **Back up the keystore and passwords** — you cannot publish updates to RuStore without the same key.

### Windows (PowerShell)

```powershell
cd c:\void_app\android\app

keytool -genkeypair -v `
  -keystore void-release.jks `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias void-upload `
  -storetype JKS
```

### macOS / Linux

```bash
cd android/app

keytool -genkeypair -v \
  -keystore void-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias void-upload \
  -storetype JKS
```

You will be prompted for:

- Keystore password (remember it → `storePassword`)
- Key password (often same as keystore → `keyPassword`)
- Name, organization, country, etc.

Result: `android/app/void-release.jks` (already ignored by git).

> `keytool` is included with the JDK. If the command is not found, install [Android Studio](https://developer.android.com/studio) or a JDK 17+ and add it to `PATH`.

---

## 2. Configure `key.properties`

Copy the example file:

```powershell
copy c:\void_app\android\key.properties.example c:\void_app\android\key.properties
```

Edit `android/key.properties`:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=void-upload
storeFile=void-release.jks
```

Notes:

- `storeFile` is relative to the `android/app/` module (where `build.gradle.kts` lives).
- Keep `key.properties` and `void-release.jks` **private** — they are listed in `android/.gitignore`.

---

## 3. `build.gradle.kts` (already configured)

`android/app/build.gradle.kts` reads `android/key.properties` and applies the `release` signing config when the file exists.

Relevant behavior:

- `signingConfigs.release` — loads alias, passwords, and keystore path from `key.properties`
- `buildTypes.release` — uses release signing if `key.properties` exists, otherwise debug (for local dev only)

No manual Gradle edits are needed after creating `key.properties`.

---

## 4. Build a signed release

From the project root:

### APK (common for RuStore)

```powershell
cd c:\void_app
D:\flutter\bin\flutter.bat build apk --release
```

Output:

```
build\app\outputs\flutter-apk\app-release.apk
```

### App Bundle (AAB, if RuStore asks for bundle)

```powershell
D:\flutter\bin\flutter.bat build appbundle --release
```

Output:

```
build\app\outputs\bundle\release\app-release.aab
```

### Verify signing (optional)

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\34.0.0\apksigner.bat" verify --verbose build\app\outputs\flutter-apk\app-release.apk
```

Use your installed build-tools version if `34.0.0` differs.

---

## 5. Upload to RuStore

1. Open [RuStore Console](https://console.rustore.ru/) → your app → new version.
2. Upload `app-release.apk` or `app-release.aab`.
3. Ensure **versionCode** in `pubspec.yaml` (`1.0.0+1` → build number `1`) increases for each release (`1.0.0+2`, `1.0.0+3`, …).
4. Fill in release notes and submit for moderation.

---

## Checklist before each release

- [ ] `pubspec.yaml` version bumped (`version: x.y.z+build`)
- [ ] `flutter test` passes
- [ ] `flutter build apk --release` succeeds
- [ ] Same keystore as previous RuStore uploads (never lose `void-release.jks`)
- [ ] `key.properties` present on the build machine (CI secret or local file)

---

## CI / team builds

Do not commit secrets. In CI, inject `key.properties` and the keystore from secure variables, for example:

```properties
storeFile=void-release.jks
```

Place the keystore file in `android/app/` during the pipeline step before `flutter build apk --release`.
