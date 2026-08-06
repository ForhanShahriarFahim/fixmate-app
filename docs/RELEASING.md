# FixMate Android releases and versioning

This runbook defines the controlled path from an approved `main` commit to a
signed Android APK published on GitHub Releases. Google Play publishing and
Android App Bundles are outside the current release scope.

## Version format

`pubspec.yaml` is the single source of truth:

```yaml
version: MAJOR.MINOR.PATCH+BUILD
```

- Increment **MAJOR** for incompatible product or data changes.
- Increment **MINOR** for backward-compatible features.
- Increment **PATCH** for backward-compatible fixes.
- Increment **BUILD** whenever a new Android artifact is published.

The Git tag must exactly equal the pubspec version with a `v` prefix. For
`version: 1.0.0+1`, use `v1.0.0+1`. Never move, replace, or force-push a release
tag.

## Private signing and GitHub configuration

Create an `android-release` GitHub Environment and store these Environment
secrets:

| Secret | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded private release keystore |
| `ANDROID_KEY_ALIAS` | Release-key alias |
| `ANDROID_KEY_PASSWORD` | Release-key password |
| `ANDROID_STORE_PASSWORD` | Keystore password |

Generate and back up the keystore outside the repository. Never commit or
upload the raw keystore, `android/key.properties`, a password, an App Check
debug token, or an Admin/service-account credential. The release workflow
reconstructs temporary signing files on the runner and deletes them in an
`always()` cleanup step.

The validation job has read-only repository permission. Only the publication
job receives the short-lived `contents: write` permission required to create
the GitHub Release.

## Release preparation

1. Confirm the release scope and update `CHANGELOG.md`.
2. Update `version:` in `pubspec.yaml`; always increase the build number.
3. Review README, legal pages, runbooks, and known limitations.
4. Run:

   ```powershell
   flutter pub get
   dart format --output=none --set-exit-if-changed lib test
   flutter analyze
   flutter test
   npm --prefix functions ci
   npm --prefix functions test
   npm --prefix functions run test:rules
   flutter build apk --debug
   git diff --check
   ```

5. Complete customer, provider, administrator, and offline/retry checks on a
   physical Android device.
6. Merge the reviewed pull request to `main` only after CI passes.
7. Verify local `main` is clean and exactly matches `origin/main`.

## Create a release

Example for `version: 1.0.0+1`:

```powershell
git switch main
git pull --ff-only origin main
git tag -a "v1.0.0+1" -m "FixMate 1.0.0 build 1"
git push origin "v1.0.0+1"
```

The tag starts `.github/workflows/android-release.yml`. The workflow validates
the tag and confirms that the tagged commit belongs to `main`, reruns Flutter
and Firestore tests, reconstructs private signing, builds a signed release APK,
generates SHA-256 checksums, retains a workflow artifact, and publishes these
GitHub Release assets:

- `fixmate-android.apk` — stable URL used by the README;
- `fixmate-1.0.0-build.1-android.apk` — immutable versioned APK;
- `SHA256SUMS.txt` — integrity hashes for both APK filenames.

## Post-release verification

1. Confirm every workflow job passed for the expected tag and commit.
2. Download the public APK and verify its SHA-256 checksum.
3. Verify the APK package is `com.fixmatebd.app`, version is `1.0.0+1`, and the
   signing certificate matches the protected release key.
4. Install the downloaded APK on a physical Android device and test startup,
   authentication, customer/provider/admin routing, bookings, Activity, and
   reviews.
5. Record the workflow URL, commit, tag, hashes, certificate fingerprint, and
   device result in `docs/FINALIZATION_PLAN.md`.

## Failure and recovery

- Missing signing secrets: correct the protected Environment and rerun the
  same workflow; never fall back to debug signing.
- Test or source failure: fix through a pull request, increase the build number,
  and create a new tag.
- Incorrect public asset: remove the affected asset while preserving evidence,
  then publish a corrected build under a new build number. Do not move the tag.
- Lost release key: restore the encrypted offline backup. A different key cannot
  update an already installed direct-distribution APK without uninstalling it.
- Firebase rollback is separate. The Android release workflow must never deploy
  Rules, indexes, data, Authentication settings, or App Check enforcement.
