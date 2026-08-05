# FixMate Spark Administration Runbook

This runbook is for the first Android internal-testing release. Administration
is manual in Firebase Console because Cloud Functions and Admin credentials are
deliberately excluded. Console actions are **configured operations**, not coded
or automatically verified behavior.

## Provider approval and suspension

1. Verify the provider's `users/{uid}` record is active, email-verified in
   Firebase Authentication, and has role `provider`.
2. Review `provider_profiles/{uid}` and its coverage.
3. Approve by setting `approvalStatus` to `approved` and
   `marketplaceVisible` to `true` in one Console edit.
4. To reject, set `marketplaceVisible` to `false` first, then set
   `approvalStatus` to `rejected`.
5. To suspend, set `provider_profiles/{uid}.marketplaceVisible` to `false`
   before setting `users/{uid}.status` to `suspended`.

The official Flutter catalog filters against the live provider profile. Rules
also reject new bookings and provider actions unless the account is active and
the profile is both approved and visible. Existing booking history remains
readable. Customers may cancel pending or accepted bookings; in-progress,
completion-requested, and disputed work requires support handling.

Any provider-authored public profile edit resets the profile to `pending` and
`marketplaceVisible: false`. Re-review it before restoring visibility.

## Reports and disputes

- Review new documents in `reports` where `status == open`.
- Do not reveal reporter details to the reported user.
- Record only necessary moderation notes and change status to `reviewing`,
  `resolved`, or `dismissed` through the Console.
- For a disputed booking, preserve its current data before any correction.
  If an administrator resolves status manually, also add a corresponding
  immutable booking event with actor `admin` and document the decision outside
  the app. There is no automatic administrator workflow in this release.

## Account-deletion requests

The application creates `deletion_requests/{uid}` and changes
`users/{uid}.status` to `deletionPending` atomically. It does not delete data or
the Authentication identity.

1. Verify the requester and confirm there are no pending, accepted,
   in-progress, completion-requested, or disputed bookings for either role.
2. Set the request status to `cleanupInProgress` and update `updatedAt`.
3. For providers, set `marketplaceVisible` to `false` and archive their
   services before removing the public provider profile.
4. Remove the user's authored messages and reviews. Review aggregates are
   computed directly from remaining immutable reviews, so no stored rating
   field requires repair.
5. Anonymize the user's name and contact fields in retained booking snapshots
   and remove private address/phone values. Preserve only operational status,
   price, schedule, and moderation data that the publisher's reviewed policy
   permits retaining.
6. Remove the private user profile and outgoing block records. Review incoming
   blocks and reports for the minimum necessary anonymization.
7. Delete the Firebase Authentication identity **after** required cleanup is
   complete.
8. Set the deletion request to `completed`, clear `failureMessage`, and update
   `updatedAt`. Retain only the minimum pseudonymous marker allowed by the
   reviewed privacy policy.

If any step fails, leave the Authentication identity intact when possible, set
the request to `cleanupFailed`, record a non-sensitive failure summary, and
resume from the last verified step. Never mark a request completed merely
because marketplace access is disabled.

For an email request, verify control of the registered email, then create the
same deletion request and `deletionPending` account state through the Console
before following the steps above.

## Release cautions

- Never put a service-account key, Admin SDK credential, App Check debug token,
  password, or signing credential in this repository or FlutLab.
- Firebase Console changes must be performed by an authorized publisher and
  recorded for the internal test.
- This runbook requires publisher and legal review before Play submission.
