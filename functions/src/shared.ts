import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, Firestore, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { NotificationType, UserRole } from "./domain";

if (getApps().length === 0) initializeApp();

export const db = getFirestore();
export const auth = getAuth();
export const messaging = getMessaging();
export const storage = getStorage();
export const REGION = "asia-south1";
export const CURRENT_TERMS_VERSION = "1.0";
export const callableOptions = {
  region: REGION,
  maxInstances: 3,
  memory: "256MiB" as const,
  concurrency: 20,
  enforceAppCheck: false,
};

export interface ActiveUser {
  uid: string;
  role: UserRole;
  displayName: string;
  email: string;
  phoneE164: string;
}

export async function requireActiveUser(request: CallableRequest<unknown>, role?: UserRole): Promise<ActiveUser> {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in to continue.");
  if (request.auth.token.email_verified !== true) {
    throw new HttpsError("failed-precondition", "Verify your email first.");
  }
  const snapshot = await db.collection("users").doc(request.auth.uid).get();
  if (!snapshot.exists) throw new HttpsError("failed-precondition", "User profile is missing.");
  const data = snapshot.data()!;
  if (data.status !== "active") throw new HttpsError("permission-denied", "This account is not active.");
  if (data.isAdultConfirmed !== true || data.termsVersion !== CURRENT_TERMS_VERSION) {
    throw new HttpsError("failed-precondition", "Accept the current Terms of Use before continuing.");
  }
  if (role && data.role !== role) throw new HttpsError("permission-denied", `A ${role} account is required.`);
  return {
    uid: request.auth.uid,
    role: data.role as UserRole,
    displayName: String(data.displayName ?? "User"),
    email: String(data.email ?? ""),
    phoneE164: String(data.phoneE164 ?? ""),
  };
}

export async function addEvent(
  firestore: Firestore,
  bookingId: string,
  type: string,
  actorId: string,
): Promise<void> {
  await firestore.collection("bookings").doc(bookingId).collection("events").add({
    type,
    actorId,
    createdAt: FieldValue.serverTimestamp(),
  });
}

export async function notifyUser(
  uid: string,
  title: string,
  body: string,
  type: NotificationType,
  route: string,
): Promise<void> {
  try {
    await db.collection("notifications").doc(uid).collection("items").add({
      title,
      body,
      type,
      route,
      readAt: null,
      createdAt: FieldValue.serverTimestamp(),
    });

    const tokensSnapshot = await db.collection("device_tokens").doc(uid).collection("tokens").get();
    const tokenDocs = tokensSnapshot.docs.filter((document) => typeof document.data().token === "string");
    if (tokenDocs.length === 0) return;
    const response = await messaging.sendEachForMulticast({
      tokens: tokenDocs.slice(0, 500).map((document) => document.data().token as string),
      notification: { title, body },
      data: { route, type },
      android: { priority: "high" },
    });
    const invalidCodes = new Set([
      "messaging/invalid-registration-token",
      "messaging/registration-token-not-registered",
    ]);
    await Promise.all(
      response.responses.map((sendResult, index) => {
        if (sendResult.error && invalidCodes.has(sendResult.error.code)) return tokenDocs[index].ref.delete();
        return Promise.resolve();
      }),
    );
  } catch (error) {
    logger.error("Notification delivery failed after a marketplace mutation.", { uid, type, route, error });
  }
}

export function assertParticipant(data: FirebaseFirestore.DocumentData, uid: string): void {
  if (data.customerId !== uid && data.providerId !== uid) {
    throw new HttpsError("permission-denied", "You are not a participant in this booking.");
  }
}

export function result(id?: string, status?: string): { ok: true; id?: string; status?: string } {
  return { ok: true, ...(id ? { id } : {}), ...(status ? { status } : {}) };
}
