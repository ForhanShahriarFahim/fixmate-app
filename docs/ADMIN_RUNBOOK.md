# FixMate Spark administration runbook

FixMate now contains a minimal Android administrator review interface. It uses
Firestore `admins/{uid}` membership; it does **not** trust a role stored in
`users/{uid}`, an email address, or local device state.

The administrator interface is implemented in the current application. The
revised Security Rules were explicitly deployed to Firebase project
`fixmate-ce36d` on 6 August 2026, and the first trusted administrator membership
was created for the project's only verified Authentication account. The live
membership contains `active: true` and `displayName: "FixMate Administrator"`.
Firebase Console rejected the nonessential `createdAt` timestamp field, so do
not claim that audit field exists on the first membership.

## Bootstrap the first administrator

There is intentionally no Register as admin option.

1. In Firebase Authentication for project `fixmate-ce36d`, create or identify
   the email/password account owned by the administrator.
2. Ensure that account controls its email and completes Firebase email
   verification. An account created in Firebase Console can sign into FixMate,
   use the verification screen to resend the verification email, and then
   verify it.
3. Copy the exact Firebase Authentication UID. Do not copy an email address
   into a UID field.
4. In Firestore Console, create document `admins/{uid}` with:
   - `active` (Boolean): `true`
   - `displayName` (String): the administrator's non-sensitive display label
   - `createdAt` (Timestamp): recommended current console time; this audit field
     is not used to authorize the administrator
5. After the revised Rules have been explicitly reviewed and deployed, sign in
   through FixMate's normal login screen. Admin membership is resolved before
   an ordinary `users/{uid}` profile, so an administrator does not need a
   customer/provider profile.
6. Confirm that the app opens **Provider reviews**, can read only authorized
   pending applications, and can sign out.

Creating or changing `admins/{uid}` from the FixMate client is always denied.
An admin cannot review a provider profile with the same UID, preventing
self-review. To revoke access, an authorized Firebase operator sets `active`
to `false` or removes the membership document through Firebase Console.

## Provider review

The dashboard lists pending `provider_profiles` and shows the matching private
`users/{uid}` record only to an authorized administrator. Before approval,
verify:

- the user role is `provider` and account status is `active`;
- email verification in Firebase Authentication;
- registered name and Bangladesh phone number;
- biography, experience, division, district, and service-area coverage.

Approve writes `approvalStatus: approved`, `marketplaceVisible: true`,
`reviewedAt` using a server timestamp, `reviewedBy` using the signed-in admin
UID, an empty `rejectionReason`, and `updatedAt` using a server timestamp.

Reject requires provider-facing feedback of 3–500 characters and writes
`approvalStatus: rejected`, `marketplaceVisible: false`, and the same protected
review audit fields. Providers can see the rejection reason and explicitly edit
and resubmit. Any provider-authored profile edit clears prior review fields and
returns the profile to pending/hidden; providers cannot approve themselves,
make themselves visible, or write admin membership.

## Service categories

An active administrator can open **Provider reviews → Manage service
categories**.

- Add a category with an immutable lowercase slug, public name, supported icon,
  display order, and active state.
- Edit the name, icon, order, or active state from the category actions menu.
- Deactivation requires confirmation. It removes the category from provider
  create/edit selection; providers editing an affected listing must choose an
  active category. Existing listings are not silently deleted or rewritten.
- Delete is permanent and is available only after deactivation. The app checks
  Firestore on the server and refuses deletion while any active or archived
  service references the category ID. Reassign every referenced service first.
  Firestore Rules independently require an active administrator and inactive
  category; providers cannot create a new reference after deactivation.
- Category IDs must remain stable because services store the ID. Do not reuse an
  old ID for an unrelated type of work.

Provider category choices come from active `categories` documents, so an active
administrator-created category appears without an application release. Rules,
not the admin UI, enforce authority and field validation.

Category deletion was coded, emulator-tested, and deployed through an explicitly
authorized Rules-only release on 6 August 2026. The live Rules source was read
back and verified against repository SHA-256
`912BF14253AA3EE4CB94179BCC235F0A6D56E83AD5332DC90E659C2B91E4AF83`.

## Suspension

To suspend a provider through Firebase Console, first set
`provider_profiles/{uid}.marketplaceVisible` to `false`, then set
`users/{uid}.status` to `suspended`. Existing history remains readable, while
new marketplace mutations are denied. In-progress, completion-requested, and
disputed work requires support handling.

## Reports and disputes

- Review `reports` where `status == open`.
- Do not reveal reporter details to the reported user.
- Record only necessary moderation notes and change status to `reviewing`,
  `resolved`, or `dismissed` through Firebase Console.
- Preserve disputed booking data before any operator correction. The current
  admin interface does not edit bookings, reports, disputes, or user status.

## Account-deletion requests

The app creates `deletion_requests/{uid}` and atomically changes
`users/{uid}.status` to `deletionPending`. Spark has no trusted automatic
cleanup in this repository. An authorized operator must complete the following
restartable process before deleting the Authentication identity:

1. Verify the requester and confirm there are no pending, accepted,
   in-progress, completion-requested, or disputed bookings for either role.
2. Set the request status to `cleanupInProgress` and update `updatedAt`.
3. For providers, set `marketplaceVisible` to `false` and archive their
   services before removing the public provider profile.
4. Remove authored messages and reviews. Review aggregates are calculated from
   the remaining reviews, so recheck affected provider statistics afterward.
5. Anonymize the user's name/contact snapshots in retained bookings and remove
   private address/phone values. Retain only operational data permitted by the
   reviewed privacy policy.
6. Remove the private user profile and outgoing block records. Minimize or
   anonymize incoming blocks, reports, and moderation records as the reviewed
   retention policy requires.
7. Delete the Firebase Authentication identity only after required cleanup is
   verified.
8. Set the deletion request to `completed`, clear `failureMessage`, and update
   `updatedAt`. Retain only the minimum pseudonymous audit marker permitted by
   the reviewed policy.

If any step fails, leave the Authentication identity intact when practical,
set the request to `cleanupFailed`, record a non-sensitive failure summary, and
resume from the last verified step. Never mark a request complete merely
because marketplace access was disabled. For an email request, verify control
of the registered email, then create the same deletion request and
`deletionPending` state through Firebase Console before following these steps.

Never store a service-account key, Admin SDK credential, App Check debug token,
password, signing credential, or administrator UID in source control.
