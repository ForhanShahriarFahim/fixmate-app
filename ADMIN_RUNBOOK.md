# FixMate administration runbook

The maintained Spark-plan administrator, provider-review, moderation, and
account-deletion instructions are in
[`docs/ADMIN_RUNBOOK.md`](docs/ADMIN_RUNBOOK.md).

FixMate uses trusted `admins/{uid}` Firestore membership. There is no public
admin registration and no hardcoded administrator email, UID, or password.
The reviewed Security Rules and first administrator membership are active in
Firebase project `fixmate-ce36d`; operational evidence is maintained in the
linked runbook and `docs/FINALIZATION_PLAN.md`.
