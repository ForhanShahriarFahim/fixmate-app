# FixMate — Firebase Spark Edition

FixMate is a Flutter Android marketplace for booking approved home-service
providers across Bangladesh. This edition is intentionally designed for the
no-cost Firebase **Spark** plan and direct GitHub import into
[FlutLab](https://flutlab.io/).

## Included beta functionality

- Customer/provider email accounts, verification, immutable roles, adult and
  Terms acceptance.
- Provider applications with Firebase Console approval and up to ten service
  areas.
- Text-only service listings with fixed BDT prices and built-in category art.
- Firestore-transaction booking lifecycle with deterministic provider slot
  locks.
- Contact privacy, calls after acceptance, real-time text chat, blocks, and
  reports.
- Cash completion, disputes, one review per booking, and dynamically calculated
  reputation statistics.
- Booking/message activity inside the app, App Check, Crashlytics, Firestore
  Rules, indexes, emulator tests, legal pages, and a Play beta checklist.

## Spark plan limitations

No billing account or Blaze upgrade is required. This edition deliberately
does not use Cloud Functions or Cloud Storage, so it does not include uploaded
avatars/service covers, Android push delivery, scheduled jobs, or trigger-based
aggregates. Account deletion creates one atomic, idempotent request and locks
the account; an authorized administrator then performs the documented,
restartable cleanup in Firebase Console. The client never claims that a
request is already completed.

Firestore Security Rules are the authoritative backend validator. Every
booking status change includes a matching append-only event, and accepting a
booking atomically creates a unique `provider_slots` lock.

## Repository layout

```text
android/                 Android package com.fixmatebd.app
assets/                  Bangladesh division/district data
lib/                     Flutter application
functions/               Local seed and Firestore Rules test tooling only
test/                    Flutter tests
docs/                    GitHub Pages legal site
firestore.rules          Spark marketplace authorization policy
firestore.indexes.json   Required Firestore indexes
```

## 1. Connected no-cost Firebase project

FixMate is configured for Firebase project `fixmate-ce36d` on the **Spark**
plan. The registered Android package is `com.fixmatebd.app`, and Firestore was
created in `asia-south1` Mumbai. The official FlutterFire workflow generated
the Android client configuration and added the required Google Services and
Crashlytics Gradle plugins.

Still complete or verify in Firebase Console:

1. Enable Email/Password in Authentication.
2. Register the Android app for App Check. Keep enforcement off until genuine
   debug/internal-test traffic has been verified.
3. Verify Crashlytics with a deliberate non-fatal event from a test device.

Do not enable Cloud Functions or Cloud Storage. The `storageBucket` value in a
generated Firebase options file is harmless client metadata; the app does not
call Firebase Storage.

## 2. Use Firebase in FlutLab

1. Import the GitHub repository root.
2. Confirm that `android/app/google-services.json` and
   `lib/core/firebase/firebase_options.dart` are present after import. These
   are non-secret Firebase client identifiers, not Admin credentials.
3. Do not create a second Firebase app or replace the generated configuration
   with values from another project.
4. Run **Pub get** using the FlutLab-compatible pinned builder: Flutter
   3.41.6 / Dart 3.11.4.

FixMate already initializes Firebase, App Check, and Crashlytics in `main.dart`.
Do not replace it with a tutorial initialization snippet.

## 3. Deploy only Firestore configuration

Install Firebase CLI, then run from the repository root:

```console
firebase login
firebase projects:list
npm --prefix functions run test:rules
firebase deploy --project fixmate-ce36d --only firestore:rules
firebase deploy --project fixmate-ce36d --only firestore:indexes
```

This deploy does not require Blaze. The repository intentionally has no
`.firebaserc`, so every operator command must name `fixmate-ce36d` explicitly.
The GitHub Actions workflow validates the repository but does not deploy it.

## 4. Seed the six categories

The `functions/` directory is local tooling and is not a deployable Functions
backend:

```console
cd functions
npm ci
npm test
gcloud auth application-default login
npm run seed -- --project fixmate-ce36d
gcloud auth application-default revoke
```

The seed creates electrical, plumbing, cleaning, AC repair, appliance repair,
and painting categories with stable document IDs. It uses operator user
Application Default Credentials; never substitute a downloaded service-account
key. Obtain separate approval before running the seed against Firebase.

## 5. Approve a provider

1. Register a provider and verify the email.
2. Complete the provider application.
3. Open Firestore → `provider_profiles/{uid}`.
4. Verify the supplied details and change `approvalStatus` from `pending` to
   `approved`, then set `marketplaceVisible` to `true`.
5. To suspend an account, first set `marketplaceVisible` to `false`, then
   update `users/{uid}.status` to `suspended` through Firebase Console.

See [docs/ADMIN_RUNBOOK.md](docs/ADMIN_RUNBOOK.md) for moderation, disputes,
and deletion handling.

## Verification

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
flutter build apk --debug
```

For Play upload, add `android/key.properties` and a private upload keystore
through a secure local/FlutLab mechanism. Those files are intentionally ignored.

## Legal URLs

Application constants use
`https://forhanshahriarfahim.github.io/fixmate-app/`, matching the configured
GitHub repository owner. Reserve `fixmatebd.support@gmail.com` and manually
verify every published link before internal testing.
