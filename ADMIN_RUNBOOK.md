# FixMate administration runbook

Administration is performed through Firebase Console for the first beta.

## Provider applications

- Review `provider_profiles` where `approvalStatus == pending`.
- Compare the submitted public profile with the phone in `users/{uid}`.
- Set `approvalStatus` to `approved` or `rejected`; never change `providerId` or rating fields manually.

## Reports and disputes

- Review `reports` where `status == open`.
- Read only the referenced booking/message required to investigate.
- Update `status` to `reviewing`, then `resolved` or `dismissed`; record concise `moderationNotes` without copying unnecessary personal data.
- For a confirmed policy breach, set `users/{uid}.status` to `suspended`.
- A `disputed` booking is terminal in the app. After support resolves it, record the resolution in moderation notes. A future admin UI may add controlled state resolution; do not casually edit financial/status history.

## External account deletion

1. Require the request from the registered email and verify ownership.
2. Check that no booking is pending, accepted, in progress, awaiting completion, or disputed.
3. Resolve or cancel eligible bookings first.
4. Delete the Authentication user individually in Firebase Console. Do not bulk delete: individual deletion triggers `cleanupDeletedAuthUser`.
5. Confirm that the private user/profile data and Storage prefixes were removed. Review Cloud Functions logs if cleanup fails.

## Operational checks

- Review Crashlytics for new fatal issues before promoting a build.
- Review Functions error rate, invocation count, and billing alerts weekly during beta.
- Keep App Check in monitoring until internal Android builds show valid Play Integrity traffic, then enforce it deliberately.
- Never put service-account JSON, Firebase Admin credentials, or private API keys in GitHub or FlutLab source.

