import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { readFileSync } from "node:fs";
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
} from "firebase/firestore";

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
let environment: RulesTestEnvironment;
const futureDate = "2030-01-02";
const createdAt = new Date("2029-12-01T00:00:00Z");

function bookingData(status: string, overrides: Record<string, unknown> = {}) {
  return {
    customerId: "customer",
    providerId: "provider",
    serviceId: "service",
    customerName: "Customer User",
    providerName: "Provider User",
    serviceTitle: "Electrical safety inspection",
    scheduleDateKey: futureDate,
    scheduledStart: new Date("2030-01-02T02:00:00Z"),
    timeWindow: "morning",
    divisionCode: "dhaka",
    districtCode: "dhaka",
    areaLabel: "Dhanmondi",
    areaKey: "dhanmondi",
    priceBdt: 1200,
    status,
    paymentStatus: status === "completed" ? "paidCash" : "unpaid",
    notes: "Please call before arrival.",
    contactReleasedAt: status === "pending" ? null : createdAt,
    cancellation: null,
    rejection: null,
    dispute: null,
    completedAt: status === "completed" ? createdAt : null,
    lastEventId: `seed-${status}`,
    lastMessageId: null,
    lastMessageAt: null,
    lastMessageSenderId: null,
    lastMessagePreview: null,
    createdAt,
    updatedAt: createdAt,
    ...overrides,
  };
}

before(async () => {
  if (!emulatorAvailable) return;
  environment = await initializeTestEnvironment({
    projectId: "fixmate-test",
    firestore: { rules: readFileSync("../firestore.rules", "utf8") },
  });
  await environment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await setDoc(doc(firestore, "users/customer"), {
      role: "customer", status: "active", displayName: "Customer User",
      email: "customer@example.com", phoneE164: "+8801700000001",
      photoPath: null, termsVersion: "1.0", isAdultConfirmed: true,
      createdAt, updatedAt: createdAt, termsAcceptedAt: createdAt,
    });
    await setDoc(doc(firestore, "users/provider"), {
      role: "provider", status: "active", displayName: "Provider User",
      email: "provider@example.com", phoneE164: "+8801700000002",
      photoPath: null, termsVersion: "1.0", isAdultConfirmed: true,
      createdAt, updatedAt: createdAt, termsAcceptedAt: createdAt,
    });
    await setDoc(doc(firestore, "users/stranger"), {
      role: "customer", status: "active", displayName: "Stranger User",
      email: "stranger@example.com", phoneE164: "+8801700000003",
      photoPath: null, termsVersion: "1.0", isAdultConfirmed: true,
      createdAt, updatedAt: createdAt, termsAcceptedAt: createdAt,
    });
    await setDoc(doc(firestore, "provider_profiles/provider"), {
      providerId: "provider", publicName: "Provider User", avatarUrl: null,
      bio: "Experienced and careful electrical service provider.",
      experienceYears: 5, divisionCode: "dhaka", districtCode: "dhaka",
      serviceAreaLabels: ["Dhanmondi"], serviceAreaKeys: ["dhanmondi"],
      approvalStatus: "approved", ratingAverage: 0, reviewCount: 0,
      completedBookings: 0, createdAt, updatedAt: createdAt,
    });
    await setDoc(doc(firestore, "categories/electrical"), {
      name: "Electrical", iconKey: "electrical", order: 1, isActive: true,
      updatedAt: createdAt,
    });
    await setDoc(doc(firestore, "services/service"), {
      providerId: "provider", providerName: "Provider User",
      categoryId: "electrical", title: "Electrical safety inspection",
      description: "A complete home electrical safety inspection service.",
      priceBdt: 1200, coverImageUrl: null, districtCode: "dhaka",
      areaLabels: ["Dhanmondi"], areaKeys: ["dhanmondi"],
      searchTokens: ["electrical", "safety", "inspection"], status: "active",
      providerRating: 0, reviewCount: 0, createdAt, updatedAt: createdAt,
    });

    for (const [id, status] of [
      ["pending", "pending"],
      ["accepted", "accepted"],
      ["completed", "completed"],
    ]) {
      await setDoc(doc(firestore, `bookings/${id}`), bookingData(status));
      await setDoc(doc(firestore, `bookings/${id}/private/contact`), {
        customerPhone: "+8801700000001",
        providerPhone: status === "pending" ? "" : "+8801700000002",
        address: "House 1, Road 2, Dhanmondi",
        landmark: "Near the park",
      });
      await setDoc(doc(firestore, `bookings/${id}/events/seed-${status}`), {
        type: status, actorId: "customer", createdAt,
      });
    }
    await setDoc(doc(firestore, `provider_slots/provider_${futureDate}_morning`), {
      providerId: "provider", bookingId: "accepted", scheduleDateKey: futureDate,
      timeWindow: "morning", createdAt,
    });
    await setDoc(doc(firestore, "bookings/accepted/messages/existing"), {
      senderId: "customer", text: "Hello", createdAt, readAt: null,
    });
  });
});

