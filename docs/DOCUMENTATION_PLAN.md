# FixMate documentation plan

Last reviewed: 6 August 2026 (Asia/Dhaka)

FixMate documentation distinguishes implemented code, local configuration,
deployed Firebase state, CI evidence, GitHub publication, and manual-device
verification. Passing one state does not prove another.

## Maintained documents

| Document | Purpose | Update trigger |
|---|---|---|
| `README.md` | Product, architecture, setup, validation, and APK download entry point | Material feature, setup, or scope change |
| `CHANGELOG.md` | User-visible release history | Every release |
| `docs/FINALIZATION_PLAN.md` | Living evidence, decisions, risks, and remaining checks | Every implementation or deployment milestone |
| `docs/RELEASING.md` | Versioning, private signing, GitHub Release, verification, and recovery | Signing or workflow change |
| `docs/LOCAL_ANDROID_DEVELOPMENT.md` | Local Android tools, physical-device flow, and troubleshooting | Flutter, Android, device, or build change |
| `docs/ADMIN_RUNBOOK.md` | Admin bootstrap, provider approval, categories, moderation, and recovery | Rules or admin behavior change |
| `docs/terms.html` | Terms of Use | Policy or marketplace change |
| `docs/privacy.html` | Data handling and retention disclosure | Data collection or retention change |
| `docs/delete-account.html` | In-app and external deletion instructions | Account-deletion change |

## Milestones

### Repository and contributor readiness

- Keep clean-clone commands runnable.
- Maintain exact product, package, Firebase, and Android identities.
- Link detailed runbooks instead of duplicating instructions.

Acceptance: a reviewer can understand FixMate, run validation, find the APK,
and identify limitations without private knowledge.

### Firebase and administrator operations

- Document provider approval, suspension, category lifecycle, reports,
  disputes, and deletion processing.
- Record the exact target, source hashes, commands, affected resources,
  deployment evidence, and rollback for every authorized Firebase change.

Acceptance: a trusted operator can complete an admin task without guessing
field names, weakening Rules, or using an Admin service-account key.

### Android acceptance

- Record the supported Flutter/Dart versions and physical-device procedure.
- Maintain clean-clone, dependency, test, debug APK, and signed release APK
  evidence.
- Test common Android screen sizes, text scale, keyboard behavior, offline and
  retry states, and customer/provider/admin workflows.

Acceptance: merged `main` passes CI, produces a signed GitHub Release APK, and
has remaining device checks explicitly recorded.

### GitHub release readiness

- Protect the release keystore and passwords outside source control.
- Record tag, commit, workflow URL, release asset hashes, and signing
  certificate fingerprint.
- Verify the downloaded APK rather than only the runner artifact.

Acceptance: the GitHub Release is reproducible, signed, downloadable, and
traceable to a green `main` commit.

## Evidence and security standards

- Use exact commands, dates, project IDs, package IDs, versions, and paths.
- Label work as **coded**, **configured**, **deployed**, **published**, or
  **manually verified**.
- Never include passwords, tokens, private UIDs, private keys, keystores,
  `key.properties`, service-account credentials, or customer data.
- Treat Firebase client configuration as public application identifiers; it is
  never an Admin credential.
- Review public links and core workflows on a physical Android device after
  every release.
