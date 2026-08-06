# FixMate finalization record

Last updated: 6 August 2026 (Asia/Dhaka)

This document is the living evidence record for the first FixMate Android
release. It distinguishes **coded**, **configured**, **deployed**, **published**,
and **manually verified** work.

## Fixed identity and scope

- Product: FixMate
- Repository: `ForhanShahriarFahim/fixmate-app`
- Dart package: `fixmate`
- Android application ID and namespace: `com.fixmatebd.app`
- Firebase project: `fixmate-ce36d` on the Spark plan
- Release platform: Android on physical devices
- Distribution: signed APK through GitHub Releases
- Current version: `1.0.0+1`; intended tag: `v1.0.0+1`

FlutLab, browser/iOS builds, Android App Bundles, and Google Play publication
are outside the current scope. Cloud Functions, Cloud Storage image upload,
online payment processing, and push notifications remain deferred.

## Verified application state

### Coded

- Email/password registration, email verification, login, password reset,
  immutable customer/provider selection, and safe configuration failure UI.
- Customer catalog, provider profiles, coverage selection, bookings, immutable
  price snapshots, booking timelines, cash completion, disputes, reviews,
  reporting, blocking, Activity history, and account-deletion requests.
- Provider application/approval gating, dashboard statistics, services,
  booking transitions, reputation, and recent activity.
- Administrator navigation, provider review, service-category create/edit/
  archive/delete behavior, moderation, and role membership via `admins/{uid}`.
- Material 3 Android UI with loading, empty, retry, validation, navigation, and
  permission/error states.
- Firebase Authentication, Firestore, Crashlytics, and optional development
  App Check initialization. App Check enforcement is disabled.

### Configured in the repository

- Android Firebase client identity points to `fixmate-ce36d` and
  `com.fixmatebd.app`.
- Firestore Security Rules, 11 composite indexes, and idempotent category seed
  tooling are versioned.
- Pull-request CI validates formatting, analysis, Flutter tests, Firestore
  emulator tests, and a debug Android APK.
- Tag workflow validates `v<pubspec-version>`, requires the commit on `main`,
  reconstructs private signing from the `android-release` Environment, builds
  a signed APK, creates checksums, and publishes GitHub Release assets.
- Release signing fails closed when `android/key.properties` or the private
  keystore is absent. No debug-signing fallback exists.

## Firebase deployment evidence

Stage 6B is complete for project `fixmate-ce36d`.

- Active Firestore Rules matched reviewed source SHA-256
  `6063EE1EBFF5FED0A2C37F6334506D600545A280EA5575CFF20D5FE8DAFA722B` at
  Stage 6B verification. A later narrowly authorized category-delete Rules
  update was deployed from reviewed SHA-256
  `912BF14253AA3EE4CB94179BCC235F0A6D56E83AD5332DC90E659C2B91E4AF83`.
- All 11 reviewed composite indexes were confirmed Enabled in Firebase Console.
- Exactly these six seed documents were verified, with no duplicates:
  `categories/electrical`, `categories/plumbing`, `categories/cleaning`,
  `categories/ac-repair`, `categories/appliance-repair`, and
  `categories/painting`.
- App Check enforcement remains disabled.
- Hosting, Storage, Functions, Authentication configuration, Remote Config,
  Cloud Messaging, and other unrelated Firebase resources were not deployed by
  Stage 6B or the category-delete Rules update.

Recovery: deploy a previously reviewed Rules revision only after authorization;
indexes can be resubmitted from `firestore.indexes.json`; category seeding is
idempotent and must never delete or overwrite unrelated documents. Firebase
rollback is independent of Android application release rollback.

## Security posture and known limits

- Direct client writes are constrained by Firestore Rules; sensitive state
  transitions and marketplace integrity are enforced within the reviewed
  Spark/client architecture.
- Privileged Admin SDK code is not used by the Android app. Firebase client
  identifiers are not service-account credentials.
