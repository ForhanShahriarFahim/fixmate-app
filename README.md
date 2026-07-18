# FixMate

FixMate is a Flutter/Firebase Android marketplace for booking approved home-service providers across Bangladesh. The repository is structured for direct GitHub import into [FlutLab](https://flutlab.io/).

## Implemented beta

- Customer/provider email accounts with verification, immutable roles, adult and Terms acceptance.
- Provider application, Firebase Console approval, nationwide district coverage, and up to ten service areas.
- Public categories and service listings with fixed BDT prices and optional cover images.
- Transactional booking lifecycle with three Dhaka time windows and provider conflict prevention.
- Private contact release after acceptance, calls, text-only booking chat, blocks, and reports.
- In-app and FCM notifications, cash completion confirmation, disputes, reviews, and rating aggregation.
- Firestore/Storage Rules, indexes, callable Functions, deletion cleanup, emulator tests, CI/CD, legal pages, and Play beta checklist.

## Repository layout

```text
android/              Android package com.fixmatebd.app
assets/               Bangladesh division/district data
lib/                  Flutter application
functions/            TypeScript Firebase backend (Node 22)
test/                 Flutter tests
docs/                 GitHub Pages legal site
firestore.rules        Client data-access policy
storage.rules          Image access and size/type policy
```

## 1. Create and configure Firebase

1. Create `fixmatebd-app-2026` (fallback `fixmatebd-app-2026-bd`) and upgrade it to Blaze. Add budget alerts.
2. Create Firestore in `asia-south1` Mumbai and create the default Storage bucket in the same region.
3. Enable Email/Password in Authentication.
4. Register Android package `com.fixmatebd.app` and download `google-services.json`.
5. In FlutLab, import this repository, select **Connect to Firebase → Android**, and upload `google-services.json`. FlutLab will add the required Android Google Services configuration.
6. Replace the placeholders in `lib/core/firebase/firebase_options.dart` with the generated FlutterFire/FlutLab values.
7. Enable Cloud Messaging, Crashlytics, and App Check. Use App Check monitoring during internal testing; enforce Play Integrity only after genuine-device traffic is verified.

The app deliberately shows a setup screen instead of crashing while Firebase values are placeholders. Never commit a service-account key. After creating the beta project, commit the generated Firebase **client** configuration because FlutLab and Android require it; authorization is enforced by Rules and Functions.

## 2. Deploy backend and seed categories

Install Node.js 22 and Firebase CLI, then:

```console
cd functions
npm ci
npm test
cd ..
firebase login
firebase use --add
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
gcloud auth application-default login
cd functions
npm run seed -- --project fixmatebd-app-2026
```

The seed script uses Google Application Default Credentials and creates electrical, plumbing, cleaning, AC repair, appliance repair, and painting categories. Firebase CLI login is used for deployment; the one-time local seed additionally needs `gcloud auth application-default login`.

All callable and Firestore triggers are Gen 2 in `asia-south1`. Firebase Authentication deletion events are still Gen 1 only, so `cleanupDeletedAuthUser` is the documented exception in `asia-east2`.

## 3. Approve a provider

1. Register a provider in the app and verify the email.
2. Complete the provider application.
3. Open Firestore → `provider_profiles/{uid}`.
4. Verify the profile and phone, then change `approvalStatus` from `pending` to `approved`.
5. To suspend any account, update `users/{uid}.status` to `suspended` in Firebase Console.

See [ADMIN_RUNBOOK.md](ADMIN_RUNBOOK.md) for reports, disputes, deletion requests, and moderation.

## 4. Import and build in FlutLab

1. Push this repository to GitHub as `fixmate-app`.
2. In FlutLab choose **Import from GitHub** and select the repository root.
3. Select Flutter **3.44.6 / Dart 3.12**. If FlutLab labels builders differently, choose its newest builder with Dart 3.12 or later and do not upgrade package versions.
4. Connect Firebase as described above and run **Pub get**.
5. Run the analyzer, launch the Android preview/device build, then build an APK or AAB.
6. Commit the generated `pubspec.lock`, final `firebase_options.dart`, Android Firebase changes, and `google-services.json` back to GitHub.

The repository and lockfile were verified with Flutter 3.44.6 / Dart 3.12.2. This workstation has no Android SDK, so the final APK/AAB build remains a required FlutLab check.

## GitHub Actions

- `ci.yml` analyzes/tests Flutter, compiles/tests Functions, and runs Firestore Rules tests in the emulator.
- `deploy-firebase.yml` deploys on `main` using Workload Identity Federation.
- `pages.yml` publishes the legal site.

Configure the GitHub `beta` environment variables:

- `GCP_PROJECT_ID`
- `WIF_PROVIDER`
- `DEPLOY_SERVICE_ACCOUNT`

Restrict the Workload Identity provider to the exact repository and `refs/heads/main`. Grant the deployment service account only the Firebase/Cloud Functions roles required by `firebase deploy`.

## Legal URLs

The application constants currently use `https://fixmatebd.github.io/fixmate-app/`. If the GitHub owner differs, update `lib/core/constants/app_constants.dart` before release. Reserve `fixmatebd.support@gmail.com` before publishing.

## Verification

Completed locally during implementation:

- `flutter analyze`: no issues.
- `flutter test`: all tests passed.
- TypeScript compile/state tests: passed.
- Firestore Rules emulator tests: all tests passed.

`npm audit --omit=dev` currently reports the upstream `uuid` moderate advisory through the latest tested `firebase-admin` dependency chain. npm offers only a forced downgrade to `firebase-admin` 10.3.0, so that breaking and outdated change was not applied. Recheck the pinned Admin SDK before beta promotion.

```console
cd functions
npm test
npm run test:rules
```

In an environment with Flutter:

```console
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build appbundle
```

For Play upload, add `android/key.properties` and a private upload keystore through a secure local/FlutLab mechanism. Those files are intentionally ignored; without them, local release builds use debug signing only for test installation.
