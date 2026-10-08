# Store Release To-Do

## 1. Android release signing

Current status: blocked until `android/key.properties` and
`android/upload-keystore.jks` exist.

Create an upload keystore locally:

```bash
./scripts/create_android_upload_keystore.sh
```

If the app is already published, do not create a new keystore. Restore the
existing Play upload keystore and create `android/key.properties` from:

```bash
cp android/key.properties.example android/key.properties
```

`android/key.properties` and keystore files are ignored by git. Do not commit
them.

## 2. Android build

```bash
./scripts/build_android_store.sh
```

Upload this file to Play Console:

```text
build/app/outputs/bundle/release/app-release.aab
```

## 3. iOS signing

Current status: needs an Apple Distribution certificate/provisioning profile.

In Apple Developer / App Store Connect:

- Register bundle ID: `com.kneayerng.kycheck`
- Enable Push Notifications.
- Enable NFC Tag Reading.
- Enable Wi-Fi Information only if the app needs it in production.
- Create/select an App Store distribution provisioning profile.

Then build:

```bash
./scripts/build_ios_store.sh
```

Upload the IPA with Xcode Organizer, Transporter, or App Store Connect tooling.

## 4. Store metadata

Prepare:

- App name and descriptions.
- Screenshots for required device sizes.
- App icon and Play Store feature graphic.
- Contact email.
- Privacy policy URL.
- Demo reviewer account and server/login instructions.

## 5. Privacy declarations

Declare all data/permissions honestly in Google Play Data Safety and Apple App
Privacy:

- Login/user profile data.
- Location for attendance.
- Camera for QR scanning and profile/media workflows.
- Photos/media for chat or uploads.
- Microphone for voice messages.
- Push notification token/device identifiers.
- NFC tag scanning.
- Crash/log/diagnostic data if collected.

## 6. Final smoke test

Before submitting:

- Fresh install opens correctly.
- Server QR login works.
- Server status/test connection works.
- Login/logout works.
- Attendance check-in/check-out works.
- Notifications arrive and open correctly.
- Camera, location, media, microphone, and NFC permission prompts are clear.
- App works with production server only.