after(async () => {
  if (emulatorAvailable) await environment.cleanup();
});

function customerDb() {
  return environment.authenticatedContext("customer", {
    email: "customer@example.com", email_verified: true,
  }).firestore();
}

function providerDb() {
  return environment.authenticatedContext("provider", {
    email: "provider@example.com", email_verified: true,
  }).firestore();
}

test("private profiles and booking contacts remain participant-scoped", { skip: !emulatorAvailable }, async () => {
  const customer = customerDb();
  const provider = providerDb();
  const stranger = environment.authenticatedContext("stranger", {
    email: "stranger@example.com", email_verified: true,
  }).firestore();
  await assertSucceeds(getDoc(doc(customer, "users/customer")));
  await assertFails(getDoc(doc(customer, "users/provider")));
  await assertFails(getDoc(doc(provider, "bookings/pending/private/contact")));
  await assertSucceeds(getDoc(doc(provider, "bookings/accepted/private/contact")));
  await assertFails(getDoc(doc(stranger, "bookings/accepted")));
});

test("customer creates a complete pending booking atomically", { skip: !emulatorAvailable }, async () => {
  const firestore = customerDb();
  const batch = writeBatch(firestore);
  const booking = doc(firestore, "bookings/new-booking");
  const event = doc(firestore, "bookings/new-booking/events/pending-event");
  const contact = doc(firestore, "bookings/new-booking/private/contact");
  batch.set(booking, {
    ...bookingData("pending", {
      lastEventId: "pending-event",
      scheduledStart: Timestamp.fromDate(new Date("2030-01-02T02:00:00Z")),
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }),
  });
  batch.set(contact, {
    customerPhone: "+8801700000001", providerPhone: "",
    address: "House 20, Dhanmondi, Dhaka", landmark: "Near lake",
  });
  batch.set(event, { type: "pending", actorId: "customer", createdAt: serverTimestamp() });
  await assertSucceeds(batch.commit());
});

test("booking status cannot be changed without its event and slot writes", { skip: !emulatorAvailable }, async () => {
  const firestore = providerDb();
  await assertFails(updateDoc(doc(firestore, "bookings/pending"), {
    status: "accepted", contactReleasedAt: serverTimestamp(),
    lastEventId: "missing", updatedAt: serverTimestamp(),
  }));
});

test("provider cannot accept a second booking in an occupied slot", { skip: !emulatorAvailable }, async () => {
  const firestore = providerDb();
  const batch = writeBatch(firestore);
  batch.update(doc(firestore, "bookings/pending"), {
    status: "accepted", contactReleasedAt: serverTimestamp(),
    lastEventId: "accepted-event", updatedAt: serverTimestamp(),
  });
  batch.update(doc(firestore, "bookings/pending/private/contact"), {
    providerPhone: "+8801700000002",
  });
  batch.set(doc(firestore, "bookings/pending/events/accepted-event"), {
    type: "accepted", actorId: "provider", createdAt: serverTimestamp(),
  });
  batch.set(doc(firestore, `provider_slots/provider_${futureDate}_morning`), {
    providerId: "provider", bookingId: "pending", scheduleDateKey: futureDate,
    timeWindow: "morning", createdAt: serverTimestamp(),
  });
  await assertFails(batch.commit());
});

