# FixMate FlutLab readiness

Last verified: 5 August 2026 (Asia/Dhaka)

## Current build status

The repository root is a complete Flutter project and can be imported directly
into FlutLab. The Android identity is fixed and verified:

- Product label: `FixMate`
- Dart package: `fixmate`
- Android application ID and namespace: `com.fixmatebd.app`
- Flutter: `3.41.6`
- Dart: `3.11.4`
- Android minimum SDK: Flutter 3.41 default (`24`)
- Android compile SDK: Flutter 3.41 default (`36`)
- Android Gradle Plugin: `8.11.1`
- Gradle: `8.14`
- Kotlin Gradle Plugin: `2.2.20`

The verified local command `flutter build apk --debug` produced
`build/app/outputs/flutter-apk/app-debug.apk` with the real Android client
configuration for Firebase project `fixmate-ce36d`. Successful Firebase
initialization enters the authentication flow; a wrong/missing project identity
or initialization failure still shows a safe setup-required screen.

The merged `main` branch was also imported successfully into FlutLab on
5 August 2026 after adding the standard `ios/` recognition scaffold. FlutLab's
available Flutter 3.41 builder resolved to Flutter `3.41.7`; dependency
resolution and all 15 Flutter tests passed there. The account's Android APK
builder invokes `assembleRelease`, so the unsigned cloud build stopped at the
repository's intentional release-signing guard. The available Hot Reload action
was web-only and no Android emulator or device was connected, so an Android
debug run and startup verification remain manual.

## Recommended FlutLab import settings

1. Import the public GitHub repository `fixmate-app`; select the repository
   root, not `android/` or another subdirectory.
   FlutLab requires the standard `ios/` scaffold to recognize an imported
   Flutter project even when only Android is being built. The scaffold is
   retained for import compatibility; iOS is not configured or in release
   scope.
2. Select Android as the target and Flutter `3.41.6` / Dart `3.11.4`. Do not
   allow an automatic dependency or Flutter upgrade during the first build.
3. Run **Pub Get** and keep the committed `pubspec.lock`.
4. Build an Android debug APK first. Java 17 or 21 is compatible with this
   repository's Gradle configuration.
5. Do not add web or iOS Firebase/release configuration, image uploads,
   Functions, Storage, or push notifications for this release.

There are no local path or Git package dependencies. The Android build disables
Kotlin incremental compilation so Windows/cloud builds remain reliable when
the Pub cache and repository are mounted on different drives.

## Firebase connection and remaining Console work

Completed in the repository:

1. Verified project `fixmate-ce36d` and Android package `com.fixmatebd.app`.
2. Ran the official Android-only FlutterFire configuration against the existing
   app registration.
3. Generated `lib/core/firebase/firebase_options.dart`, copied the matching
   `android/app/google-services.json`, and added Google Services/Crashlytics
   Gradle plugins.
4. Added runtime project/app identity validation and retained the safe failure
   screen.
5. Deployed and verified the reviewed Firestore Rules, seeded exactly the six
   reviewed category documents, and confirmed all 11 composite indexes are
   Enabled/`READY`. App Check enforcement remains disabled.

The two client configuration files are intentionally included in the
repository so GitHub Actions and a clean FlutLab import receive identical
Android configuration. They contain non-secret client identifiers. Never use
or commit an Admin service-account JSON file in their place.

Remaining manual work:

1. Confirm Email/Password Authentication is enabled in Firebase Console.
2. Verify customer and provider Authentication/Firestore workflows on a
   physical Android device without writing uncontrolled production test data.
3. Register App Check for the Android app. Keep enforcement off during initial
   internal testing, never commit a debug token, and enable enforcement only
   after genuine device traffic is verified.
4. Send and verify one deliberate Crashlytics test event from a test device.
5. Approve providers with both `approvalStatus: approved` and
   `marketplaceVisible: true`; follow `docs/ADMIN_RUNBOOK.md` for suspension,
   reports, disputes, and deletion requests.

## Verified automated checks

| Check | Result |
|---|---|
| `flutter pub get` | Pass |
| Dart formatting verification | Pass; 29 files checked, 0 changes |
| `flutter analyze` | Pass; no issues |
| `flutter test` | Pass; 15 tests |
| `npm run lint` | Pass |
| `npm test` | Pass; 5 local tooling tests, emulator tests skipped as designed |
| `npm run test:rules` | Pass; 24/24 emulator cases |
| `flutter build apk --debug` | Pass; Firebase-connected 174,897,108-byte APK |
| FlutLab Flutter 3.41.7 `pub get` | Pass |
| FlutLab Flutter tests | Pass; 15 tests |
| FlutLab `android-all` build | Expected signing stop; FlutLab invoked `assembleRelease`, and release signing remains fail-closed |

## Remaining blockers before Play internal testing

- Firebase Android client configuration is complete; FlutLab imported the
  project and passed dependency resolution/tests, but no Android debug device
  was available to verify startup, Authentication, App Check, or Crashlytics.
- FlutLab's current cloud Android APK action invokes a release build. A debug
  run requires a connected supported Android device/environment; do not bypass
  the release-signing guard or upload signing material merely to obtain a debug
  test build.
- Firestore Rules, all 11 indexes, and the six reviewed category documents are
  deployed; their customer/provider behavior still requires device verification.
- GitHub Pages legal files are coded but not published or legally reviewed.
- Release builds fail closed when private upload signing is absent or
  incomplete; they never fall back to the debug key. Supply a private upload
  keystore and `key.properties` through a secure, untracked mechanism before
  building an AAB for Play.
- Small/medium/large physical Android devices, keyboard behavior, text scaling,
  TalkBack, phone/mail links, offline recovery, App Check, and Crashlytics still
  require manual verification.

Never upload a service-account key, Firebase Admin credential, App Check debug
token, upload keystore, `key.properties`, password, or signing secret to GitHub
or FlutLab.
