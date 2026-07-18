import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { chatStatuses } from "./domain";
import { bookingIdSchema, messageSchema, parse } from "./schemas";
import { assertParticipant, callableOptions, db, notifyUser, requireActiveUser, result } from "./shared";

export const checkCommunication = onCall(callableOptions, async (request) => {
  const user = await requireActiveUser(request);
  const input = parse(bookingIdSchema, request.data);
  const bookingSnapshot = await db.collection("bookings").doc(input.bookingId).get();
  if (!bookingSnapshot.exists) throw new HttpsError("not-found", "Booking not found.");
  const booking = bookingSnapshot.data()!;
  assertParticipant(booking, user.uid);
  if (booking.contactReleasedAt == null) {
    throw new HttpsError("failed-precondition", "Contact details are not available yet.");
  }
  const recipientId = booking.customerId === user.uid ? String(booking.providerId) : String(booking.customerId);
  const [outgoingBlock, incomingBlock] = await Promise.all([
    db.collection("blocks").doc(user.uid).collection("users").doc(recipientId).get(),
    db.collection("blocks").doc(recipientId).collection("users").doc(user.uid).get(),
  ]);
  return result(input.bookingId, outgoingBlock.exists || incomingBlock.exists ? "blocked" : "allowed");
});

export const sendMessage = onCall(callableOptions, async (request) => {
  const user = await requireActiveUser(request);
  const input = parse(messageSchema, request.data);
  const bookingRef = db.collection("bookings").doc(input.bookingId);
  const bookingSnapshot = await bookingRef.get();
  if (!bookingSnapshot.exists) throw new HttpsError("not-found", "Booking not found.");
  const booking = bookingSnapshot.data()!;
  assertParticipant(booking, user.uid);
  if (!chatStatuses.has(booking.status)) {
    throw new HttpsError("failed-precondition", "Chat is not open for this booking.");
  }
  const recipientId = booking.customerId === user.uid ? String(booking.providerId) : String(booking.customerId);
  const [outgoingBlock, incomingBlock] = await Promise.all([
    db.collection("blocks").doc(user.uid).collection("users").doc(recipientId).get(),
    db.collection("blocks").doc(recipientId).collection("users").doc(user.uid).get(),
  ]);
  if (outgoingBlock.exists || incomingBlock.exists) {
    throw new HttpsError("permission-denied", "Messaging is unavailable because one participant blocked the other.");
  }

  const rateRef = db.collection("message_rate_limits").doc(user.uid);
  await db.runTransaction(async (transaction) => {
    const rateSnapshot = await transaction.get(rateRef);
    const now = Timestamp.now();
    const current = rateSnapshot.data();
    const windowStart = current?.windowStart instanceof Timestamp ? current.windowStart as Timestamp : null;
    const sameWindow = windowStart != null && now.toMillis() - windowStart.toMillis() < 60_000;
    const count = sameWindow ? Number(current?.count ?? 0) : 0;
    if (count >= 30) throw new HttpsError("resource-exhausted", "Message limit reached. Wait a minute and try again.");
    transaction.set(rateRef, {
      windowStart: sameWindow ? windowStart : now,
      count: count + 1,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  const messageRef = bookingRef.collection("messages").doc();
  await messageRef.set({
    senderId: user.uid,
    text: input.text,
    createdAt: FieldValue.serverTimestamp(),
    readAt: null,
  });
  await notifyUser(recipientId, user.displayName, input.text, "message", `/booking/${input.bookingId}/chat`);
  return result(messageRef.id);
});
