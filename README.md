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
aggregates. Account deletion performs client-side cleanup and retains only a
pseudonymous deletion marker and moderation identifiers for manual security
handling.

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

## 1. Create a no-cost Firebase project

1. Create `fixmatebd-app-2026` (fallback `fixmatebd-app-2026-bd`).
2. Keep the project on the **Spark** plan. Do not attach a billing account.
3. Enable Email/Password in Authentication.
4. Create the one free Firestore database in `asia-south1` Mumbai using
   Production mode.
5. Register Android package `com.fixmatebd.app` and download
   `google-services.json`.
6. Enable Crashlytics and register App Check. Keep App Check enforcement off
   until genuine debug/internal-test traffic has been verified.

Do not enable Cloud Functions or Cloud Storage. The `storageBucket` value in a
generated Firebase options file is harmless client metadata; the app does not
call Firebase Storage.

## 2. Connect Firebase in FlutLab

1. Import the GitHub repository root.
2. Select **Connect to Firebase → Android** and upload
   `google-services.json`.
3. Copy FlutLab's generated `lib/firebase_options.dart` over
   `lib/core/firebase/firebase_options.dart`, then remove the extra generated
   file.
4. Confirm no `REPLACE_WITH` placeholders remain.
5. Run **Pub get** using Flutter 3.44.6 / Dart 3.12 or a newer compatible
   builder.

FixMate already initializes Firebase, App Check, and Crashlytics in `main.dart`.
Do not replace it with a tutorial initialization snippet.

## 3. Deploy only Firestore configuration

Install Firebase CLI, then run from the repository root:

```console
firebase login
firebase use --add
firebase deploy --only firestore:rules,firestore:indexes
```

This deploy does not require Blaze. A manual GitHub Actions workflow is also
included, but only use it after configuring its Workload Identity variables.

## 4. Seed the six categories

The `functions/` directory is local tooling and is not a deployable Functions
backend:

```console
cd functions
npm ci
npm test
gcloud auth application-default login
npm run seed -- --project fixmatebd-app-2026
```

The seed creates electrical, plumbing, cleaning, AC repair, appliance repair,
and painting categories. Change the project ID when using the fallback.

## 5. Approve a provider

1. Register a provider and verify the email.
2. Complete the provider application.
3. Open Firestore → `provider_profiles/{uid}`.
4. Verify the supplied details and change `approvalStatus` from `pending` to
   `approved`.
5. To suspend an account, update `users/{uid}.status` to `suspended` through
   Firebase Console.

See [ADMIN_RUNBOOK.md](ADMIN_RUNBOOK.md) for moderation, disputes, and deletion
handling.

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
flutter build apk
```

For Play upload, add `android/key.properties` and a private upload keystore
through a secure local/FlutLab mechanism. Those files are intentionally ignored.

## Legal URLs

Application constants currently use `https://fixmatebd.github.io/fixmate-app/`.
If the GitHub Pages owner differs, update
`lib/core/constants/app_constants.dart` before release. Reserve
`fixmatebd.support@gmail.com` before publishing.