- Private signing material, `key.properties`, Admin keys, passwords, tokens,
  and App Check debug tokens must never enter Git, logs, release assets, or
  documentation.
- A Spark/client-only design cannot provide the same trusted transaction and
  notification guarantees as callable backend functions. Deferred workflows
  must not be represented as implemented.
- App Check can be enabled for registered local debug testing only. The GitHub
  APK does not activate a debug provider and enforcement remains disabled.

## Release acceptance criteria

### Automated

- `flutter pub get` passes.
- `dart format --output=none --set-exit-if-changed lib test` passes.
- `flutter analyze` passes.
- All Flutter tests pass.
- Functions package lint/unit and Firestore emulator Rules tests pass.
- `flutter build apk --debug` passes.
- Workflow YAML and permissions are reviewed.
- Targeted secret scan finds no private key, keystore, password, token, Admin
  credential, or App Check debug token.
- PR CI and post-merge `main` CI pass.
- Tag workflow produces a signed release APK and matching checksums.

### Manual Android checks

- Install and launch the GitHub-downloaded APK on a physical Android device.
- Verify registration and email verification, customer discovery/booking/
  activity/review, provider approval/dashboard/service/booking/reputation, and
  admin category/provider/moderation flows.
- Verify back navigation from profile-missing and booking-detail screens.
- Verify offline/retry, expired authentication, rejected/pending provider,
  permission-denied, keyboard, text scaling, and common portrait layouts.
- Confirm the public APK package, version, checksum, and certificate fingerprint.

Manual checks are recorded as pending until the device and the published APK
are actually observed; automated success must not be described as a device pass.

## Release execution record

| Gate | Status | Evidence |
|---|---|---|
| Marketplace implementation PR | Coded | Branch `codex/finalize-release-readiness`, PR #7 |
| Previous PR CI | Passed | GitHub Actions run `31114221113` |
| Android-only conversion | Coded | Web/iOS/FlutLab and Play/AAB paths removed in current branch diff |
| Current local validation | Passed | Formatting, analysis, 45 Flutter tests, 5 tooling unit tests, 30 Rules tests, and debug APK on 6 August 2026 |
| Current PR CI | Pending updated commit | Must pass before merge |
| Private release signing | Pending | Must be generated and backed up outside repository |
| GitHub Environment secrets | Pending | `android-release` only; values must not be printed |
| Merge to `main` | Pending | Requires green PR CI |
| Tag and GitHub Release | Pending | `v1.0.0+1` after green `main` |
| Published APK verification | Pending | Checksum, package, version, certificate, download |
| Physical-device release test | Pending | User device must be connected/available |

The verified debug APK is
`build/app/outputs/flutter-apk/app-debug.apk` (package `com.fixmatebd.app`,
version `1.0.0+1`). No Android device was connected during this validation, so
`flutter run` and physical-device acceptance remain pending.

The Firebase test/seed toolchain was updated to current reviewed versions. A
non-forced `npm audit fix` removed every high-severity finding. Nine moderate
transitive advisories remain in Firebase CLI/Admin dependencies; npm proposes a
forced direct-tool downgrade rather than a safe upgrade. These packages run
only in operator/CI tooling and are not included in the Android APK. Reassess
them when upstream Firebase packages publish corrected dependency ranges.

## Exact implementation order

1. Finish Android-only source, CI, and documentation cleanup.
2. Run formatting, analysis, Flutter tests, Firestore tests, debug APK build,
   workflow review, diff review, and secret scan.
3. Commit and push the intentional update to existing PR #7; update its scope.
4. Wait for PR CI and fix only verified in-scope failures.
5. Generate and encrypt a private signing backup outside the repository; verify
   a local signed APK without exposing credentials.
6. Configure the `android-release` Environment secrets.
7. Mark PR #7 ready and merge only after all required checks are green.
8. Verify `main` CI, create and push `v1.0.0+1`, then wait for release CI.
9. Download and verify the GitHub Release APK and checksums.
10. Complete and record the remaining physical-device checks.
