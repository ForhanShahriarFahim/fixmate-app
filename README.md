# FixMate

[![CI](https://github.com/ForhanShahriarFahim/fixmate-app/actions/workflows/ci.yml/badge.svg)](https://github.com/ForhanShahriarFahim/fixmate-app/actions/workflows/ci.yml)
[![Android release](https://github.com/ForhanShahriarFahim/fixmate-app/actions/workflows/android-release.yml/badge.svg)](https://github.com/ForhanShahriarFahim/fixmate-app/actions/workflows/android-release.yml)
[![Latest release](https://img.shields.io/github/v/release/ForhanShahriarFahim/fixmate-app?display_name=tag&sort=semver)](https://github.com/ForhanShahriarFahim/fixmate-app/releases/latest)

FixMate is a Flutter marketplace for booking approved home-service providers
across Bangladesh. Customers can discover services, create bookings, chat after
acceptance, confirm cash payment, and submit verified reviews. Providers manage
their listings and booking workflow, while trusted administrators review
provider applications and service categories.

> **Release status:** Android beta preparation. FixMate is not yet presented as
> production-ready. Physical-device, FlutLab, signing, legal, App Check, and
> Google Play internal-testing checks remain release gates.

## Download Android builds

- **Stable signed APK:** [Download the latest FixMate APK](https://github.com/ForhanShahriarFahim/fixmate-app/releases/latest/download/fixmate-android.apk)
- **Development APKs:** open [GitHub Actions](https://github.com/ForhanShahriarFahim/fixmate-app/actions/workflows/ci.yml), select a successful run, and download its `fixmate-debug-<commit>` artifact.
- **Play upload bundle:** signed tag workflows retain the AAB in the workflow-run artifact. The public GitHub Release publishes APKs and checksums, not signing material.

The stable link becomes available after the first authorized version tag completes
the Android release workflow.

## First-release capabilities

### Customer

- Email/password registration, verification, login, reset, and account deletion request.
- Browse active services by category and Bangladesh coverage.
- Book a future date and fixed morning, afternoon, or evening window.
- Track an append-only booking timeline and in-app Activity history.
- Access contact details and text chat only after provider acceptance.
- Cancel eligible bookings, dispute completion, confirm cash payment, block/report users, and submit one review per completed booking.

### Provider

- Submit a provider profile for administrator approval.
- Manage multiple fixed-price service listings after approval.
- Accept/reject requests with deterministic date/window slot protection.
- Start work, request completion, communicate with customers, and track exact confirmed-cash earnings and booking statistics.
- View verified rating, review count, completed work, and customer review history.

### Administrator

- Trusted `admins/{uid}` membership with no public admin registration.
- Review, approve, and reject provider applications with protected audit fields.
- Add, edit, activate, deactivate, and safely delete unused service categories.
- Category deletion requires deactivation and is refused while any active or archived service references the category.

## Technology and architecture

| Area | Implementation |
|---|---|
| Client | Flutter 3.44.8, Dart 3.12.2, Material 3 |
| State and navigation | Riverpod without code generation, `go_router` |
| Backend | Firebase Authentication and Cloud Firestore on Spark |
| Client safeguards | Firebase App Check integration and Crashlytics initialization |
| Android identity | `com.fixmatebd.app` application ID and namespace |
| Firebase project | `fixmate-ce36d`, Firestore in `asia-south1` |
| Backend enforcement | Firestore Security Rules and transactional client writes |
| Test tooling | Flutter tests, TypeScript tests, Firestore Emulator Rules tests |
| CI/CD | GitHub Actions Android/web validation, APK artifacts, signed tag releases |

The Flutter application uses feature-focused screens with shared domain models,
Firebase repositories, Riverpod providers, and guarded routing. Privileged
marketplace fields are validated by Firestore Rules; the UI is never treated as
the security boundary.

Cloud Functions, Cloud Storage/image uploads, push notifications, and online
payments are deliberately outside the first Spark release. A Firebase-connected
web build is retained for FlutLab preview and browser regression testing; Android
remains the only release target. The HTML files under `docs/` are the legal
GitHub Pages site.

## Repository structure

```text
fixmate-app/
├── .github/workflows/       CI and signed Android release automation
├── android/                 Android runner and fail-closed release signing
├── assets/data/             Bangladesh division/district reference data
├── docs/                    Legal pages, runbooks, plans, and release evidence
├── functions/               Local seed tooling and Firestore Rules tests
├── lib/
│   ├── core/                Models, repositories, Firebase, routing, theme
│   └── features/            Auth, admin, catalog, booking, provider, shared UI
├── test/                    Flutter unit, widget, and navigation tests
├── web/                     Firebase-connected FlutLab web preview scaffold
├── firestore.rules          Marketplace authorization and data integrity
├── firestore.indexes.json   Eleven reviewed composite indexes
├── firebase.json            Emulator and Firebase CLI configuration
└── pubspec.yaml             Dart package and Android release version
```

## Local development

### Prerequisites

- Flutter 3.44.8 with Dart 3.12.2
- Android SDK and an Android device/emulator
- Java 21 for the Firestore Emulator
- Node.js 22 and npm for Firebase test tooling

### Set up and validate

```powershell
git clone https://github.com/ForhanShahriarFahim/fixmate-app.git
cd fixmate-app

flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

npm --prefix functions ci
npm --prefix functions test
npm --prefix functions run test:rules

flutter build web --debug
flutter build apk --debug
flutter run --debug
```

The debug APK is written to
`build/app/outputs/flutter-apk/app-debug.apk`. See
[Local Android development](docs/LOCAL_ANDROID_DEVELOPMENT.md) for device,
App Check, Xiaomi/MIUI, and troubleshooting details.

### Firebase client configuration

The tracked `android/app/google-services.json` and
`lib/core/firebase/firebase_options.dart` identify the public Firebase client.
They are not Firebase Admin credentials. Never commit a service-account key,
private key, App Check debug token, upload keystore, `key.properties`, password,
or signing secret.

Before using a different Firebase project, use the official FlutterFire workflow
and verify both the project ID and `com.fixmatebd.app`; never invent Firebase
configuration values.

## FlutLab

Import the repository root from GitHub, select the intended branch, and run Pub
Get. The Flutter project intentionally lives at the repository root and has no
local-path or Git dependencies. Firebase client files required by cloud Android
and web builds are tracked; Admin credentials and Android signing credentials
are not.

For browser preview, choose FlutLab's `web-emulator` builder, build the project,
and open Web Emulator. For Android, use a debug-capable builder/device for
development; FlutLab's release APK action will correctly stop until private
release signing is supplied outside the repository.

Use FlutLab for previews and development builds. Treat the signed GitHub tag
workflow and Google Play App Bundle as the controlled release path.

## Security model

- Marketplace writes require an authenticated, verified, active account.
- Customer/provider roles are immutable after registration.
- Provider visibility and service writes require administrator approval.
- Booking transitions validate actor, current state, related event writes, and slot locks.
- Contact details remain private until booking acceptance.
- Reviews require a completed booking and use the booking ID for uniqueness.
- Administrator access depends on an active `admins/{uid}` document, not an editable profile role or hardcoded email.
- Category deletion is administrator-only, inactive-only, and protected by an application-level service-reference check.

The publisher must verify ownership of `fixmatebd.support@gmail.com` before the
beta. After verification, report suspected vulnerabilities there instead of a
public issue. Never include credentials or personal customer data.

## CI, versioning, and releases

Pull requests and pushes to `main` run formatting, analysis, Flutter tests,
Firestore tooling tests, Rules emulator tests, web compilation, and a debug APK
build. Successful Flutter jobs retain a downloadable debug APK artifact for 14
days.

FixMate versions use Flutter's `MAJOR.MINOR.PATCH+BUILD` format in
`pubspec.yaml`. A release tag must match it exactly with a `v` prefix:

```text
pubspec.yaml: version: 1.0.0+1
Git tag:      v1.0.0+1
```

An authorized tag push validates the version, reruns every test, creates a
signed release APK and Play AAB, generates SHA-256 checksums, uploads the build
artifact, and creates or updates the matching GitHub Release. The workflow is
fail-closed if any Android signing secret is missing.

Follow [Android releases and versioning](docs/RELEASING.md) before creating a
tag. Release history is maintained in [CHANGELOG.md](CHANGELOG.md).

## Project documentation

- [Finalization plan and evidence](docs/FINALIZATION_PLAN.md)
- [Documentation plan](docs/DOCUMENTATION_PLAN.md)
- [Android releases and versioning](docs/RELEASING.md)
- [Administrator runbook](docs/ADMIN_RUNBOOK.md)
- [Local Android development](docs/LOCAL_ANDROID_DEVELOPMENT.md)
- [FlutLab readiness and settings](docs/FLUTLAB_READINESS.md)
- [Google Play checklist](PLAY_RELEASE_CHECKLIST.md)
- [Terms of Use](docs/terms.html)
- [Privacy Policy](docs/privacy.html)
- [Account deletion](docs/delete-account.html)

## Contribution workflow

1. Start from the latest `main` and create a focused feature branch.
2. Preserve unrelated work and never commit credentials or signing files.
3. Add tests for material behavior changes.
4. Run the complete validation suite locally.
5. Open a pull request and wait for required CI checks and review.
6. Never deploy Firebase resources, push a version tag, or publish a release without explicit authorization.

## Current release limitations

- Payment is confirmed cash only; no card or mobile-wallet gateway is connected.
- Activity is in-app history, not push notification delivery.
- Service images are built-in; uploads and Cloud Storage are deferred.
- App Check enforcement remains disabled until valid debug and Play traffic is verified.
- Account cleanup and complex moderation remain trusted operator procedures on Spark.
- Google Play internal testing, legal review, final signing, and full physical-device acceptance remain pending.

FixMate is a technical marketplace beta; repository documentation is not legal
advice. The publisher must review all policies and Play declarations before
distribution.
