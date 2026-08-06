# FixMate finalization plan

Last updated: 6 August 2026 (Asia/Dhaka)

This is the living evidence record for the Android internal-testing beta. Code,
local configuration, deployed Firebase state, and manual device verification
are separate states.

## Fixed scope

- Product: FixMate; repository: `fixmate-app`; Dart package: `fixmate`.
- Android application ID and namespace: `com.fixmatebd.app`.
- Initial and only application platform: Android.
- Firebase project: `fixmate-ce36d` on the Spark plan.
- Cloud Functions, Cloud Storage, uploaded images, and push notifications are
  deferred.
- GitHub Pages under `docs/` remains the legal site and is not an application
  platform.

## Verified repository and Firebase state

- Remote: `https://github.com/ForhanShahriarFahim/fixmate-app.git`.
- Current implementation started from `main` at `c40e935` with existing user
  changes in `android/gradle.properties` and `pubspec.lock`; neither change was
  discarded.
- No applicable `AGENTS.md` file exists in the repository or its checked parent
  directories.
- Flutter 3.44.8 / Dart 3.12.2 is installed at `F:\dev\flutter`.
- Android package, namespace, manifest label, Google Services registration, and
  generated Firebase Android options remain aligned.
- Stage 6B deployed only the reviewed Firestore Rules, 11 composite indexes,
  and six categories to `fixmate-ce36d`. Rules hash at deployment was
  `6063EE1EBFF5FED0A2C37F6334506D600545A280EA5575CFF20D5FE8DAFA722B`;
  all 11 indexes were verified Enabled, and the six documents were
  `electrical`, `plumbing`, `cleaning`, `ac-repair`, `appliance-repair`, and
  `painting`.
- App Check enforcement remained disabled. No Hosting, Storage, Functions,
  Messaging, Authentication configuration, billing, or unrelated Firestore
  resource was deployed during Stage 6B.

## Current Android correction milestone

Verified root causes before implementation:

1. Flutter bindings were initialized outside the guarded zone while the
   successful `runApp` executed inside it, causing `Zone mismatch`.
2. The provider form rendered inline at `/provider` and navigated to the same
   location after saving, so navigation did not establish a new state.
3. Email verification reloaded the user but did not force-refresh the ID token;
   Firestore could therefore receive a stale `email_verified: false` claim.
4. Provider submission awaited a write but did not perform a server read-back
   or explicitly refresh the Riverpod provider profile state.

Implemented corrections:

- Binding initialization, Firebase, App Check, Crashlytics handlers, setup
  failure UI, and every `runApp` now execute in one guarded Dart zone.
- Crashlytics is called only after Firebase initialization; debug errors remain
  visible in the console.
- Verification refresh reloads the user, reacquires the current-user instance,
  force-refreshes its ID token, invalidates Riverpod auth/profile state, and
  navigates only when the refreshed user is verified.
- Provider submission safely handles a missing session, prevents double taps,
  performs a server-confirmed read-back, requires pending/hidden returned state,
  invalidates the profile stream, and immediately renders the review state.
- Submission failures retain form state and provide provider-specific guidance
  for permission denial without logging tokens or personal information.
- Provider entry resolution is driven by the persisted profile: missing → form,
  pending → review, rejected → needs changes, approved and visible → dashboard.
- Android-only configuration removed application web options and cloud-preview
  scaffolds while retaining the independent legal Pages site.

## Baseline evidence before this milestone

| Command | Result |
|---|---|
| `flutter --version` | Pass: Flutter 3.44.8, Dart 3.12.2 |
| `flutter pub get` | Pass; no mass dependency upgrade performed |
| `dart format --output=none --set-exit-if-changed lib test` | Pass; 29 files, 0 changes |
| `flutter analyze` | Pass; no issues (235.0s) |
| `flutter test` | Pass; 16 tests |
| `flutter build apk --debug` | Pass; SDK XML version warning only |
| `flutter devices` | Phone unavailable; Windows, Chrome, and Edge detected |
| `npm --prefix functions ci` | Blocked: timed out after five minutes with no output |
| `npm --prefix functions test` | Blocked after incomplete install: `tsc` unavailable |
| `npm --prefix functions run test:rules` | Not run at baseline because dependency installation was incomplete |

## Security constraints preserved

- Firestore still requires a verified-email ID-token claim for active
  marketplace mutations.
- Provider-authored profiles are always reset to `pending` and
  `marketplaceVisible: false`; providers cannot self-approve.
