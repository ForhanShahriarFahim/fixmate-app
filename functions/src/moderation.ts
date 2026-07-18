import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { blockSchema, parse, reportSchema } from "./schemas";
import { assertParticipant, callableOptions, db, notifyUser, requireActiveUser, result } from "./shared";

export const submitReport = onCall(callableOptions, async (request) => {
  const user = await requireActiveUser(request);
  const input = parse(reportSchema, request.data);
  const bookingSnapshot = await db.collection("bookings").doc(input.bookingId).get();
  if (!bookingSnapshot.exists) throw new HttpsError("not-found", "Booking not found.");
  const booking = bookingSnapshot.data()!;
  assertParticipant(booking, user.uid);
  const otherUid = booking.customerId === user.uid ? String(booking.providerId) : String(booking.customerId);

  if (input.targetType === "user" && input.targetId !== otherUid) {
    throw new HttpsError("invalid-argument", "Only the other booking participant can be reported.");
  }
  if (input.targetType === "message") {
    const message = await db.collection("bookings").doc(input.bookingId).collection("messages").doc(input.targetId).get();
    if (!message.exists || message.data()!.senderId !== otherUid) {
      throw new HttpsError("invalid-argument", "Reported message is invalid.");
    }
  }

  const reference = db.collection("reports").doc();
  await reference.set({
    reporterId: user.uid,
    targetType: input.targetType,
    targetId: input.targetId,
    targetUserId: otherUid,
    bookingId: input.bookingId,
    reason: input.reason,
    details: input.details,
    status: "open",
    moderationNotes: "",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await notifyUser(user.uid, "Report received", "FixMate support will review your report.", "moderation", `/booking/${input.bookingId}`);
  return result(reference.id, "open");
});

export const setUserBlocked = onCall(callableOptions, async (request) => {
  const user = await requireActiveUser(request);
  const input = parse(blockSchema, request.data);
  if (input.targetUid === user.uid) throw new HttpsError("invalid-argument", "You cannot block yourself.");
  const target = await db.collection("users").doc(input.targetUid).get();
  if (!target.exists) throw new HttpsError("not-found", "User not found.");
  const reference = db.collection("blocks").doc(user.uid).collection("users").doc(input.targetUid);
  if (input.blocked) {
    await reference.set({ blockedUid: input.targetUid, createdAt: FieldValue.serverTimestamp() });
  } else {
    await reference.delete();
  }
  return result(input.targetUid, input.blocked ? "blocked" : "unblocked");
});

