# Changelog

All notable FixMate changes are recorded here. Versions follow
`MAJOR.MINOR.PATCH+BUILD` from `pubspec.yaml`; Git tags add a `v` prefix.

## Unreleased

### Added

- Safe administrator deletion for inactive, unused service categories.
- Downloadable debug APK artifacts on successful CI runs.
- Signed tag workflow for versioned APKs, a stable APK download, checksums, and
  a Play App Bundle artifact.
- Android release/versioning runbook and documentation maintenance plan.
- Firebase-connected web compilation in CI to protect FlutLab preview support.

### Changed

- Service-category cards now use a compact, accessible actions menu with clear
  active/inactive state and destructive-action guidance.
- README reorganized around product roles, architecture, setup, security,
  FlutLab, CI/CD, versioning, downloads, and release limitations.
- Release tags must match `pubspec.yaml` and point to a commit contained in
  `main` before signed artifacts can be built.

### Security

- Category deletion requires an active administrator and an inactive category;
  the application refuses deletion while any service still references its ID.
- Signed release builds remain fail-closed when private signing configuration is
  missing. No signing credential is stored in the repository.
- The reviewed category-deletion Rules are deployed and their live source was
  verified against the repository file.