- Debug App Check uses `AndroidDebugProvider`; release uses Play Integrity.
- App Check enforcement is not changed by repository code.
- Release signing remains fail-closed. Debug signing is not used for release.
- No Admin credential, service-account key, App Check debug token, upload
  keystore, `key.properties`, password, or secret belongs in source control.

## Post-implementation automated evidence

| Command | Result |
|---|---|
| `flutter --version` | Pass: Flutter 3.44.8, Dart 3.12.2 |
| `flutter pub get` | Pass; 28 newer incompatible packages reported, with no mass upgrade performed |
| `dart format --output=none --set-exit-if-changed lib test` | Pass; 31 files, 0 changes on the final verification pass |
| `flutter analyze` | Pass; no issues |
| `flutter test` | Pass; 22 tests, including verification ordering, provider state, success, failure retention, restart reconstruction, and duplicate-submit coverage |
| `flutter build apk --debug` | Pass in 47.7s; `build/app/outputs/flutter-apk/app-debug.apk` |
| `npm --prefix functions ci` | Pass; 835 packages installed; audit reports 17 moderate and 3 high inherited advisories for later reviewed dependency work |
| `npm --prefix functions test` | Pass; 5 local tooling tests, with 24 emulator-only cases skipped as designed by this command |
| `npm --prefix functions run test:rules` | Pass; 24/24 emulator cases, including the exact pending/hidden provider payload, unverified denial, and self-approval denial |
| `git diff HEAD --check` | Pass; no whitespace errors |
| Obsolete application-platform reference scan | Pass; no cloud-preview, application web, or iOS platform references remain outside deleted history |

The debug APK is automated build evidence only. `flutter devices` and
`adb devices -l` did not list the M2003J15SC, so `flutter run -d
c57ddc760409 --debug` and the manual authentication/provider flow were not run.
No external Firebase resource was deployed, updated, deleted, or reseeded.

## Remaining validation and acceptance criteria

- Formatting, analysis, all Flutter tests, debug APK, TypeScript tests, and
  Firestore emulator Rules tests pass after the implementation diff.
- The physical M2003J15SC must be detected before `flutter run -d
  c57ddc760409 --debug` can be performed.
- Manual provider registration, email verification, pending/hidden Firestore
  state, immediate review screen, restart reconstruction, and absence of a zone
  warning remain manual until the phone and test credentials are available.
- Email/Password Authentication, App Check monitoring/debug-token registration,
  and Crashlytics delivery still require Firebase Console/device confirmation.
- Legal review, support email, Play declarations, private release signing, AAB,
  and Play internal testing remain release blockers.

## Rollback and recovery

Repository changes in this milestone are intentionally uncommitted. Review the
complete diff before any future commit. Do not use destructive Git commands;
revert individual reviewed files through an intentional follow-up change if a
rollback is required. No external Firebase resource is modified by this work.

## Authentication, profile recovery, and administrator milestone

Verified root causes:

1. A successful Firebase Authentication session with no `users/{uid}` document
   rendered a static error with no sign-out or navigation action.
2. `_RoleGuard` and `_AccountGuard` rendered an indefinite loading indicator
   for the same missing-document state and exposed raw profile-load errors.
3. Administrator authority, routing, dashboard, and protected provider-review
   fields did not exist; provider approval was only a manual Console process.
4. The shared filled outline-field theme removed its border side and lacked
   explicit content padding, which allowed floating labels to meet the border
   poorly on the physical Android layout.

Implemented locally:

- Authentication failure remains on Login; malformed email is rejected before
  Firebase; invalid credentials use a non-enumerating message; loading resets
  and duplicate submissions are blocked.
- Admin membership is checked before the ordinary profile. A confirmed missing
  profile now explains incomplete setup, can check again, and returns to Login
  only after sign-out. Android Back performs the same recovery. Firestore
  loading failures are a distinct retryable state.
- `/admin` and `/admin/provider/:providerId` are guarded by
  `admins/{uid}.active`, not an editable user role. The dashboard lists pending
  applications, displays submitted and registered-account details, approves,
  rejects with required feedback, and signs out.
- Review writes use server timestamps and protected `reviewedAt`, `reviewedBy`,
  and `rejectionReason` fields. Revised local Rules deny admin self-assignment,
  provider self-approval, admin self-review, public hidden-profile reads, and
  non-admin application listing.
- Pending/rejected providers now see next steps, administrator feedback,
  explicit editing, account information, and sign-out. Provider edits reset
  review status to pending/hidden.
- Shared form fields now use a real outline border, focused/error borders,
  floating labels, and 18-pixel vertical content padding. Login, registration,
  password-reset, verification, recovery, provider-status, and admin review
  surfaces remain scrollable for keyboard and text scaling.

