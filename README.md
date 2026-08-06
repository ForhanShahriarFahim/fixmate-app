# FixMate

[![CI](https://github.com/ForhanShahriarFahim/fixmate-app/actions/workflows/ci.yml/badge.svg)](https://github.com/ForhanShahriarFahim/fixmate-app/actions/workflows/ci.yml)
[![Android release](https://github.com/ForhanShahriarFahim/fixmate-app/actions/workflows/android-release.yml/badge.svg)](https://github.com/ForhanShahriarFahim/fixmate-app/actions/workflows/android-release.yml)
[![Latest release](https://img.shields.io/github/v/release/ForhanShahriarFahim/fixmate-app?display_name=tag&sort=semver)](https://github.com/ForhanShahriarFahim/fixmate-app/releases/latest)

FixMate is an Android home-service marketplace for Bangladesh, built with
Flutter and Firebase Spark. Customers find approved providers and book fixed
price services; providers manage listings and jobs; trusted administrators
review provider applications and service categories.

Android is the only supported application platform. Development and manual
testing use a connected Android phone. Distribution uses signed APK files from
GitHub Releases.

## Download

- **Latest signed APK:** [Download FixMate for Android](https://github.com/ForhanShahriarFahim/fixmate-app/releases/latest/download/fixmate-android.apk)
- **All versions:** [GitHub Releases](https://github.com/ForhanShahriarFahim/fixmate-app/releases)
- **Development APK:** open a successful [CI run](https://github.com/ForhanShahriarFahim/fixmate-app/actions/workflows/ci.yml) and download its `fixmate-debug-<commit>` artifact.

The stable APK link becomes active when the first authorized version tag
finishes the Android release workflow.

## Features

### Customer

- Email/password registration, verification, login, reset, and deletion request.
- Browse active services by category and Bangladesh coverage.
- Book a future date and morning, afternoon, or evening window.
- Track status and immutable booking-event history.
- See contact details and use text chat only after provider acceptance.
- Cancel eligible bookings, dispute completion, confirm cash payment, block or
  report users, and leave one verified review per completed booking.

### Provider

- Submit a profile for administrator approval.
- Create and manage fixed-price services after approval.
- Accept or reject requests with date/window slot-conflict protection.
- Start work, request completion, communicate with customers, and track
  confirmed-cash earnings and booking statistics.
- View completed work, verified ratings, and customer review history.

### Administrator

- Sign in through a trusted `admins/{uid}` Firestore membership; there is no
  public administrator registration.
- Review, approve, and reject provider applications with protected audit data.
- Add, edit, activate, deactivate, and safely delete unused categories.
- Category deletion requires deactivation and is blocked while any service
  references the category.

## Technology

| Area | Implementation |
|---|---|
| Client | Flutter 3.44.8, Dart 3.12.2, Material 3 |
| State/navigation | Riverpod without generation, `go_router` |
| Backend | Firebase Authentication and Cloud Firestore on Spark |
| Diagnostics | Crashlytics; optional debug App Check monitoring |
| Android identity | `com.fixmatebd.app` |
| Firebase project | `fixmate-ce36d`, Firestore `asia-south1` |
| Integrity | Firestore Security Rules and transactional client writes |
| Automation | GitHub Actions validation, APK artifacts, signed releases |

Cloud Functions, Cloud Storage uploads, push notifications, and online payment
gateways are deliberately outside this release. Activity is stored in-app, and
payments are recorded as confirmed cash only.

## Repository structure

```text
fixmate-app/
├── .github/workflows/       CI and signed GitHub Release automation
├── android/                 Android runner and fail-closed release signing
├── assets/data/             Bangladesh division/district reference data
├── docs/                    Legal pages, runbooks, and release evidence
├── functions/               Local seed tooling and Firestore Rules tests
├── lib/
│   ├── core/                Models, repositories, Firebase, routing, theme
│   └── features/            Auth, admin, catalog, booking, provider, shared UI
├── test/                    Unit, widget, repository, and navigation tests
├── firestore.rules          Marketplace authorization and data integrity
├── firestore.indexes.json   Eleven reviewed composite indexes
├── firebase.json            Android Firebase and emulator configuration
└── pubspec.yaml             Dart package and release version
```

## Local Android development

### Requirements

- Flutter 3.44.8 with Dart 3.12.2
- Android SDK and an Android phone with USB debugging enabled
- Java 21 for the Firestore Emulator
- Node.js 22.12 or newer within the Node 22 line, plus npm, for Firebase
  tooling tests

### Validate and run

```powershell
git clone https://github.com/ForhanShahriarFahim/fixmate-app.git
cd fixmate-app

flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions test
npm --prefix functions run test:rules

flutter build apk --debug
flutter devices
flutter run -d <ANDROID_DEVICE_ID> --debug
```

The debug APK is written to
`build/app/outputs/flutter-apk/app-debug.apk`. See
[local Android development](docs/LOCAL_ANDROID_DEVELOPMENT.md) for device and
troubleshooting guidance.

## Firebase configuration

The tracked `android/app/google-services.json` and
`lib/core/firebase/firebase_options.dart` identify the public Android Firebase
client. They are not Firebase Admin credentials. The application validates the
expected project and Android app identity before initialization and shows a safe
configuration screen if they do not match.

Never commit a service-account key, private key, App Check debug token, release
keystore, `key.properties`, password, or signing secret. Firebase client API
keys are identifiers rather than backend authorization; Firestore Rules enforce
data access. Review appropriate API/application restrictions before resolving
repository secret-scanning alerts.

## Security model

- Marketplace writes require an authenticated, verified, active account.
- Customer/provider roles are immutable after registration.
- Provider visibility and service writes require administrator approval.
- Booking transitions validate actor, state, event writes, and slot locks.
- Full address and contact data remain private until booking acceptance.
- Reviews require a completed booking and use the booking ID for uniqueness.
- Admin access depends on an active `admins/{uid}` document, never an email or
  editable user role.
- Category deletion is admin-only, inactive-only, and protected by a service
  reference check.

## CI, versioning, and GitHub Releases

Pull requests and pushes to `main` run formatting, analysis, Flutter tests,
Firestore tooling tests, Rules emulator tests, and a debug APK build. Successful
CI runs retain a downloadable debug APK for 14 days.

Versions use Flutter's `MAJOR.MINOR.PATCH+BUILD` format. A release tag must match
the value in `pubspec.yaml` exactly with a `v` prefix:

```text
pubspec.yaml: version: 1.0.0+1
Git tag:      v1.0.0+1
```

An authorized tag must point to a commit contained in `main`. The release
workflow reruns all checks, reconstructs private signing from protected GitHub
Environment secrets, creates a signed stable APK plus a versioned APK, writes
SHA-256 checksums, and publishes them to GitHub Releases. Signing fails closed
if any required secret is unavailable.

Follow [GitHub Android releases and versioning](docs/RELEASING.md) before
creating a tag. User-visible history is maintained in [CHANGELOG.md](CHANGELOG.md).

## Documentation

- [Finalization status and evidence](docs/FINALIZATION_PLAN.md)
- [Documentation maintenance plan](docs/DOCUMENTATION_PLAN.md)
- [GitHub Android releases and versioning](docs/RELEASING.md)
- [Administrator runbook](docs/ADMIN_RUNBOOK.md)
- [Local Android development](docs/LOCAL_ANDROID_DEVELOPMENT.md)
- [Terms of Use](docs/terms.html)
- [Privacy Policy](docs/privacy.html)
- [Account deletion](docs/delete-account.html)

## Current limitations

- Online payment gateways are not connected; completion records cash payment.
- Notifications are in-app Activity history, not push delivery.
- Images are built-in; user uploads and Cloud Storage are deferred.
- App Check enforcement remains disabled while direct-release behavior is
  evaluated. Debug tokens must never be committed.
- Account cleanup and complex moderation remain trusted operator procedures on
  the Spark plan.
- Legal text and the public support mailbox require publisher review.

FixMate is an Android marketplace beta. Repository documentation is technical
guidance and not legal advice.
