# FixMate local Android development

Last verified: 6 August 2026 (Asia/Dhaka)

## Supported local setup

- Product: FixMate
- Dart package: `fixmate`
- Android application ID and namespace: `com.fixmatebd.app`
- Firebase project: `fixmate-ce36d`
- Flutter: 3.44.8
- Dart: 3.12.2
- Primary test phone: M2003J15SC, Android 12 / API 31, android-arm64
- Device ID when connected: `c57ddc760409`

The repository has no local-path or Git package dependencies. Android debug
builds use the tracked Firebase client configuration. Release builds continue
to require a private release keystore and an untracked `android/key.properties`;
they never fall back to the debug signing key.

## First run

Enable Developer options and USB debugging on the phone, connect it by USB,
accept the phone's RSA authorization prompt, and run:

```powershell
cd "F:\AI Practice\fixmate-app"
flutter --version
flutter pub get
flutter devices
flutter run -d c57ddc760409 --debug
```

Interactive `flutter run` commands:

- `r`: hot reload source changes.
- `R`: hot restart and reconstruct application state.
- `d`: detach without stopping the installed application.
- `q`: stop the application and exit.

If the phone is missing, unlock it, reconnect USB, accept the authorization
prompt, select File transfer/Android Auto USB mode if necessary, then run
`adb devices` and `flutter doctor -v`. An `unauthorized` ADB entry must be fixed
on the phone before Flutter can run the app.

On Xiaomi/MIUI, installing a new debug APK can pause at a device-side **Install
via USB** confirmation. Unlock the phone and approve that prompt. MIUI may also
deny automated `adb shell input` taps with `INJECT_EVENTS`; this does not stop a
normal manual touch test.

## App Check during local development

App Check is disabled by default. Registered local debug builds can opt into
Firebase's Android debug provider. The direct-distribution release does not
activate a debug or release provider, and enforcement remains disabled. Never
hardcode or commit a debug token.

Start the registered debug build with:

```powershell
flutter run -d c57ddc760409 --debug --dart-define=FIXMATE_ENABLE_APP_CHECK=true
```

Copy the one-time debug token from local device logs directly into Firebase Console:
App Check → Apps → FixMate Android → Manage debug tokens. Treat the token like
a credential, keep it out of screenshots and terminal transcripts, and revoke
it when the development device is retired. Enforcement should stay disabled
until valid device traffic is confirmed.

## Validation commands

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
npm --prefix functions ci
npm --prefix functions test
npm --prefix functions run test:rules
```

The debug APK is written to
`build/app/outputs/flutter-apk/app-debug.apk`.

Known environment-only warnings can include an Android SDK XML tool-version
mismatch, third-party deprecated Java APIs, Impeller messages, or Xiaomi OpenGL
driver output. Investigate them separately; do not weaken application security
or release signing merely to silence vendor/tooling warnings.

On the M2003J15SC, Google Play services 26.28.33 logs a non-user-facing
`DEVELOPER_ERROR` from its internal `Phenotype.API` flag client, together with
`Unknown calling package name 'com.google.android.gms'`. The FixMate process
continued rendering and logged no fatal Android exception, Flutter exception,
or zone mismatch. FixMate does not include Google Sign-In, and its Firebase
project/package identities match, so this warning is not evidence of failed
FixMate credentials or navigation. Update the device's Google Play services or
MIUI system components when an update is available; do not change the
application ID or weaken App Check to suppress it.

## Manual provider regression flow

1. Register a new provider and verify its email.
2. Return to FixMate and press **I have verified my email**.
3. Complete and submit the provider application.
4. Confirm `provider_profiles/{uid}` is `pending` and hidden.
5. Confirm the app immediately shows **Application under review**.
6. Fully stop and reopen the app; confirm the review screen remains.
7. Confirm device logs contain no `Zone mismatch`.
8. Confirm no token or personal data was written into repository files.

Do not claim this manual flow passed unless the physical phone, authentication
account, Firebase connectivity, and resulting Firestore state were all
observed.