The revised Security Rules were explicitly deployed on 6 August 2026 to
`fixmate-ce36d` with the rules-only command documented below. The first trusted
administrator membership was then created for the project's only verified
Authentication account. Its live document contains `active: true` and
`displayName: "FixMate Administrator"`, which is sufficient for `isAdmin()`.
Firebase Console rejected the optional `createdAt` timestamp update, so that
field is not claimed as live. No index, category, Functions, Storage, Hosting,
Authentication configuration, App Check enforcement, or other Firebase
resource was modified during this administrator bootstrap.

Latest automated evidence (6 August 2026):

| Command | Result |
|---|---|
| `flutter analyze` | Pass; no issues |
| `flutter test` | Pass; 32 tests, including invalid login, malformed email, duplicate submit, missing-profile sign-out/Back recovery, retryable profile errors, 320dp/2x login/registration text scale, provider restart, and rejection feedback |
| `npm --prefix functions test` | Pass; 5 tooling tests; emulator-only cases skipped as designed |
| `npm --prefix functions run test:rules` | Pass; 27/27 emulator cases, including admin membership, hidden application reads, approve/reject audit writes, provider self-approval, and self-admin denial |

Administrator deployment evidence (6 August 2026):

- pre-deployment identity checks verified Firebase project `fixmate-ce36d`,
  one Android client for `com.fixmatebd.app`, and `firebase.json` pointing to
  `firestore.rules`;
- `npm run test:rules --prefix functions` passed all 27 emulator cases;
- deployed Rules SHA-256:
  `423EA3F6442CAD0D26CDA2C2877EB98CB2D26175352997468CB84F13229710F1`;
- deployment used the repository-pinned Firebase CLI 15.24.0:
  `functions\\node_modules\\.bin\\firebase.cmd deploy --only firestore:rules --project fixmate-ce36d --non-interactive`;
- the CLI compiled, uploaded, and released only `firestore.rules` successfully;
- exactly one `admins/{uid}` document was visually verified with `active: true`
  and the expected display label. Its UID is deliberately not copied into this
  repository.

Still required before administrator acceptance:

- sign in to the current FixMate build with the administrator account and
  confirm routing to **Provider reviews**;
- register a separate provider account and manually exercise pending,
  rejection feedback, resubmission, approval, service access, sign-out, Back,
  and large-font flows on the M2003J15SC;
- optionally add a trusted `createdAt` timestamp to the first admin membership
  if Firebase Console's timestamp editor succeeds in a later operator session.

Physical-device evidence on 6 August 2026:

- M2003J15SC (`c57ddc760409`), Android 12/API 31, was detected and the current
  debug APK was installed/launched after Xiaomi's Install via USB step.
- The current FixMate process visibly rendered the new **Complete account
  setup** recovery screen with **Check again** and **Return to sign in**. This
  confirms the fixed APK reached the previously trapped real-device state.
- Automated ADB touch/Back injection is denied by this MIUI build's
  `INJECT_EVENTS` policy, so the physical tap and Back outcomes still require a
  person to press them. Widget tests verify both paths sign out before Login.
- Process-scoped log review reproduced `DEVELOPER_ERROR` and attributed it to
  Google Play services 26.28.33 `Phenotype.API` (`FlagRegistrar`/`FlagStore`),
  with `Unknown calling package name 'com.google.android.gms'`. There was no
  fatal Android exception, Flutter exception, Firebase initialization failure,
  or zone mismatch. FixMate has no Google Sign-In dependency; the Firebase
  project and package remain correct. Treat this as a non-user-facing
  Play-services/MIUI flag-client warning and recheck after device updates and
  on the future Play-installed build.

App Check follow-up remains separate: debug builds use the debug provider and
must keep its token private; the Play release uses Play Integrity and will need
the final Play signing SHA-256 registered before enforcement. App Check
enforcement remains disabled.

## Marketplace reliability and usability milestone (6 August 2026)

Verified problems and decisions:

- The provider dashboard coupled the rating aggregate, booking aggregates, and
  booking stream behind one all-or-nothing error state. A single aggregate
  failure therefore replaced the whole dashboard with the generic error.
- Firebase Authentication must create the identity before it can send an email
  verification link. An unverified account appearing in Authentication is
  expected. The router and Firestore Rules continue to deny marketplace access
  until the refreshed ID token contains `email_verified: true`; automatic
  cleanup of abandoned unverified identities is deferred because it requires a
  trusted scheduled backend outside the Spark/client-only release.
