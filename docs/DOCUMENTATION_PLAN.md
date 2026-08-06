# FixMate documentation plan

Last reviewed: 6 August 2026 (Asia/Dhaka)

FixMate documentation must distinguish implemented code, local configuration,
deployed Firebase state, CI evidence, and manual verification. Passing one state
must never be used to claim another.

## Documentation set

| Document | Audience and purpose | Release state | Update trigger |
|---|---|---|---|
| `README.md` | Contributors, reviewers, and beta testers; product and setup overview | Maintained | Material feature, setup, CI, or scope change |
| `CHANGELOG.md` | Testers and release operators; user-visible release history | Maintained from first tag | Every release PR |
| `docs/FINALIZATION_PLAN.md` | Publisher and engineers; living evidence, risks, deployment record | Maintained | Every implementation/deployment milestone |
| `docs/RELEASING.md` | Release operator; version, signing, tag, artifact, and rollback procedure | Required before first tag | Signing or workflow change |
| `docs/LOCAL_ANDROID_DEVELOPMENT.md` | Android developers; local tools, device flow, and troubleshooting | Maintained | Flutter/device/build change |
| `docs/FLUTLAB_READINESS.md` | FlutLab users; import, web preview, Android build constraints, and verified builder evidence | Maintained | FlutLab/platform/dependency change |
| `docs/ADMIN_RUNBOOK.md` | Trusted operator; admin bootstrap, providers, categories, moderation | Maintained | Rules or admin behavior change |
| `PLAY_RELEASE_CHECKLIST.md` | Publisher; Google Play internal-test gates | In progress | Every release candidate |
| `docs/terms.html` | Users and Play review; Terms of Use | Publisher/legal review pending | Policy or marketplace change |
| `docs/privacy.html` | Users and Play review; data handling disclosure | Publisher/legal review pending | Data collection/retention change |
| `docs/delete-account.html` | Users and Play review; deletion instructions | Manual verification pending | Account-deletion change |

## Documentation milestones

### Milestone 1 — Repository and contributor readiness

- Keep README commands runnable from a clean clone.
- Maintain the repository tree, fixed identities, Firebase scope, and explicit
  first-release limitations.
- Link every detailed runbook instead of duplicating conflicting instructions.
- Add contribution/security policies if public external contributions are opened.

Acceptance: a reviewer can understand the product, run validation, locate the
APK, and identify deferred features without private knowledge.

### Milestone 2 — Administrator and Firebase operations

- Document provider approval, suspension, category lifecycle, reports,
  disputes, deletion requests, and recovery.
- Record exact Firebase target, reviewed source hashes, commands, affected
  resources, deployment evidence, and rollback for every authorized change.
- Remove stale statements immediately after a verified live-state change.

Acceptance: a trusted operator can complete a task without guessing field names,
weakening Rules, or using a service-account key.

### Milestone 3 — Android and FlutLab acceptance

- Record supported Flutter/Dart versions and FlutLab builder settings.
- Maintain clean-clone, Pub Get, debug APK, signed release APK, and AAB evidence.
- Add a manual test matrix for small/medium/large Android screens, text scale,
  keyboard, offline/retry, customer, provider, and administrator flows.

Acceptance: the merged `main` builds locally, in GitHub Actions, and in FlutLab,
with remaining device checks clearly identified.

### Milestone 4 — Internal testing and legal readiness

- Finalize support contact ownership and GitHub Pages URLs.
- Obtain publisher/legal review for Terms and Privacy wording.
- Complete Play Data safety, account deletion, UGC, content rating, App Check,
  signing, and tester instructions.
- Record release tag, commit, checksums, CI URL, Play track, and known issues.

Acceptance: the publisher can support every Play declaration with repository or
Console evidence.

## Writing and evidence standards

- Use exact commands, dates, project IDs, package IDs, versions, and artifact paths.
- Label work as **coded**, **configured**, **deployed**, or **manually verified**.
- Link to authoritative source files and official external documentation.
- Keep instructions task-oriented and describe rollback for external changes.
- Never include passwords, tokens, private UIDs, private keys, keystores,
  `key.properties`, service-account credentials, or personal customer data.
- Treat Firebase client configuration as public identifiers while still applying
  appropriate API/application restrictions.
- Review all links and screenshots on a physical Android device before release.

## Ownership before the first tag

- **Publisher:** legal text, support mailbox, Play Console declarations, signing
  key custody, release approval.
- **Trusted Firebase operator:** Rules/index/data deployment evidence, admin
  membership, moderation, deletion processing, App Check monitoring.
- **Engineering:** README, architecture, tests, CI/CD, versioning, runbooks,
  changelog, and reproducible build evidence.
- **Beta tester:** device matrix, accessibility, offline behavior, end-to-end
  customer/provider/admin acceptance, and release APK installation.

No version tag should be pushed until every required owner has completed and
recorded their release-gate checks.
