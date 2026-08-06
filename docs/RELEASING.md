# FixMate Android releases and versioning

This runbook defines the controlled path from an approved `main` commit to a
downloadable signed APK and a Google Play App Bundle. Creating a tag publishes
external GitHub release assets, so it always requires explicit authorization.

## Version format

`pubspec.yaml` is the single source of truth:

```yaml
version: MAJOR.MINOR.PATCH+BUILD
```

- Increment **MAJOR** for incompatible product/data changes.
- Increment **MINOR** for backward-compatible features.
- Increment **PATCH** for backward-compatible fixes.
- Increment **BUILD** for every Android artifact submitted to Google Play. A
  version code can never be reused after Play accepts it.

The Git tag must exactly equal the pubspec version with a `v` prefix. For
`version: 1.0.0+1`, use `v1.0.0+1`. Tags are immutable: never move, replace, or
force-push a release tag.

## Required GitHub configuration

Create an `android-release` Environment in repository settings and require a
reviewer before the release job can access its secrets. Store these Environment
secrets:

| Secret | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded private upload keystore |
| `ANDROID_KEY_ALIAS` | Upload-key alias |
| `ANDROID_KEY_PASSWORD` | Upload-key password |
| `ANDROID_STORE_PASSWORD` | Keystore password |

Generate and back up the upload keystore outside the repository. Follow the
official Flutter/Android signing instructions. Never upload the raw keystore to
GitHub, attach it to an issue, place it in FlutLab, or commit `key.properties`.
Keep an offline encrypted backup and recovery instructions under publisher
control.

The workflow reconstructs temporary signing files on the GitHub runner, builds,
then removes them with an `always()` cleanup step. It never logs the values and
does not use a Firebase Admin or service-account credential.
The build/test job has read-only repository permission; only the separate
publication job receives the short-lived `contents: write` permission required
to create GitHub Release assets.

## Release preparation

1. Confirm the intended release scope and update `CHANGELOG.md`.
2. Update `version:` in `pubspec.yaml`; always increase the build number.
3. Review README, legal pages, runbooks, Data safety answers, and known limitations.
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
7. Verify the local `main` is clean and exactly matches `origin/main`.

## Create the authorized tag

Example for the current pubspec version:

```powershell
git switch main
git pull --ff-only origin main
git tag -a "v1.0.0+1" -m "FixMate 1.0.0 build 1"
git push origin "v1.0.0+1"
```

The tag push starts `.github/workflows/android-release.yml`. It validates the
tag and confirms that the tagged commit belongs to `main`, reruns Flutter and
Firestore tests, compiles the FlutLab web preview, configures private signing,
builds the release APK and AAB, creates SHA-256 checksums, retains a signed
workflow artifact, and creates or updates the corresponding GitHub Release.

The public release contains:

- `fixmate-android.apk` for the stable README download link;
- a versioned APK such as `fixmate-1.0.0-build.1-android.apk`;
- `SHA256SUMS.txt`.

The signed AAB is retained in the Actions artifact for the authorized Play
operator. Google Play prefers the AAB; the APK is for direct Android testing.

## Verification after the workflow

1. Confirm every workflow step passed and the expected tag/commit is displayed.
2. Download the APK and verify its SHA-256 checksum.
3. Inspect the APK certificate and confirm it uses the intended upload key.
4. Install on a clean Android device and test startup, Firebase connection,
   customer/provider/admin routing, booking, Activity, and reviews.
5. Download the AAB from the workflow artifact and upload it only to Google Play
   internal testing.
6. Record the workflow URL, commit, tag, hashes, tester result, and Play release
   status in `docs/FINALIZATION_PLAN.md` and `CHANGELOG.md`.

## Failure and rollback

- Missing signing secrets: configure the protected Environment secrets and
  rerun the same workflow; do not weaken release signing.
- Test or source failure: do not publish from the failing commit. Fix through a
  new pull request, increase the Android build number, and create a new tag.
- Incorrect public release asset: remove the affected GitHub Release asset while
  preserving audit evidence; do not move the tag. Publish a corrected build with
  a new build number.
- Bad Play build: stop the internal-testing rollout and upload a new higher
  version code. Google Play does not support reusing a version code.
- Firebase rollback is separate from application release rollback. Never deploy
  Rules, indexes, data, or App Check settings from the Android release workflow.