- Booking creation replaced the navigation stack with Booking Details, while
  Booking Details had no fallback when no route could be popped.
- Activity was a synthetic, in-app view of recent bookings/messages with no
  persisted read cursor. Completed bookings were not intentionally filtered,
  but their state was not explained or tested.
- Exact review and dashboard aggregates existed, but provider-owned profile
  presentation and refresh behavior were incomplete.
- The category seed was operator-only; administrators had no application UI
  for adding or deactivating provider-selectable categories.
- This release supports confirmed cash payment only. A fake online checkout is
  not added without a trusted payment provider and server/webhook validation.

Implemented locally:

- Provider Dashboard now renders bookings even if a reputation or analytics
  aggregate fails, exposes targeted retry, and reports new requests, active
  jobs, completed jobs, active/total listings, exact confirmed-cash earnings,
  and verified review data. Returning to Dashboard/Profile refreshes aggregates.
- Customer and provider shells accept safe tab destinations. Booking creation
  preserves its previous route, Booking Details always exposes Back or Return
  to Bookings, and the page includes a bottom Return to Bookings action.
- Booking and create-booking screens clearly identify cash as the active method
  and online payment as unavailable. No card/wallet information is accepted.
- Activity now keeps terminal/completed booking history, shows timestamps,
  persists one private `lastReadAt` cursor per user, displays unread dots and
  navigation badges, and provides a duplicate-safe Mark all read action. It is
  still explicitly in-app Activity; push notifications are not claimed.
- Exact verified ratings are displayed on public provider profiles and the
  provider's own Profile tab, with refresh/error behavior. A successful local
  review invalidates the affected provider's cached rating.
- Administrators have a protected Service categories screen for create, edit,
  activate, and deactivate. IDs are immutable lowercase slugs; deletion is
  denied. Providers automatically select from active categories, receive a
  useful empty state, and cannot save an inactive/stale category.
- The verification screen now explains why the Authentication identity already
  exists and enumerates the capabilities that remain blocked.

Security and deployment state:

- Local Rules add strict admin-only category writes and owner-only
  `activity_states/{uid}` reads/writes. Category deletion and Activity-state
  deletion remain denied. Unverified users cannot write Activity state.
- These revised Rules were coded and emulator-tested during this milestone and
  were subsequently deployed in the Rules-only release recorded below. No live
  Firebase resource was changed during the original implementation milestone.
- The two GitHub Google API-key alerts point to generated Firebase client
  configuration. Firebase documents that Firebase client API keys identify a
  project/app and are not authorization secrets; Firestore Rules and App Check
  protect data. The alerts must not be "fixed" by inventing values or deleting
  required client configuration. Before resolving them, an operator must review
  Google Cloud application/API restrictions for the Android and web client keys,
  then resolve the GitHub alerts with an accurate explanation. No Admin key,
  service-account credential, private key, signing file, password, or App Check
  debug token was added.

Automated evidence for this milestone:

| Command | Result |
|---|---|
| `flutter analyze` | Pass; no issues (92.2s) |
| `flutter test` | Pass; 35 tests |
| isolated Firestore emulator test command on port 8181 | Pass; 29/29 Rules cases, including category administration and private Activity state |
| `flutter build apk --debug` | Pass on final rerun; `build/app/outputs/flutter-apk/app-debug.apk` (60.1s) |
| `git diff --check` | Pass before final documentation update |

Remaining acceptance work:

- Manually verify admin category creation/deactivation and Activity unread state
  against `fixmate-ce36d`; the required Rules-only deployment is now complete.
- Run two-account physical-device tests for registration/verification,
  provider submit/approve/login, dashboard partial failure/retry, create and
  complete booking, completed Activity retention, unread badge/mark-read,
  review refresh, and booking return navigation.
- Review/restrict the two Firebase client keys in Google Cloud Console and
  resolve the corresponding GitHub alerts. Do not rotate/delete a working
  Firebase client key until replacement configuration and clean builds are
  verified.
- Online payment remains deliberately deferred. A future implementation needs
  a selected Bangladesh-capable gateway, server-created payment intents,
  authenticated webhooks, idempotency, refund/dispute handling, updated Rules,
  and legal/Play disclosures; a client-only demo must not claim real payment.

## Android startup-spinner recovery (6 August 2026)

Real-device evidence:

- The user command sequence was valid: dependency resolution, analysis, tests,
  the debug APK build, installation, and Android process startup all succeeded.
