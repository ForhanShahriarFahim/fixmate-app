import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { parse, reviewSchema } from "./schemas";
import { REGION, callableOptions, db, notifyUser, requireActiveUser, result } from "./shared";

export const submitReview = onCall(callableOptions, async (request) => {
  const user = await requireActiveUser(request, "customer");
  const input = parse(reviewSchema, request.data);
  const bookingRef = db.collection("bookings").doc(input.bookingId);
  const reviewRef = db.collection("reviews").doc(input.bookingId);
  let providerId = "";
  await db.runTransaction(async (transaction) => {
    const [bookingSnapshot, reviewSnapshot] = await Promise.all([
      transaction.get(bookingRef),
      transaction.get(reviewRef),
    ]);
    if (!bookingSnapshot.exists) throw new HttpsError("not-found", "Booking not found.");
    const booking = bookingSnapshot.data()!;
    if (booking.customerId !== user.uid) throw new HttpsError("permission-denied", "Only the customer can review this booking.");
    if (booking.status !== "completed") throw new HttpsError("failed-precondition", "Complete the booking before reviewing.");
    if (reviewSnapshot.exists) throw new HttpsError("already-exists", "This booking already has a review.");
    providerId = String(booking.providerId);
    transaction.create(reviewRef, {
      bookingId: input.bookingId,
      customerId: user.uid,
      customerName: user.displayName,
      providerId,
      serviceId: booking.serviceId,
      rating: input.rating,
      comment: input.comment,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  await notifyUser(providerId, "New review", `${user.displayName} left a ${input.rating}-star review.`, "review", `/booking/${input.bookingId}`);
  return result(input.bookingId, "published");
});

export const recalculateProviderRating = onDocumentWritten(
  { document: "reviews/{bookingId}", region: REGION, maxInstances: 3 },
  async (event) => {
    const after = event.data?.after;
    const before = event.data?.before;
    const providerId = String((after?.exists ? after.data()?.providerId : before?.data()?.providerId) ?? "");
    if (!providerId) return;

    const reviews = await db.collection("reviews").where("providerId", "==", providerId).get();
    const count = reviews.size;
    const average = count === 0
      ? 0
      : reviews.docs.reduce((total, document) => total + Number(document.data().rating ?? 0), 0) / count;
    const completedCount = await db
      .collection("bookings")
      .where("providerId", "==", providerId)
      .where("status", "==", "completed")
      .count()
      .get();
    const providerRef = db.collection("provider_profiles").doc(providerId);
    if ((await providerRef.get()).exists) {
      await providerRef.update({
        ratingAverage: Math.round(average * 100) / 100,
        reviewCount: count,
        completedBookings: completedCount.data().count,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    const services = await db.collection("services").where("providerId", "==", providerId).get();
    for (let start = 0; start < services.docs.length; start += 450) {
      const batch = db.batch();
      for (const document of services.docs.slice(start, start + 450)) {
        batch.update(document.ref, {
          providerRating: Math.round(average * 100) / 100,
          reviewCount: count,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  },
);

export const refreshProviderCompletedCount = onDocumentWritten(
  { document: "bookings/{bookingId}", region: REGION, maxInstances: 3 },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    const beforeProvider = before?.exists ? String(before.data()?.providerId ?? "") : "";
    const afterProvider = after?.exists ? String(after.data()?.providerId ?? "") : "";
    const wasCompleted = before?.exists && before.data()?.status === "completed";
    const isCompleted = after?.exists && after.data()?.status === "completed";
    if (beforeProvider === afterProvider && wasCompleted === isCompleted) return;

    const providerIds = new Set([beforeProvider, afterProvider]);
    providerIds.delete("");
    for (const providerId of providerIds) {
      const providerRef = db.collection("provider_profiles").doc(providerId);
      if (!(await providerRef.get()).exists) continue;
      const completed = await db
        .collection("bookings")
        .where("providerId", "==", providerId)
        .where("status", "==", "completed")
        .count()
        .get();
      await providerRef.update({
        completedBookings: completed.data().count,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  },
);
