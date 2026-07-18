import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { auth, callableOptions, db, requireActiveUser, result, storage } from "./shared";

const blockingStatuses = ["pending", "accepted", "inProgress", "completionRequested", "disputed"];

export const requestAccountDeletion = onCall(callableOptions, async (request) => {
  const user = await requireActiveUser(request);
  const authTime = Number(request.auth?.token.auth_time ?? 0);
  const ageSeconds = Math.floor(Date.now() / 1000) - authTime;
  if (authTime <= 0 || ageSeconds > 5 * 60) {
    throw new HttpsError("failed-precondition", "Sign in again before deleting your account.");
  }
  const [customerBookings, providerBookings] = await Promise.all([
    db.collection("bookings").where("customerId", "==", user.uid).where("status", "in", blockingStatuses).limit(1).get(),
    db.collection("bookings").where("providerId", "==", user.uid).where("status", "in", blockingStatuses).limit(1).get(),
  ]);
  if (!customerBookings.empty || !providerBookings.empty) {
    throw new HttpsError(
      "failed-precondition",
      "Cancel pending or accepted bookings and resolve active or disputed bookings before deleting your account.",
    );
  }
  await auth.deleteUser(user.uid);
  return result(user.uid, "deleted");
});

export async function cleanupUserData(uid: string): Promise<void> {
  const [customerBookings, providerBookings, authoredMessages, authoredReviews, services, reported, targeted] = await Promise.all([
    db.collection("bookings").where("customerId", "==", uid).get(),
    db.collection("bookings").where("providerId", "==", uid).get(),
    db.collectionGroup("messages").where("senderId", "==", uid).get(),
    db.collection("reviews").where("customerId", "==", uid).get(),
    db.collection("services").where("providerId", "==", uid).get(),
    db.collection("reports").where("reporterId", "==", uid).get(),
    db.collection("reports").where("targetUserId", "==", uid).get(),
  ]);

  const bookingUpdates = new Map<string, { ref: FirebaseFirestore.DocumentReference; data: Record<string, unknown> }>();
  for (const document of customerBookings.docs) {
    bookingUpdates.set(document.id, {
      ref: document.ref,
      data: { customerId: `deleted:${uid}`, customerName: "Deleted user", updatedAt: FieldValue.serverTimestamp() },
    });
    await document.ref.collection("private").doc("contact").set({
      customerPhone: "",
      address: "",
      landmark: "",
    }, { merge: true });
  }
  for (const document of providerBookings.docs) {
    const existing = bookingUpdates.get(document.id);
    bookingUpdates.set(document.id, {
      ref: document.ref,
      data: {
        ...existing?.data,
        providerId: `deleted:${uid}`,
        providerName: "Deleted provider",
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
    await document.ref.collection("private").doc("contact").set({ providerPhone: "" }, { merge: true });
  }

  const writeGroups: FirebaseFirestore.DocumentReference[][] = [];
  const deleteRefs = [
    ...authoredMessages.docs.map((document) => document.ref),
    ...authoredReviews.docs.map((document) => document.ref),
    ...services.docs.map((document) => document.ref),
  ];
  for (let index = 0; index < deleteRefs.length; index += 400) writeGroups.push(deleteRefs.slice(index, index + 400));
  for (const group of writeGroups) {
    const batch = db.batch();
    group.forEach((reference) => batch.delete(reference));
    await batch.commit();
  }
  for (const update of bookingUpdates.values()) await update.ref.update(update.data);
  for (const document of reported.docs) {
    await document.ref.update({ reporterId: "deleted", details: "", updatedAt: FieldValue.serverTimestamp() });
  }
  for (const document of targeted.docs) {
    await document.ref.update({ targetUserId: "deleted", targetId: document.data().targetType === "user" ? "deleted" : document.data().targetId, updatedAt: FieldValue.serverTimestamp() });
  }

  await Promise.all([
    db.recursiveDelete(db.collection("notifications").doc(uid)),
    db.recursiveDelete(db.collection("device_tokens").doc(uid)),
    db.recursiveDelete(db.collection("blocks").doc(uid)),
    db.collection("message_rate_limits").doc(uid).delete(),
    db.collection("provider_profiles").doc(uid).delete(),
    db.collection("users").doc(uid).delete(),
  ]);

  const bucket = storage.bucket();
  await Promise.allSettled([
    bucket.deleteFiles({ prefix: `users/${uid}/` }),
    bucket.deleteFiles({ prefix: `services/${uid}/` }),
  ]);
}