- On M2003J15SC / Android 12, Firebase initialized successfully and the cached
  verified Authentication session was restored. HTTPS requests from the phone
  reached both Firestore and Identity Toolkit endpoints.
- The indefinite loading state was isolated to the protected
  `admins/{uid}` Firestore listener. No Flutter fatal exception or Firebase
  identity mismatch occurred.
- A fresh Authentication ID token completes successfully. A bounded one-time
  Firestore server read also completes and lets the application enter the
  correct role dashboard; the long-lived listener was the stalled path.
- Read-only Console inspection verified project `fixmate-ce36d`, Spark billing,
  App Check not yet registered (and therefore not enforced), and an Android
  client key that includes Firestore and Identity Toolkit with no application
  restriction. No cloud setting was changed.
- Once the dashboard opened, device logs showed the expected
  `permission-denied` for `activity_states/{uid}` because the revised local
  Rules documented above have not been deployed. That is separate from the
  startup-spinner defect and remains an explicitly deferred Rules-only deploy.

Implemented recovery:

- Startup now has a 12-second progress explanation plus Retry and a safe
  Return to sign in action instead of an unbounded blank spinner.
- Firestore server confirmation uses one absolute 15-second deadline, so
  repeated cache events cannot restart the timeout indefinitely.
- A restored verified user receives a fresh ID token before protected
  Firestore reads begin. Failure surfaces as a retryable session error rather
  than an ambiguous account/profile failure. The startup provider deliberately
  does not call `reload()`, because `userChanges()` would retrigger it and form
  a refresh loop; explicit email-verification refresh keeps its separate tested
  reload path.
- Administrator membership uses a bounded server read before attaching its
  live listener. Permission denial safely means no administrator authority;
  existing role routing then continues normally.
- App Check client activation is opt-in with
  `--dart-define=FIXMATE_ENABLE_APP_CHECK=true`. This matches the current
  Console state and avoids pretending that an unregistered provider is
  configured. Register the Android app and debug/Play providers before opting
  in; keep enforcement disabled until verified.
- The latest debug APK was installed over the existing app without clearing
  user data and visibly reached the provider dashboard. No Firebase resource,
  Git branch, commit, or remote was changed.

Latest automated evidence:

| Command | Result |
|---|---|
| `flutter analyze` | Pass; no issues |
| `flutter test` | Pass; 36 tests |
| `flutter build apk --debug` | Pass; `build/app/outputs/flutter-apk/app-debug.apk` |

Remaining manual/device work:

- Retest Activity unread state and admin category management now that the
  reviewed Rules-only deployment is complete.
- Reopen Dashboard, Bookings, Services, Activity, and Profile on the physical
  phone and exercise Retry/Return to sign in manually; MIUI blocks automated
  accessibility tap injection on this device.
- Register App Check providers later, opt in with the documented Dart define,
  observe valid traffic, and keep enforcement disabled until both debug and
  Play-installed builds are verified.

## Marketplace visibility and reliability recovery (6 August 2026)

Verified causes:

- Provider reputation and analytics depended on Firestore aggregate RPCs. The
  device could complete ordinary Firestore reads, but those independent RPCs
  timed out or failed, leaving both cards unavailable even though recent
  bookings were readable.
- Before the Rules-only release, the live Rules did not contain the reviewed
  `activity_states/{uid}` owner access or administrator category-list/write
  access. Device logging confirmed that historical `permission-denied`; the
  later verified deployment resolved the live/local Rules mismatch.
- A completed booking supported one review in the data model, but the provider's
  own Profile omitted the review list and Booking details always offered the
  review action. Multiple reviews from different completed bookings therefore
  appeared ambiguous even though duplicate reviews for one booking were denied.

Implemented locally:

- Reputation and provider analytics now use bounded, exact, paginated server
  reads rather than aggregate RPCs. The calculation includes all fetched pages,
  ignores malformed ratings, counts booking states consistently, and counts
  earnings only for completed `paidCash` bookings. Reads have an absolute
  deadline and avoid unbounded collection access.
- Category, review, and booking-review streams perform a bounded initial server
  read before attaching their live listener. This provides deterministic initial
  errors and avoids an indefinite loading card.
- Activity history remains usable if unread-state access is denied. The screen
  explains that unread markers are unavailable, does not mislabel events as
  unread, and preserves retry behavior for unrelated failures. The reviewed
  live Rules now authorize the normal unread-state path.
- Provider Profile and public provider/service views display consistent verified
  review cards with customer, rating, date, and an explicit no-comment label.
  Completed Booking details show an existing review instead of offering a
  duplicate submission; each completed booking can be reviewed once.
