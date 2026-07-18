import { FieldValue } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import {
  BookingStatus,
  cancellableStatuses,
  canTransition,
  dhakaDateKey,
  isValidDhakaDateKey,
  occupiedStatuses,
} from "./domain";
import {
  bookingIdSchema,
  cancelSchema,
  createBookingSchema,
  disputeSchema,
  parse,
  respondSchema,
} from "./schemas";
import {
  addEvent,
  assertParticipant,
  callableOptions,
  db,
  notifyUser,
  REGION,
  requireActiveUser,
  result,
} from "./shared";

function slotReference(providerId: string, dateKey: string, timeWindow: string) {
  return db.collection("provider_slots").doc(`${providerId}_${dateKey}_${timeWindow}`);
}

export const createBooking = onCall(callableOptions, async (request) => {
  const user = await requireActiveUser(request, "customer");
  const input = parse(createBookingSchema, request.data);
  if (!isValidDhakaDateKey(input.dateKey) || input.dateKey <= dhakaDateKey()) {
    throw new HttpsError("invalid-argument", "Choose a future service date.");
  }

  const serviceRef = db.collection("services").doc(input.serviceId);
  const serviceSnapshot = await serviceRef.get();
  if (!serviceSnapshot.exists) throw new HttpsError("not-found", "Service not found.");
  const service = serviceSnapshot.data()!;
  if (service.status !== "active") throw new HttpsError("failed-precondition", "Service is not active.");
  if (!Array.isArray(service.areaKeys) || !service.areaKeys.includes(input.serviceAreaKey)) {
    throw new HttpsError("invalid-argument", "The provider does not cover that service area.");
  }
  const priceBdt = Number(service.priceBdt);
  if (!Number.isInteger(priceBdt) || priceBdt <= 0) {
    throw new HttpsError("failed-precondition", "Service price is invalid.");
  }

  const providerId = String(service.providerId);
  const [providerProfileSnapshot, providerUserSnapshot] = await Promise.all([
    db.collection("provider_profiles").doc(providerId).get(),
    db.collection("users").doc(providerId).get(),
  ]);
  if (!providerProfileSnapshot.exists || providerProfileSnapshot.data()!.approvalStatus !== "approved") {
    throw new HttpsError("failed-precondition", "Provider is not approved.");
  }
  if (!providerUserSnapshot.exists || providerUserSnapshot.data()!.status !== "active") {
    throw new HttpsError("failed-precondition", "Provider account is not active.");
  }

  const areaIndex = (service.areaKeys as string[]).indexOf(input.serviceAreaKey);
  const areaLabel = String((service.areaLabels as string[])[areaIndex] ?? input.serviceAreaKey);
  const bookingRef = db.collection("bookings").doc();
  const contactRef = bookingRef.collection("private").doc("contact");
  const eventRef = bookingRef.collection("events").doc();
  const batch = db.batch();
  batch.create(bookingRef, {
    customerId: user.uid,
    providerId,
    serviceId: input.serviceId,
    customerName: user.displayName,
    providerName: String(service.providerName ?? providerProfileSnapshot.data()!.publicName ?? "Provider"),
    serviceTitle: String(service.title ?? "Home service"),
    scheduleDateKey: input.dateKey,
    timeWindow: input.timeWindow,
    divisionCode: String(providerProfileSnapshot.data()!.divisionCode ?? ""),
    districtCode: String(service.districtCode ?? ""),
    areaLabel,
    areaKey: input.serviceAreaKey,
    priceBdt,
    status: "pending",
    paymentStatus: "unpaid",
    notes: input.notes,
    contactReleasedAt: null,
    cancellation: null,
    dispute: null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  batch.create(contactRef, {
    customerPhone: user.phoneE164,
    providerPhone: String(providerUserSnapshot.data()!.phoneE164 ?? ""),
    address: input.address,
    landmark: input.landmark,
  });
  batch.create(eventRef, {
    type: "pending",
    actorId: user.uid,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  await notifyUser(
    providerId,
    "New booking request",
    `${user.displayName} requested ${String(service.title)} on ${input.dateKey}.`,
    "booking",
    `/booking/${bookingRef.id}`,
  );
  return result(bookingRef.id, "pending");
});

export const respondToBooking = onCall(callableOptions, async (request) => {
  const user = await requireActiveUser(request, "provider");
  const input = parse(respondSchema, request.data);
  const bookingRef = db.collection("bookings").doc(input.bookingId);
  let customerId = "";
  let serviceTitle = "";
  const nextStatus: BookingStatus = input.decision === "accept" ? "accepted" : "rejected";
  if (nextStatus === "rejected" && !input.reason?.trim()) {
    throw new HttpsError("invalid-argument", "A rejection reason is required.");
  }

  await db.runTransaction(async (transaction) => {
    const bookingSnapshot = await transaction.get(bookingRef);
    if (!bookingSnapshot.exists) throw new HttpsError("not-found", "Booking not found.");
    const booking = bookingSnapshot.data()!;
    if (booking.providerId !== user.uid) throw new HttpsError("permission-denied", "This booking belongs to another provider.");
    if (booking.status !== "pending" || !canTransition("pending", nextStatus)) {
      throw new HttpsError("failed-precondition", "This booking is no longer pending.");
    }

    if (nextStatus === "accepted") {
      const slotRef = slotReference(user.uid, String(booking.scheduleDateKey), String(booking.timeWindow));
      const slotSnapshot = await transaction.get(slotRef);
      if (slotSnapshot.exists && slotSnapshot.data()?.bookingId !== bookingRef.id) {
        throw new HttpsError("already-exists", "You already have a booking in this time window.");
      }
      const conflicts = db
        .collection("bookings")
        .where("providerId", "==", user.uid)
        .where("scheduleDateKey", "==", booking.scheduleDateKey)
        .where("timeWindow", "==", booking.timeWindow)
        .where("status", "in", occupiedStatuses);
      const conflictSnapshot = await transaction.get(conflicts);
      if (conflictSnapshot.docs.some((document) => document.id !== bookingRef.id)) {
        throw new HttpsError("already-exists", "You already have a booking in this time window.");
      }
      transaction.set(slotRef, {
        providerId: user.uid,
        bookingId: bookingRef.id,
        scheduleDateKey: booking.scheduleDateKey,
        timeWindow: booking.timeWindow,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    customerId = String(booking.customerId);
    serviceTitle = String(booking.serviceTitle);
    transaction.update(bookingRef, {
      status: nextStatus,
      ...(nextStatus === "accepted"
        ? { contactReleasedAt: FieldValue.serverTimestamp() }
        : { rejection: { reason: input.reason, actorId: user.uid, createdAt: FieldValue.serverTimestamp() } }),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(bookingRef.collection("events").doc(), {
      type: nextStatus,
      actorId: user.uid,
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  await notifyUser(
    customerId,
    nextStatus === "accepted" ? "Booking accepted" : "Booking rejected",
    nextStatus === "accepted"
      ? `${user.displayName} accepted your ${serviceTitle} booking.`
      : `${user.displayName} could not accept your ${serviceTitle} booking.`,
    "booking",
    `/booking/${input.bookingId}`,
  );
  return result(input.bookingId, nextStatus);
});

async function transition(
  request: CallableRequest<unknown>,
  expected: BookingStatus,
  next: BookingStatus,
  actor: "customer" | "provider",
  extra: Record<string, unknown> = {},
): Promise<{ ok: true; id?: string; status?: string }> {
  const user = await requireActiveUser(request, actor);
  const input = parse(bookingIdSchema, request.data);
  const reference = db.collection("bookings").doc(input.bookingId);
  let recipientId = "";
  let serviceTitle = "";
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) throw new HttpsError("not-found", "Booking not found.");
    const data = snapshot.data()!;
    if (data[`${actor}Id`] !== user.uid) throw new HttpsError("permission-denied", "You cannot perform this action.");
    if (data.status !== expected || !canTransition(expected, next)) {
      throw new HttpsError("failed-precondition", `Booking must be ${expected} for this action.`);
    }
    recipientId = actor === "customer" ? String(data.providerId) : String(data.customerId);
    serviceTitle = String(data.serviceTitle);
    transaction.update(reference, {
      status: next,
      ...extra,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(reference.collection("events").doc(), {
      type: next,
      actorId: user.uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    if (next === "completed") {
      transaction.delete(slotReference(String(data.providerId), String(data.scheduleDateKey), String(data.timeWindow)));
    }
  });
  await notifyUser(
    recipientId,
    bookingNotificationTitle(next),
    `${serviceTitle}: ${bookingNotificationTitle(next).toLowerCase()}.`,
    "booking",
    `/booking/${input.bookingId}`,
  );
  return result(input.bookingId, next);
}

export const startBooking = onCall(callableOptions, async (request) =>
  transition(request, "accepted", "inProgress", "provider"),
);

export const requestCompletion = onCall(callableOptions, async (request) =>
  transition(request, "inProgress", "completionRequested", "provider"),
);

export const confirmCompletion = onCall(callableOptions, async (request) =>
  transition(request, "completionRequested", "completed", "customer", {
    paymentStatus: "paidCash",
    completedAt: FieldValue.serverTimestamp(),
  }),
);

export const disputeCompletion = onCall(callableOptions, async (request) => {
  const user = await requireActiveUser(request, "customer");
  const input = parse(disputeSchema, request.data);
  const reference = db.collection("bookings").doc(input.bookingId);
  let providerId = "";
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) throw new HttpsError("not-found", "Booking not found.");
    const data = snapshot.data()!;
    if (data.customerId !== user.uid) throw new HttpsError("permission-denied", "Only the customer can dispute completion.");
    if (data.status !== "completionRequested") {
      throw new HttpsError("failed-precondition", "Completion is not awaiting confirmation.");
    }
    providerId = String(data.providerId);
    transaction.update(reference, {
      status: "disputed",
      paymentStatus: "disputed",
      dispute: { reason: input.reason, details: input.details, actorId: user.uid, createdAt: FieldValue.serverTimestamp() },
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(reference.collection("events").doc(), {
      type: "disputed",
      actorId: user.uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.delete(slotReference(String(data.providerId), String(data.scheduleDateKey), String(data.timeWindow)));
  });
  await notifyUser(providerId, "Booking disputed", "The customer requested support for this booking.", "moderation", `/booking/${input.bookingId}`);
  return result(input.bookingId, "disputed");
});

export const cancelBooking = onCall(callableOptions, async (request) => {
  const user = await requireActiveUser(request);
  const input = parse(cancelSchema, request.data);
  const reference = db.collection("bookings").doc(input.bookingId);
  let recipientId = "";
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) throw new HttpsError("not-found", "Booking not found.");
    const data = snapshot.data()!;
    assertParticipant(data, user.uid);
    if (!cancellableStatuses.has(data.status as BookingStatus)) {
      throw new HttpsError("failed-precondition", "Only pending or accepted bookings can be cancelled.");
    }
    recipientId = data.customerId === user.uid ? String(data.providerId) : String(data.customerId);
    transaction.update(reference, {
      status: "cancelled",
      cancellation: {
        reason: input.reason,
        details: input.details,
        actorId: user.uid,
        createdAt: FieldValue.serverTimestamp(),
      },
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(reference.collection("events").doc(), {
      type: "cancelled",
      actorId: user.uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    if (data.status === "accepted") {
      transaction.delete(slotReference(String(data.providerId), String(data.scheduleDateKey), String(data.timeWindow)));
    }
  });
  await notifyUser(recipientId, "Booking cancelled", `${user.displayName} cancelled the booking.`, "booking", `/booking/${input.bookingId}`);
  return result(input.bookingId, "cancelled");
});

function bookingNotificationTitle(status: BookingStatus): string {
  switch (status) {
    case "inProgress": return "Work started";
    case "completionRequested": return "Confirm completion";
    case "completed": return "Booking completed";
    default: return "Booking updated";
  }
}

export const cleanupReleasedProviderSlot = onDocumentWritten(
  { document: "bookings/{bookingId}", region: REGION, maxInstances: 3 },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before?.exists) return;
    const beforeData = before.data()!;
    const afterStatus = after?.exists ? after.data()?.status as BookingStatus : null;
    if (!occupiedStatuses.includes(beforeData.status as BookingStatus) ||
        (afterStatus != null && occupiedStatuses.includes(afterStatus))) return;
    const reference = slotReference(
      String(beforeData.providerId),
      String(beforeData.scheduleDateKey),
      String(beforeData.timeWindow),
    );
    await db.runTransaction(async (transaction) => {
      const slot = await transaction.get(reference);
      if (slot.exists && slot.data()?.bookingId === before.id) transaction.delete(reference);
    });
  },
);