test("provider accepts with contact release, event, and a unique slot", { skip: !emulatorAvailable }, async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await deleteDoc(doc(context.firestore(), `provider_slots/provider_${futureDate}_morning`));
  });
  const firestore = providerDb();
  await assertSucceeds(
    getDoc(doc(firestore, `provider_slots/provider_${futureDate}_morning`)),
  );
  const batch = writeBatch(firestore);
  batch.update(doc(firestore, "bookings/pending"), {
    status: "accepted", contactReleasedAt: serverTimestamp(),
    lastEventId: "accepted-event", updatedAt: serverTimestamp(),
  });
  batch.update(doc(firestore, "bookings/pending/private/contact"), {
    providerPhone: "+8801700000002",
  });
  batch.set(doc(firestore, "bookings/pending/events/accepted-event"), {
    type: "accepted", actorId: "provider", createdAt: serverTimestamp(),
  });
  batch.set(doc(firestore, `provider_slots/provider_${futureDate}_morning`), {
    providerId: "provider", bookingId: "pending", scheduleDateKey: futureDate,
    timeWindow: "morning", createdAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
});

test("participant sends chat only with matching booking metadata", { skip: !emulatorAvailable }, async () => {
  const firestore = customerDb();
  const batch = writeBatch(firestore);
  batch.set(doc(firestore, "bookings/accepted/messages/new-message"), {
    senderId: "customer", text: "I am ready", createdAt: serverTimestamp(), readAt: null,
  });
  batch.update(doc(firestore, "bookings/accepted"), {
    lastMessageId: "new-message", lastMessageAt: serverTimestamp(),
    lastMessageSenderId: "customer", lastMessagePreview: "I am ready",
    updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());

  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "blocks/provider/users/customer"), {
      blockedUid: "customer", createdAt,
    });
  });
  const blockedBatch = writeBatch(firestore);
  blockedBatch.set(doc(firestore, "bookings/accepted/messages/blocked-message"), {
    senderId: "customer", text: "Blocked", createdAt: serverTimestamp(), readAt: null,
  });
  blockedBatch.update(doc(firestore, "bookings/accepted"), {
    lastMessageId: "blocked-message", lastMessageAt: serverTimestamp(),
    lastMessageSenderId: "customer", lastMessagePreview: "Blocked",
    updatedAt: serverTimestamp(),
  });
  await assertFails(blockedBatch.commit());
});

test("one customer review is allowed only for a completed booking", { skip: !emulatorAvailable }, async () => {
  const firestore = customerDb();
  const review = doc(firestore, "reviews/completed");
  await assertSucceeds(setDoc(review, {
    bookingId: "completed", customerId: "customer", customerName: "Customer User",
    providerId: "provider", serviceId: "service", rating: 5,
    comment: "Excellent service", createdAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(review, { rating: 1 }));
  await assertFails(setDoc(doc(firestore, "reviews/pending"), {
    bookingId: "pending", customerId: "customer", customerName: "Customer User",
    providerId: "provider", serviceId: "service", rating: 5,
    comment: "Too early", createdAt: serverTimestamp(),
  }));
});

test("reports are create-only and limited to the other participant", { skip: !emulatorAvailable }, async () => {
  const firestore = customerDb();
  const report = doc(firestore, "reports/report-user");
  await assertSucceeds(setDoc(report, {
    reporterId: "customer", targetType: "user", targetId: "provider",
    targetUserId: "provider", bookingId: "accepted", reason: "unsafe_behavior",
    details: "", status: "open", moderationNotes: "",
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(report, { status: "dismissed" }));
});

test("deletion-pending users can remove only their own authored content", { skip: !emulatorAvailable }, async () => {
  const firestore = customerDb();
  await assertSucceeds(updateDoc(doc(firestore, "users/customer"), {
    status: "deletionPending", updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(deleteDoc(doc(firestore, "bookings/accepted/messages/existing")));
  await assertFails(deleteDoc(doc(firestore, "services/service")));
  const profile = await assertSucceeds(getDoc(doc(firestore, "users/customer")));
  assert.equal(profile.data()?.status, "deletionPending");
});