- Administrator Categories are grouped into Active and Inactive sections, show
  counts and permanent IDs, support refresh, generate Rules-compatible slugs,
  and provide clearer form validation. Add/edit is disabled with a specific
  deployment message when live Rules deny the administrator query.
- Rating stars now expose one screen-reader label, and the new calculation,
  category-ID, review-presentation, and actual Firestore-query paths have
  automated coverage.

Firebase and deployment state:

- Project identity remains `fixmate-ce36d`; Android application ID and namespace
  remain `com.fixmatebd.app`; all 11 existing composite indexes remain declared.
- Revised local Rules SHA-256 is
  `595A77FAFFF2E2C69DDEB53B0A0AC6DC8EF2061A7466265A4B17437295CB0355`.
- The revised Rules were initially coded and emulator-tested without deployment.
  The user subsequently approved and completed the Rules-only release recorded
  below. No Firebase data, indexes, Authentication setting, App Check setting,
  or other external resource was changed.

Automated evidence for this milestone:

| Command | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | Pass; 36 files unchanged after formatting |
| `flutter analyze` | Pass; no issues |
| `flutter test` | Pass; 43/43 tests, including exact statistics, Activity fallback, category slugs, review visibility, and review accessibility |
| `npm --prefix functions test` | Pass; 5 passed, 30 intentionally skipped emulator-only cases |
| `npm --prefix functions run test:rules` | Pass; 30/30 Rules/emulator cases |
| `flutter build apk --debug` | Pass; `build/app/outputs/flutter-apk/app-debug.apk` |

Remaining manual/device work:

- Verify administrator category add/edit/deactivate and customer/provider unread
  Activity markers against the live project after the Rules-only release.
- Install the final debug APK without clearing data. Exercise provider Dashboard
  and Profile, both Activity screens, administrator Categories, two completed
  booking reviews, review retry/empty states, and the one-review-per-booking UI.
  The 6 August replacement-install attempt was blocked by the connected Xiaomi
  device with `INSTALL_FAILED_USER_RESTRICTED` (install cancelled by the user),
  so no final-build device behavior is claimed yet.
- Online payments, Cloud Functions, Cloud Storage, push notifications, and App
  Check enforcement remain deliberately outside this Firebase Spark release.

## Firestore Rules-only deployment (6 August 2026)

- User authorization was explicit and limited to `firestore.rules` for Firebase
  project `fixmate-ce36d`.
- Pre-deployment checks verified repository
  `ForhanShahriarFahim/fixmate-app`, branch `main`, Android package and namespace
  `com.fixmatebd.app`, Rules source `firestore.rules`, all 11 existing indexes,
  and reviewed local Rules SHA-256
  `595A77FAFFF2E2C69DDEB53B0A0AC6DC8EF2061A7466265A4B17437295CB0355`.
- The last pre-deployment emulator run passed 30/30 Rules cases.
- At 13:24:54 UTC (19:24:54 Asia/Dhaka), Firebase CLI 15.24.0 compiled,
  uploaded, and released only the Firestore Security Rules with:
  `npx firebase-tools@15.24.0 deploy --only firestore:rules --project fixmate-ce36d --config firebase.json`.
- Read-only Firebase Rules API verification identified release
  `projects/fixmate-ce36d/releases/cloud.firestore` and Ruleset
  `projects/fixmate-ce36d/rulesets/43b0ae97-b63d-4b98-a7bf-4ad0c932f4fb`.
  Its normalized source exactly matches the reviewed local file.
- No index deployment, document write, seed operation, Authentication change,
  App Check change, Functions, Storage, Hosting, Cloud Messaging, billing, or
  other Firebase resource was included.
- Rollback: use Firebase Console Rules history to restore the immediately prior
  Rules release, or redeploy a reviewed prior `firestore.rules` revision with
  the same Rules-only command. Never weaken the Rules to recover UI access.
- Remaining evidence is a manual administrator add/edit/deactivate check and a
  customer/provider Activity unread/mark-read check against the live project.

## Category deletion and release automation milestone (6 August 2026)

Verified starting state:

- The administrator category card exposed only a crowded edit control and
  Firestore Rules denied every category deletion.
- Services retain category IDs, including archived services. Unconditional hard
  deletion would therefore orphan listings and break marketplace integrity.
- CI validated a debug APK but discarded it at job completion. The repository
  had no tag/version contract, protected signing workflow, release checksums, or
  stable GitHub APK download.
- Android Gradle signing was already correctly fail-closed when the untracked
  upload keystore or `android/key.properties` was absent.

