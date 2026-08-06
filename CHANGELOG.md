# Changelog

All notable FixMate changes are recorded here. Versions follow
`MAJOR.MINOR.PATCH+BUILD` from `pubspec.yaml`; Git tags add a `v` prefix.

## 1.0.0+1 — 2026-08-06

### Added

- Customer, provider, and trusted administrator Android workflows.
- Provider approval and service-category management.
- Safe deletion for inactive categories not referenced by a service.
- Provider reputation, confirmed-cash analytics, review history, and in-app
  Activity unread state.
- Downloadable debug APK artifacts for successful CI runs.
- Signed GitHub Release workflow with stable/versioned APKs and checksums.
- Android development, administrator, release, and operational documentation.

### Changed

- Hardened authentication/profile recovery, provider onboarding, booking return
  navigation, loading/error states, and duplicate-submission prevention.
- Replaced unreliable aggregate calls with bounded paginated reads.
- Standardized category management UI, BDT/date presentation, review cards,
  accessibility labels, and Android layouts.
- Limited the repository and release pipeline to Android only.
- Updated the Firebase test and seed toolchain and removed all high-severity
  npm audit findings without a forced dependency downgrade.

### Security

- Marketplace writes require verified active accounts and protected role/state
  transitions.
- Category deletion requires an active administrator and inactive category;
  referenced categories cannot be deleted.
- Release signing fails closed and private signing material is never committed.
- The reviewed Firestore Rules are deployed and live-source verified against
  the repository file.
- Nine moderate transitive advisories remain in Firebase CLI/Admin tooling;
  those operator/test packages are not bundled in the Android APK.
