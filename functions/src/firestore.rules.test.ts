import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { readFileSync } from "node:fs";
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, serverTimestamp, setDoc } from "firebase/firestore";

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
let environment: RulesTestEnvironment;

before(async () => {
  if (!emulatorAvailable) return;
  environment = await initializeTestEnvironment({
    projectId: "fixmate-test",
    firestore: { rules: readFileSync("../firestore.rules", "utf8") },
  });
  await environment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    const { setDoc } = await import("firebase/firestore");
    await setDoc(doc(firestore, "users/customer"), {
      role: "customer", status: "active", displayName: "Customer", createdAt: new Date(),
      termsAcceptedAt: new Date(), isAdultConfirmed: true,
    });
    await setDoc(doc(firestore, "users/provider"), {
      role: "provider", status: "active", displayName: "Provider", createdAt: new Date(),
      termsAcceptedAt: new Date(), isAdultConfirmed: true,
    });
    await setDoc(doc(firestore, "bookings/booking"), {
      customerId: "customer", providerId: "provider", status: "pending", contactReleasedAt: null,
    });
    await setDoc(doc(firestore, "bookings/booking/private/contact"), { address: "Private address" });
    await setDoc(doc(firestore, "bookings/accepted"), {
      customerId: "customer", providerId: "provider", status: "accepted", contactReleasedAt: new Date(),
    });
    await setDoc(doc(firestore, "bookings/accepted/private/contact"), { address: "Released address" });
    await setDoc(doc(firestore, "bookings/accepted/messages/message"), {
      senderId: "customer", text: "Hello", createdAt: new Date(), readAt: null,
    });
    await setDoc(doc(firestore, "notifications/customer/items/notice"), {
      title: "Update", body: "Booking updated", type: "booking", route: "/booking/accepted",
      readAt: null, createdAt: new Date(),
    });
    await setDoc(doc(firestore, "reports/report"), {
      reporterId: "customer", targetUserId: "provider", status: "open",
    });
  });
});

after(async () => {
  if (emulatorAvailable) await environment.cleanup();
});

test("users can read only their own private profile", { skip: !emulatorAvailable }, async () => {
  const customer = environment.authenticatedContext("customer", { email_verified: true }).firestore();
  await assertSucceeds(getDoc(doc(customer, "users/customer")));
  await assertFails(getDoc(doc(customer, "users/provider")));
});

test("provider contact access is denied before acceptance", { skip: !emulatorAvailable }, async () => {
  const provider = environment.authenticatedContext("provider", { email_verified: true }).firestore();
  await assertFails(getDoc(doc(provider, "bookings/booking/private/contact")));
});

test("customer always reads their booking contact", { skip: !emulatorAvailable }, async () => {
  const customer = environment.authenticatedContext("customer", { email_verified: true }).firestore();
  const snapshot = await assertSucceeds(getDoc(doc(customer, "bookings/booking/private/contact")));
  assert.equal(snapshot.data()?.address, "Private address");
});

test("accepted provider can read released contact and participant chat", { skip: !emulatorAvailable }, async () => {
  const provider = environment.authenticatedContext("provider", { email_verified: true }).firestore();
  const contact = await assertSucceeds(getDoc(doc(provider, "bookings/accepted/private/contact")));
  const message = await assertSucceeds(getDoc(doc(provider, "bookings/accepted/messages/message")));
  assert.equal(contact.data()?.address, "Released address");
  assert.equal(message.data()?.text, "Hello");
});

test("unrelated accounts cannot read bookings, chat, notifications, or reports", { skip: !emulatorAvailable }, async () => {
  const stranger = environment.authenticatedContext("stranger", { email_verified: true }).firestore();
  await assertFails(getDoc(doc(stranger, "bookings/accepted")));
  await assertFails(getDoc(doc(stranger, "bookings/accepted/messages/message")));
  await assertFails(getDoc(doc(stranger, "notifications/customer/items/notice")));
  await assertFails(getDoc(doc(stranger, "reports/report")));
});

test("clients cannot write booking messages directly", { skip: !emulatorAvailable }, async () => {
  const customer = environment.authenticatedContext("customer", { email_verified: true }).firestore();
  await assertFails(setDoc(doc(customer, "bookings/accepted/messages/client-message"), {
    senderId: "customer", text: "Bypass", createdAt: serverTimestamp(), readAt: null,
  }));
});

test("a user can register only a well-formed token under their own uid", { skip: !emulatorAvailable }, async () => {
  const customer = environment.authenticatedContext("customer", { email_verified: true }).firestore();
  await assertSucceeds(setDoc(doc(customer, "device_tokens/customer/tokens/device"), {
    token: "a-valid-firebase-token-value", platform: "android", updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(customer, "device_tokens/provider/tokens/device"), {
    token: "a-valid-firebase-token-value", platform: "android", updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(customer, "device_tokens/customer/tokens/invalid"), {
    token: "short", platform: "android", updatedAt: serverTimestamp(),
  }));
});