Implemented locally:

- Category cards now show state, display order, permanent ID, a standard actions
  menu, busy indicator, edit action, and contextual delete action. Active
  categories explicitly require deactivation first.
- Permanent deletion requires confirmation. The repository performs a server
  administrator check, server category read, inactive-state check, and a bounded
  query for any active or archived service reference. Any reference blocks the
  deletion with remediation guidance.
- Revised Rules permit deletion only to an active administrator when the stored
  category is inactive. Administrators can read service documents solely to
  perform the reference check. Because no trusted Cloud Function exists on
  Spark, Rules cannot themselves query the whole services collection; requiring
  deactivation prevents new provider references while the trusted admin client
  performs the final check.
- CI retains successful debug APKs for 14 days. The new Android release workflow
  is triggered only by a `v<MAJOR.MINOR.PATCH+BUILD>` tag matching `pubspec.yaml`,
  reruns all Flutter and Rules checks, reconstructs signing from protected GitHub
  Environment secrets, builds signed APK/AAB files, generates checksums, retains
  a 90-day artifact, and publishes versioned plus stable APK release assets.
- Release signing remains fail-closed and temporary signing files are removed in
  an `always()` cleanup step. Build/test uses a read-only repository token; only
  the separate asset-publication job receives `contents: write`. The workflow
  has no Firebase deployment command or Firebase/Admin credential.
- `README.md`, `CHANGELOG.md`, `docs/RELEASING.md`,
  `docs/DOCUMENTATION_PLAN.md`, and the administrator runbook now define project
  scope, setup, downloads, versioning, signing, release, rollback, documentation
  ownership, and remaining beta limitations.

Deployment and publication state:

- The user explicitly authorized the updated Rules-only deployment to
  `fixmate-ce36d`. Immediately before deployment, the repository, `main`
  branch, GitHub remote, Android package/namespace, Google Services project,
  configured Rules path, authenticated CLI project access, and reviewed Rules
  SHA-256 were reverified. The repository has no `.firebaserc`, so the exact
  Firebase project was supplied explicitly rather than inferred.
- At 14:26:39 UTC (20:26:39 Asia/Dhaka), Firebase CLI 15.24.0 compiled,
  uploaded, and released only `firestore.rules` with:
  `npx firebase-tools@15.24.0 deploy --only firestore:rules --project fixmate-ce36d --config firebase.json`.
  The deployed local file SHA-256 is
  `912BF14253AA3EE4CB94179BCC235F0A6D56E83AD5332DC90E659C2B91E4AF83`.
- Read-only Firebase Rules API verification identified release
  `projects/fixmate-ce36d/releases/cloud.firestore` and Ruleset
  `projects/fixmate-ce36d/rulesets/577f8c43-e376-4a13-97df-e90165194a2c`.
  Its normalized source exactly matches the reviewed local file.
- No indexes, Firestore documents or category seed data, Authentication
  configuration, App Check setting or enforcement, Functions, Storage,
  Hosting, Cloud Messaging, billing, or other Firebase resource was modified.
  App Check enforcement remains disabled.
- No commit, push, tag, GitHub Release, signing-secret change, or Google Play
  action was performed in this milestone.
- Recovery requires selecting the immediately previous release in Firebase
  Console Rules history or explicitly authorizing a Rules-only redeployment of
  a reviewed earlier `firestore.rules`. Rules must not be weakened as a
  workaround.
- The first intended tag is `v1.0.0+1`, but it must not be created until the
  working tree is reviewed, CI is merged on `main`, protected signing secrets
  exist, and manual release gates pass.

Automated evidence:

| Command/check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | Pass; 36 files, 0 changes |
| `flutter analyze` | Pass; no issues |
| `flutter test` | Pass; 46/46 tests, including active/inactive category menu behavior, overflow regression coverage, and the verified Firebase web identity |
| `npm --prefix functions test` | Pass; 5 tooling tests; 30 emulator-only cases skipped as designed |
| `npm --prefix functions run test:rules` | Pass; 30/30 cases, including active/non-admin deletion denial, inactive administrator deletion, and administrator service-reference query access |
| GitHub workflow YAML parsing | Pass for `ci.yml` and `android-release.yml` |
| Release Bash syntax and tag-validation dry run | Pass; `v1.0.0+1` matches `pubspec.yaml` |
| `flutter build apk --debug` | Pass; `build/app/outputs/flutter-apk/app-debug.apk` |
| Local Markdown link check | Pass across the maintained Markdown documentation |
| `git diff --check` | Pass |
| Targeted credential/signing scan | Pass; no private key, service account, Google API key, App Check token, literal signing password, keystore, or `key.properties` in the intended files |

