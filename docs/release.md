# Release

## Signing

`android/app/build.gradle.kts` reads `android/key.properties` when it exists and signs `release` with it; otherwise it falls back to debug signing (so `flutter run --release` still works). `key.properties` and `*.jks` are git-ignored.

### Create the upload keystore (once)

```
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Put the `.jks` outside the repo (e.g. `C:\Users\<you>\keys\`) and create `android/key.properties`:

```
storeFile=C:\\Users\\<you>\\keys\\upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

**Back up the `.jks` and the passwords outside the PC** (password manager + a USB stick or cloud). With Play App Signing a lost upload key can be reset through Play support, but it takes days.

## Build

```
flutter build appbundle                 # for Google Play
flutter build apk --split-per-abi       # for GitHub Releases
```

Bump `version:` in `pubspec.yaml` (`name+build`) before each upload; Play needs a higher build number every time.

Per-ABI APK sizes (measured on the first release build): (`flutter build apk --split-per-abi`; the `.aab` is ~115 MB).

- arm64-v8a: 48.4 MB
- armeabi-v7a: 38.5 MB
- x86_64: 53.5 MB

`armeabi-v7a` is kept: cheap old phones are exactly the target.

## Play Console: data safety answers

- **Does the app collect or share user data?** The developer collects nothing. Declare as *shared* (only when the user opts in): **text spoken** (App activity / other user-generated content), sent to ElevenLabs with the user's own key.
- **Collected by the developer:** none. No accounts, no analytics, no ads.
- **Shared:** the text to be spoken goes to ElevenLabs, only if the user sets up an ElevenLabs key. Optional (user can turn it off / never turn it on).
- **Audio:** the microphone records sentences the user chooses; recordings stay on the device and are never sent anywhere (not collected).
- **Encrypted in transit:** yes (HTTPS for catalog, voice downloads, ElevenLabs).
- **Data deletion request:** not applicable (nothing is stored by the developer); the user can delete everything by clearing app data or uninstalling.
- **Privacy policy URL:** `https://github.com/stamasg84/mondom/blob/main/PRIVACY.md`
- Permissions to justify: `RECORD_AUDIO` (message banking), `INTERNET` (voice downloads, optional ElevenLabs).

## Release steps (T44)

1. `flutter analyze` and `flutter test` pass.
2. Build the appbundle and per-ABI APKs; install the release APK on the Pixel 6a and run through the main flows (speak, record, backup, alarm, voice download).
3. Check on a device that system-TTS speed affects `synthesizeToFile` (see `docs/architecture.md` "Speech speed").
4. Take the phone screenshots for the Play listing (Play needs at least 2; 3–4 is good: speaking screen, lists, voice picker). They are not used in the READMEs, so they need no upkeep there.
5. Upload the `.aab` to a Play internal testing track, fill the store listing and data safety form (above), then promote.
6. Tag the release on GitHub and attach the per-ABI APKs.