Remaining acceptance work:

- With the Rules deployment complete, manually add a disposable unused
  category, deactivate it, delete it, and confirm deletion is blocked when a
  service references a category.
- Before the first tag, configure the protected `android-release` Environment,
  verify the intended upload certificate, run the tag workflow, download the APK
  and checksum, install it on a clean device, and upload only the AAB to Play
  internal testing.

## GitHub release-readiness milestone (6 August 2026)

Scope and branch:

- Work is isolated on `codex/finalize-release-readiness`, created from
  `main` commit `c40e935` and targeted at
  `ForhanShahriarFahim/fixmate-app`.
- The previously staged deletion of `web/`, `ios/`, `.metadata`, and
  `docs/FLUTLAB_READINESS.md` was excluded because it would regress the
  already-merged FlutLab import and web-preview support. All application,
  security, test, and documentation changes were otherwise preserved.
- Android remains the only release target. The Firebase-connected web build is
  a FlutLab preview and browser-regression target, not a separately published
  production application.

Implemented release infrastructure:

- Pull-request and `main` CI now verifies formatting, analysis, 46 Flutter
  tests, the Firebase-connected web build, the debug Android APK, TypeScript
  tooling, and 30 Firestore Rules emulator cases. Successful runs retain
  `fixmate-debug-<commit>` for 14 days.
- `pubspec.yaml` remains the version source of truth at `1.0.0+1`; the first
  eligible immutable tag is `v1.0.0+1`.
- The tag-only Android workflow rejects a tag that differs from `pubspec.yaml`
  or points outside `main`, reruns the complete validation suite, compiles the
  web preview, reconstructs private signing only from protected Environment
  secrets, builds signed APK/AAB files, writes SHA-256 checksums, retains a
  90-day signed artifact, and publishes stable/versioned APK release assets.
  Build/test permissions are read-only; only the publication job receives
  `contents: write`, with `actions: read` for the same-run artifact.
- Signing remains fail-closed. No keystore, `key.properties`, signing value,
  Firebase Admin key, service-account credential, or App Check debug token is
  tracked. The workflow does not deploy Firebase resources.
- README, changelog, FlutLab readiness, release runbook, documentation plan,
  admin runbook, and Play checklist now cross-link the maintained setup,
  operations, artifact-download, versioning, signing, and release procedures.

Local validation evidence:

| Command/check | Result |
|---|---|
| `flutter pub get` | Pass with committed dependency constraints |
| `dart format --output=none --set-exit-if-changed lib test` | Pass; 36 files, 0 changes |
| `flutter analyze` | Pass; no issues |
| `flutter test` | Pass; 46/46 tests |
| `flutter build web --debug` | Pass; Firebase-connected `build/web` |
| `flutter build apk --debug` | Pass; 176,852,672 bytes, package `com.fixmatebd.app`, version `1.0.0+1` |
| Debug APK SHA-256 | `2C439BE42D7EA4AB96A76B0DC2BD53776AD5B10517E9BD2D96A439AE8861BD9E` |
| `npm --prefix functions ci` | Pass; npm reports 17 moderate and 3 high transitive advisories for reviewed follow-up |
| `npm --prefix functions test` | Pass; 5 tooling tests, 30 emulator cases skipped as designed |
| `npm --prefix functions run test:rules` | Pass; 30/30 emulator cases |
| Workflow YAML and embedded Bash validation | Pass; four workflows and six Bash blocks |
| Version/tag contract | Pass; `1.0.0+1` maps to `v1.0.0+1` |
| Local Markdown links | Pass across ten maintained Markdown files |
| Diff/signing/credential checks | Pass; no whitespace error, tracked signing file, server credential, App Check token, or new Google API key in the diff |

Remote and publication state:

- GitHub Actions is enabled. Existing repository Environments are `beta` and
  `github-pages`; `android-release` and its four signing secrets are not yet
  configured, so no signed tag should be created.
- The generated Firebase client API keys remain existing public client
  identifiers from merged `main`; this diff introduces no new key. API and
  application restrictions still require operator review before resolving the
  existing GitHub alerts.
- No release tag, GitHub Release, Play upload, additional Firebase deployment,
  or signing-secret change is included in this milestone.
- After pull-request CI passes and the work is reviewed, merge to `main`,
  configure the protected signing Environment, complete manual device/FlutLab
  gates, then request separate authorization before pushing `v1.0.0+1`.
