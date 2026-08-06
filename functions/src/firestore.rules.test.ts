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
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
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

function providerApplicationData(overrides: Record<string, unknown> = {}) {
  return {
    providerId: "applicant",
    publicName: "Applicant User",
    avatarUrl: null,
    bio: "A qualified provider applying to join the FixMate marketplace.",
    experienceYears: 3,
    divisionCode: "dhaka",
    districtCode: "dhaka",
    serviceAreaLabels: ["Dhanmondi"],
    serviceAreaKeys: ["dhanmondi"],
    approvalStatus: "pending",
    marketplaceVisible: false,
    reviewedAt: null,
    reviewedBy: null,
    rejectionReason: "",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
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
    await setDoc(doc(firestore, "users/applicant"), {
      role: "provider", status: "active", displayName: "Applicant User",
      email: "applicant@example.com", phoneE164: "+8801700000004",
      photoPath: null, termsVersion: "1.0", isAdultConfirmed: true,
      createdAt, updatedAt: createdAt, termsAcceptedAt: createdAt,
    });
    await setDoc(doc(firestore, "users/suspended-provider"), {
      role: "provider", status: "suspended", displayName: "Suspended Provider",
      email: "suspended@example.com", phoneE164: "+8801700000005",
      photoPath: null, termsVersion: "1.0", isAdultConfirmed: true,
      createdAt, updatedAt: createdAt, termsAcceptedAt: createdAt,
    });
    await setDoc(doc(firestore, "users/suspended-customer"), {
      role: "customer", status: "suspended", displayName: "Suspended Customer",
      email: "suspended-customer@example.com", phoneE164: "+8801700000007",
      photoPath: null, termsVersion: "1.0", isAdultConfirmed: true,
      createdAt, updatedAt: createdAt, termsAcceptedAt: createdAt,
    });
    await setDoc(doc(firestore, "users/pending-review"), {
      role: "provider", status: "active", displayName: "Pending Review",
      email: "pending@example.com", phoneE164: "+8801700000008",
      photoPath: null, termsVersion: "1.0", isAdultConfirmed: true,
      createdAt, updatedAt: createdAt, termsAcceptedAt: createdAt,
    });
    await setDoc(doc(firestore, "users/pending-reject"), {
      role: "provider", status: "active", displayName: "Pending Reject",
      email: "reject@example.com", phoneE164: "+8801700000009",
      photoPath: null, termsVersion: "1.0", isAdultConfirmed: true,
      createdAt, updatedAt: createdAt, termsAcceptedAt: createdAt,
    });
    await setDoc(doc(firestore, "admins/admin"), {
      active: true, displayName: "FixMate Administrator", createdAt,
    });
    await setDoc(doc(firestore, "provider_profiles/provider"), {
      providerId: "provider", publicName: "Provider User", avatarUrl: null,
      bio: "Experienced and careful electrical service provider.",
      experienceYears: 5, divisionCode: "dhaka", districtCode: "dhaka",
      serviceAreaLabels: ["Dhanmondi"], serviceAreaKeys: ["dhanmondi"],
      approvalStatus: "approved", marketplaceVisible: true,
      reviewedAt: createdAt, reviewedBy: "seed-admin", rejectionReason: "",
      ratingAverage: 0, reviewCount: 0,
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
    await setDoc(doc(firestore, "provider_profiles/suspended-provider"), {
      providerId: "suspended-provider", publicName: "Suspended Provider", avatarUrl: null,
      bio: "This provider is not eligible to participate in the marketplace.",
      experienceYears: 5, divisionCode: "dhaka", districtCode: "dhaka",
      serviceAreaLabels: ["Dhanmondi"], serviceAreaKeys: ["dhanmondi"],
      approvalStatus: "approved", marketplaceVisible: true,
      reviewedAt: createdAt, reviewedBy: "seed-admin", rejectionReason: "",
      ratingAverage: 0, reviewCount: 0, completedBookings: 0,
      createdAt, updatedAt: createdAt,
    });
    for (const id of ["pending-review", "pending-reject"]) {
      await setDoc(doc(firestore, `provider_profiles/${id}`), {
        providerId: id, publicName: id === "pending-review" ? "Pending Review" : "Pending Reject",
        avatarUrl: null,
        bio: "A qualified provider waiting for an administrator review decision.",
        experienceYears: 4, divisionCode: "dhaka", districtCode: "dhaka",
        serviceAreaLabels: ["Dhanmondi"], serviceAreaKeys: ["dhanmondi"],
        approvalStatus: "pending", marketplaceVisible: false,
        reviewedAt: null, reviewedBy: null, rejectionReason: "",
        createdAt, updatedAt: createdAt,
      });
    }
    await setDoc(doc(firestore, "provider_profiles/admin"), {
      providerId: "admin", publicName: "Admin Applicant", avatarUrl: null,
      bio: "An administrator must not be allowed to review their own application.",
      experienceYears: 4, divisionCode: "dhaka", districtCode: "dhaka",
      serviceAreaLabels: ["Dhanmondi"], serviceAreaKeys: ["dhanmondi"],
      approvalStatus: "pending", marketplaceVisible: false,
      reviewedAt: null, reviewedBy: null, rejectionReason: "",
      createdAt, updatedAt: createdAt,
    });
    await setDoc(doc(firestore, "services/suspended-service"), {
      providerId: "suspended-provider", providerName: "Suspended Provider",
      categoryId: "electrical", title: "Suspended electrical service",
      description: "A stale listing whose provider account is currently suspended.",
      priceBdt: 900, coverImageUrl: null, districtCode: "dhaka",
      areaLabels: ["Dhanmondi"], areaKeys: ["dhanmondi"],
      searchTokens: ["suspended", "electrical"], status: "active",
      providerRating: 0, reviewCount: 0, createdAt, updatedAt: createdAt,
    });
    await setDoc(doc(firestore, "bookings/suspended-recipient"), bookingData("accepted", {
      customerId: "suspended-customer", customerName: "Suspended Customer",
      scheduleDateKey: "2030-03-01", scheduledStart: new Date("2030-03-01T02:00:00Z"),
      lastEventId: "seed-suspended-recipient",
    }));
    await setDoc(doc(firestore, "bookings/suspended-recipient/private/contact"), {
      customerPhone: "+8801700000007", providerPhone: "+8801700000002",
      address: "House 1, Road 2, Dhanmondi", landmark: "Near the park",
    });
    await setDoc(doc(firestore, "bookings/suspended-recipient/events/seed-suspended-recipient"), {
      type: "accepted", actorId: "provider", createdAt,
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
    for (const item of [
      { id: "accepted-transition", status: "accepted", date: "2030-02-01", window: "morning" },
      { id: "completion-complete", status: "completionRequested", date: "2030-02-02", window: "afternoon" },
      { id: "completion-dispute", status: "completionRequested", date: "2030-02-03", window: "evening" },
      { id: "pending-cancel", status: "pending", date: "2030-02-04", window: "morning" },
      { id: "accepted-cancel", status: "accepted", date: "2030-02-05", window: "afternoon" },
    ]) {
      await setDoc(doc(firestore, `bookings/${item.id}`), bookingData(item.status, {
        scheduleDateKey: item.date,
        scheduledStart: new Date(`${item.date}T02:00:00Z`),
        timeWindow: item.window,
        lastEventId: `seed-${item.id}`,
      }));
      await setDoc(doc(firestore, `bookings/${item.id}/private/contact`), {
        customerPhone: "+8801700000001",
        providerPhone: item.status === "pending" ? "" : "+8801700000002",
        address: "House 1, Road 2, Dhanmondi",
        landmark: "Near the park",
      });
      await setDoc(doc(firestore, `bookings/${item.id}/events/seed-${item.id}`), {
        type: item.status, actorId: "customer", createdAt,
      });
      if (item.status !== "pending") {
        await setDoc(doc(firestore, `provider_slots/provider_${item.date}_${item.window}`), {
          providerId: "provider", bookingId: item.id, scheduleDateKey: item.date,
          timeWindow: item.window, createdAt,
        });
      }
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
    auth_time: Math.floor(Date.now() / 1000),
  }).firestore();
}

function providerDb() {
  return environment.authenticatedContext("provider", {
    email: "provider@example.com", email_verified: true,
    auth_time: Math.floor(Date.now() / 1000),
  }).firestore();
}

function adminDb() {
  return environment.authenticatedContext("admin", {
    email: "admin@example.com", email_verified: true,
    auth_time: Math.floor(Date.now() / 1000),
  }).firestore();
}

test("public reads stay public while unauthenticated private access and writes are denied", { skip: !emulatorAvailable }, async () => {
  const firestore = environment.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(firestore, "services/service")));
  await assertFails(getDoc(doc(firestore, "users/customer")));
  await assertFails(setDoc(doc(firestore, "services/anonymous"), {
    providerId: "provider", status: "active",
  }));
});

test("unverified accounts cannot perform marketplace mutations", { skip: !emulatorAvailable }, async () => {
  const unverifiedCustomer = environment.authenticatedContext("customer", {
    email: "customer@example.com", email_verified: false,
  }).firestore();
  const bookingBatch = writeBatch(unverifiedCustomer);
  bookingBatch.set(doc(unverifiedCustomer, "bookings/unverified-booking"), {
    ...bookingData("pending", {
      lastEventId: "unverified-event",
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }),
  });
  bookingBatch.set(doc(unverifiedCustomer, "bookings/unverified-booking/private/contact"), {
    customerPhone: "+8801700000001", providerPhone: "",
    address: "House 20, Dhanmondi, Dhaka", landmark: "Near lake",
  });
  bookingBatch.set(doc(unverifiedCustomer, "bookings/unverified-booking/events/unverified-event"), {
    type: "pending", actorId: "customer", createdAt: serverTimestamp(),
  });
  await assertFails(bookingBatch.commit());

  const unverifiedProvider = environment.authenticatedContext("provider", {
    email: "provider@example.com", email_verified: false,
  }).firestore();
  await assertFails(setDoc(doc(unverifiedProvider, "services/unverified-service"), {
    providerId: "provider", providerName: "Provider User",
    categoryId: "electrical", title: "Unverified electrical service",
    description: "A complete home electrical service from an unverified account.",
    priceBdt: 1200, coverImageUrl: null, districtCode: "dhaka",
    areaLabels: ["Dhanmondi"], areaKeys: ["dhanmondi"],
    searchTokens: ["unverified", "electrical"], status: "active",
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
});

test("provider applications require verification, match the client payload, and cannot self-approve", { skip: !emulatorAvailable }, async () => {
  const unverified = environment.authenticatedContext("applicant", {
    email: "applicant@example.com", email_verified: false,
  }).firestore();
  await assertFails(setDoc(
    doc(unverified, "provider_profiles/applicant"),
    providerApplicationData(),
  ));

  const firestore = environment.authenticatedContext("applicant", {
    email: "applicant@example.com", email_verified: true,
  }).firestore();
  const profile = doc(firestore, "provider_profiles/applicant");
  await assertSucceeds(setDoc(profile, providerApplicationData()));
  const saved = await assertSucceeds(getDoc(profile));
  assert.equal(saved.data()?.approvalStatus, "pending");
  assert.equal(saved.data()?.marketplaceVisible, false);
  assert.equal(saved.data()?.avatarUrl, null);
  assert.equal(saved.data()?.ratingAverage, undefined);
  await assertFails(updateDoc(profile, {
    approvalStatus: "approved", marketplaceVisible: true,
    updatedAt: serverTimestamp(),
  }));
});

test("admin membership cannot be self-assigned or inspected by another user", { skip: !emulatorAvailable }, async () => {
  const admin = adminDb();
  const customer = customerDb();
  await assertSucceeds(getDoc(doc(admin, "admins/admin")));
  await assertFails(getDoc(doc(customer, "admins/admin")));
  await assertFails(setDoc(doc(customer, "admins/customer"), {
    active: true, displayName: "Fake admin", createdAt: serverTimestamp(),
  }));
});

test("only administrators can manage provider-selectable service categories", { skip: !emulatorAvailable }, async () => {
  const admin = adminDb();
  const customer = customerDb();
  const provider = providerDb();
  const category = {
    name: "Water Filter Repair", iconKey: "appliance", order: 7,
    isActive: true, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  };
  await assertFails(setDoc(doc(customer, "categories/water-filter-repair"), category));
  await assertSucceeds(setDoc(doc(admin, "categories/water-filter-repair"), category));
  await assertSucceeds(getDocs(query(
    collection(admin, "categories"),
    orderBy("order"),
  )));
  await assertSucceeds(getDoc(doc(provider, "categories/water-filter-repair")));
  await assertFails(deleteDoc(doc(admin, "categories/water-filter-repair")));
  await assertSucceeds(updateDoc(doc(admin, "categories/water-filter-repair"), {
    isActive: false, updatedAt: serverTimestamp(),
  }));
  await assertFails(getDoc(doc(provider, "categories/water-filter-repair")));
  await assertSucceeds(getDoc(doc(admin, "categories/water-filter-repair")));
  await assertFails(deleteDoc(doc(customer, "categories/water-filter-repair")));
  await assertSucceeds(deleteDoc(doc(admin, "categories/water-filter-repair")));

  await assertSucceeds(getDocs(query(
    collection(admin, "services"),
    where("categoryId", "==", "electrical"),
  )));
  await assertFails(getDocs(query(
    collection(customer, "services"),
    where("categoryId", "==", "electrical"),
  )));
});

test("activity read state is private and requires a verified active account", { skip: !emulatorAvailable }, async () => {
  const customer = customerDb();
  const provider = providerDb();
  const state = doc(customer, "activity_states/customer");
  await assertSucceeds(setDoc(state, {
    uid: "customer", lastReadAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(getDoc(state));
  await assertFails(getDoc(doc(provider, "activity_states/customer")));
  const unverified = environment.authenticatedContext("stranger", {
    email: "stranger@example.com", email_verified: false,
  }).firestore();
  await assertFails(setDoc(doc(unverified, "activity_states/stranger"), {
    uid: "stranger", lastReadAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
});

test("only an admin can inspect hidden applications and approve an eligible provider", { skip: !emulatorAvailable }, async () => {
  const admin = adminDb();
  const customer = customerDb();
  await assertFails(getDoc(doc(customer, "provider_profiles/pending-review")));
  const pending = query(
    collection(admin, "provider_profiles"),
    where("approvalStatus", "==", "pending"),
  );
  const pendingSnapshot = await assertSucceeds(getDocs(pending));
  assert.ok(pendingSnapshot.docs.some((item) => item.id === "pending-review"));

  await assertSucceeds(updateDoc(doc(admin, "provider_profiles/pending-review"), {
    approvalStatus: "approved", marketplaceVisible: true,
    reviewedAt: serverTimestamp(), reviewedBy: "admin", rejectionReason: "",
    updatedAt: serverTimestamp(),
  }));
  const reviewed = await assertSucceeds(
    getDoc(doc(customer, "provider_profiles/pending-review")),
  );
  assert.equal(reviewed.data()?.marketplaceVisible, true);
  await assertSucceeds(getDoc(doc(admin, "users/pending-review")));
});

test("admin rejection requires feedback and protected audit fields", { skip: !emulatorAvailable }, async () => {
  const admin = adminDb();
  const profile = doc(admin, "provider_profiles/pending-reject");
  await assertFails(updateDoc(profile, {
    approvalStatus: "rejected", marketplaceVisible: false,
    reviewedAt: serverTimestamp(), reviewedBy: "admin", rejectionReason: "",
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(profile, {
    approvalStatus: "approved", marketplaceVisible: true,
    reviewedAt: serverTimestamp(), reviewedBy: "someone-else", rejectionReason: "",
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(profile, {
    approvalStatus: "rejected", marketplaceVisible: false,
    reviewedAt: serverTimestamp(), reviewedBy: "admin",
    rejectionReason: "Please provide clearer coverage details.",
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(admin, "provider_profiles/admin"), {
    approvalStatus: "rejected", marketplaceVisible: false,
    reviewedAt: serverTimestamp(), reviewedBy: "admin",
    rejectionReason: "Self-review is not allowed.",
    updatedAt: serverTimestamp(),
  }));
});

test("approved providers can create and update only their own valid services", { skip: !emulatorAvailable }, async () => {
  const firestore = providerDb();
  const service = doc(firestore, "services/provider-managed");
  await assertSucceeds(setDoc(service, {
    providerId: "provider", providerName: "Provider User",
    categoryId: "electrical", title: "Electrical wiring inspection",
    description: "A detailed electrical wiring inspection for residential properties.",
    priceBdt: 1400, coverImageUrl: null, districtCode: "dhaka",
    areaLabels: ["Dhanmondi"], areaKeys: ["dhanmondi"],
    searchTokens: ["electrical", "wiring", "inspection"], status: "active",
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(service, {
    priceBdt: 1500, description: "An updated electrical wiring inspection for residential properties.",
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(service, {
    providerId: "stranger", updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(service, {
    providerRating: 5, reviewCount: 100, updatedAt: serverTimestamp(),
  }));
});

test("suspended providers and their stale listings cannot create marketplace data", { skip: !emulatorAvailable }, async () => {
  const suspended = environment.authenticatedContext("suspended-provider", {
    email: "suspended@example.com", email_verified: true,
  }).firestore();
  await assertFails(setDoc(doc(suspended, "services/suspended-provider-new"), {
    providerId: "suspended-provider", providerName: "Suspended Provider",
    categoryId: "electrical", title: "New suspended provider service",
    description: "A service that a suspended provider must not be allowed to publish.",
    priceBdt: 900, coverImageUrl: null, districtCode: "dhaka",
    areaLabels: ["Dhanmondi"], areaKeys: ["dhanmondi"],
    searchTokens: ["suspended", "service"], status: "active",
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));

  const customer = customerDb();
  const bookingBatch = writeBatch(customer);
  bookingBatch.set(doc(customer, "bookings/stale-provider-booking"), {
    ...bookingData("pending", {
      providerId: "suspended-provider", serviceId: "suspended-service",
      providerName: "Suspended Provider", serviceTitle: "Suspended electrical service",
      priceBdt: 900, lastEventId: "stale-provider-event",
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }),
  });
  bookingBatch.set(doc(customer, "bookings/stale-provider-booking/private/contact"), {
    customerPhone: "+8801700000001", providerPhone: "",
    address: "House 20, Dhanmondi, Dhaka", landmark: "Near lake",
  });
  bookingBatch.set(doc(customer, "bookings/stale-provider-booking/events/stale-provider-event"), {
    type: "pending", actorId: "customer", createdAt: serverTimestamp(),
  });
  await assertFails(bookingBatch.commit());
});

test("clients cannot supply privileged account, aggregate, or booking fields", { skip: !emulatorAvailable }, async () => {
  const firestore = environment.authenticatedContext("new-customer", {
    email: "new-customer@example.com", email_verified: true,
  }).firestore();
  await assertFails(setDoc(doc(firestore, "users/new-customer"), {
    role: "customer", status: "suspended", displayName: "New Customer",
    email: "new-customer@example.com", phoneE164: "+8801700000006",
    photoPath: null, termsVersion: "1.0", isAdultConfirmed: true,
    termsAcceptedAt: serverTimestamp(), createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));

  const customer = customerDb();
  const bookingBatch = writeBatch(customer);
  bookingBatch.set(doc(customer, "bookings/privileged-field"), {
    ...bookingData("pending", {
      lastEventId: "privileged-event", moderationStatus: "resolved",
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }),
  });
  bookingBatch.set(doc(customer, "bookings/privileged-field/private/contact"), {
    customerPhone: "+8801700000001", providerPhone: "",
    address: "House 20, Dhanmondi, Dhaka", landmark: "Near lake",
  });
  bookingBatch.set(doc(customer, "bookings/privileged-field/events/privileged-event"), {
    type: "pending", actorId: "customer", createdAt: serverTimestamp(),
  });
  await assertFails(bookingBatch.commit());
});

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

test("customer cannot forge the locked service price", { skip: !emulatorAvailable }, async () => {
  const firestore = customerDb();
  const batch = writeBatch(firestore);
  batch.set(doc(firestore, "bookings/forged-price"), {
    ...bookingData("pending", {
      priceBdt: 1, lastEventId: "forged-event",
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }),
  });
  batch.set(doc(firestore, "bookings/forged-price/private/contact"), {
    customerPhone: "+8801700000001", providerPhone: "",
    address: "House 20, Dhanmondi, Dhaka", landmark: "Near lake",
  });
  batch.set(doc(firestore, "bookings/forged-price/events/forged-event"), {
    type: "pending", actorId: "customer", createdAt: serverTimestamp(),
  });
  await assertFails(batch.commit());
});

test("provider can start work and request completion only with matching events", { skip: !emulatorAvailable }, async () => {
  const firestore = providerDb();
  const startBatch = writeBatch(firestore);
  startBatch.update(doc(firestore, "bookings/accepted-transition"), {
    status: "inProgress", lastEventId: "start-event", updatedAt: serverTimestamp(),
  });
  startBatch.set(doc(firestore, "bookings/accepted-transition/events/start-event"), {
    type: "inProgress", actorId: "provider", createdAt: serverTimestamp(),
  });
  await assertSucceeds(startBatch.commit());

  const completionBatch = writeBatch(firestore);
  completionBatch.update(doc(firestore, "bookings/accepted-transition"), {
    status: "completionRequested", lastEventId: "completion-event",
    updatedAt: serverTimestamp(),
  });
  completionBatch.set(doc(firestore, "bookings/accepted-transition/events/completion-event"), {
    type: "completionRequested", actorId: "provider", createdAt: serverTimestamp(),
  });
  await assertSucceeds(completionBatch.commit());
});

test("customer can confirm cash completion or open a dispute", { skip: !emulatorAvailable }, async () => {
  const firestore = customerDb();
  const completeBatch = writeBatch(firestore);
  completeBatch.update(doc(firestore, "bookings/completion-complete"), {
    status: "completed", paymentStatus: "paidCash",
    completedAt: serverTimestamp(), lastEventId: "completed-event",
    updatedAt: serverTimestamp(),
  });
  completeBatch.set(doc(firestore, "bookings/completion-complete/events/completed-event"), {
    type: "completed", actorId: "customer", createdAt: serverTimestamp(),
  });
  completeBatch.delete(doc(firestore, "provider_slots/provider_2030-02-02_afternoon"));
  await assertSucceeds(completeBatch.commit());

  const disputeBatch = writeBatch(firestore);
  disputeBatch.update(doc(firestore, "bookings/completion-dispute"), {
    status: "disputed", paymentStatus: "disputed",
    dispute: { reason: "service_issue", details: "Work is incomplete", actorId: "customer", createdAt: serverTimestamp() },
    lastEventId: "disputed-event", updatedAt: serverTimestamp(),
  });
  disputeBatch.set(doc(firestore, "bookings/completion-dispute/events/disputed-event"), {
    type: "disputed", actorId: "customer", createdAt: serverTimestamp(),
  });
  disputeBatch.delete(doc(firestore, "provider_slots/provider_2030-02-03_evening"));
  await assertSucceeds(disputeBatch.commit());
});

test("participants can cancel pending or accepted bookings with reasons", { skip: !emulatorAvailable }, async () => {
  const customer = customerDb();
  const pendingBatch = writeBatch(customer);
  pendingBatch.update(doc(customer, "bookings/pending-cancel"), {
    status: "cancelled",
    cancellation: { reason: "schedule_changed", details: "Need another day", actorId: "customer", createdAt: serverTimestamp() },
    lastEventId: "pending-cancel-event", updatedAt: serverTimestamp(),
  });
  pendingBatch.set(doc(customer, "bookings/pending-cancel/events/pending-cancel-event"), {
    type: "cancelled", actorId: "customer", createdAt: serverTimestamp(),
  });
  await assertSucceeds(pendingBatch.commit());

  const provider = providerDb();
  const acceptedBatch = writeBatch(provider);
  acceptedBatch.update(doc(provider, "bookings/accepted-cancel"), {
    status: "cancelled",
    cancellation: { reason: "provider_unavailable", details: "Unable to attend", actorId: "provider", createdAt: serverTimestamp() },
    lastEventId: "accepted-cancel-event", updatedAt: serverTimestamp(),
  });
  acceptedBatch.set(doc(provider, "bookings/accepted-cancel/events/accepted-cancel-event"), {
    type: "cancelled", actorId: "provider", createdAt: serverTimestamp(),
  });
  acceptedBatch.delete(doc(provider, "provider_slots/provider_2030-02-05_afternoon"));
  await assertSucceeds(acceptedBatch.commit());
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

test("messages are denied when the other participant is suspended", { skip: !emulatorAvailable }, async () => {
  const firestore = providerDb();
  const batch = writeBatch(firestore);
  batch.set(doc(firestore, "bookings/suspended-recipient/messages/message"), {
    senderId: "provider", text: "This must not be delivered",
    createdAt: serverTimestamp(), readAt: null,
  });
  batch.update(doc(firestore, "bookings/suspended-recipient"), {
    lastMessageId: "message", lastMessageAt: serverTimestamp(),
    lastMessageSenderId: "provider", lastMessagePreview: "This must not be delivered",
    updatedAt: serverTimestamp(),
  });
  await assertFails(batch.commit());
});

test("an active participant can cancel when the other account is suspended", { skip: !emulatorAvailable }, async () => {
  const firestore = providerDb();
  const batch = writeBatch(firestore);
  batch.update(doc(firestore, "bookings/suspended-recipient"), {
    status: "cancelled",
    cancellation: {
      reason: "customer_unavailable", details: "Customer account is unavailable",
      actorId: "provider", createdAt: serverTimestamp(),
    },
    lastEventId: "suspended-cancel-event", updatedAt: serverTimestamp(),
  });
  batch.set(doc(firestore, "bookings/suspended-recipient/events/suspended-cancel-event"), {
    type: "cancelled", actorId: "provider", createdAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
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

test("provider dashboard and public review queries match the rules", { skip: !emulatorAvailable }, async () => {
  const provider = providerDb();
  await assertSucceeds(getDocs(query(
    collection(provider, "bookings"),
    where("providerId", "==", "provider"),
    orderBy("createdAt", "desc"),
  )));
  await assertSucceeds(getDocs(query(
    collection(provider, "services"),
    where("providerId", "==", "provider"),
    orderBy("updatedAt", "desc"),
  )));
  await assertSucceeds(getDocs(query(
    collection(provider, "reviews"),
    where("providerId", "==", "provider"),
    orderBy("createdAt", "desc"),
  )));
});

test("reports use contextual reasons, deterministic IDs, and are create-only", { skip: !emulatorAvailable }, async () => {
  const firestore = customerDb();
  const report = doc(firestore, "reports/customer_accepted_user_provider");
  await assertSucceeds(setDoc(report, {
    reporterId: "customer", targetType: "user", targetId: "provider",
    targetUserId: "provider", bookingId: "accepted", reason: "unsafe_behavior",
    details: "", status: "open", moderationNotes: "",
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(report, { status: "dismissed" }));
  await assertFails(setDoc(doc(firestore, "reports/customer_accepted_user_provider-2"), {
    reporterId: "customer", targetType: "user", targetId: "provider",
    targetUserId: "provider", bookingId: "accepted", reason: "abusive_content",
    details: "", status: "open", moderationNotes: "",
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
});

test("account deletion is an atomic, idempotent request instead of client cleanup", { skip: !emulatorAvailable }, async () => {
  const firestore = customerDb();
  await assertFails(updateDoc(doc(firestore, "users/customer"), {
    status: "deletionPending", updatedAt: serverTimestamp(),
  }));
  const stale = environment.authenticatedContext("customer", {
    email: "customer@example.com", email_verified: true,
    auth_time: Math.floor(Date.now() / 1000) - 700,
  }).firestore();
  const staleBatch = writeBatch(stale);
  staleBatch.update(doc(stale, "users/customer"), {
    status: "deletionPending", updatedAt: serverTimestamp(),
  });
  staleBatch.set(doc(stale, "deletion_requests/customer"), {
    uid: "customer", status: "requested", failureMessage: "",
    requestedAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  await assertFails(staleBatch.commit());
  const batch = writeBatch(firestore);
  batch.update(doc(firestore, "users/customer"), {
    status: "deletionPending", updatedAt: serverTimestamp(),
  });
  batch.set(doc(firestore, "deletion_requests/customer"), {
    uid: "customer", status: "requested", failureMessage: "",
    requestedAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
  await assertFails(deleteDoc(doc(firestore, "bookings/accepted/messages/existing")));
  await assertFails(deleteDoc(doc(firestore, "services/service")));
  await assertSucceeds(getDoc(doc(firestore, "deletion_requests/customer")));
  const profile = await assertSucceeds(getDoc(doc(firestore, "users/customer")));
  assert.equal(profile.data()?.status, "deletionPending");
  await environment.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), "users/customer"), {
      status: "active", updatedAt: createdAt,
    });
    await deleteDoc(doc(context.firestore(), "deletion_requests/customer"));
  });
});

test("providers cannot self-approve and profile edits revoke marketplace visibility", { skip: !emulatorAvailable }, async () => {
  const firestore = providerDb();
  await assertFails(updateDoc(doc(firestore, "provider_profiles/provider"), {
    publicName: "Self Approved Provider", marketplaceVisible: true,
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(firestore, "provider_profiles/provider"), {
    publicName: "Provider User Updated", approvalStatus: "pending",
    marketplaceVisible: false, reviewedAt: null, reviewedBy: null,
    rejectionReason: "", updatedAt: serverTimestamp(),
  }));
});

test("services cannot publish coverage outside the approved provider profile", { skip: !emulatorAvailable }, async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), "provider_profiles/provider"), {
      publicName: "Provider User", approvalStatus: "approved",
      marketplaceVisible: true, updatedAt: createdAt,
    });
  });
  const firestore = providerDb();
  await assertFails(setDoc(doc(firestore, "services/outside-coverage"), {
    providerId: "provider", providerName: "Provider User",
    categoryId: "electrical", title: "Electrical repair outside area",
    description: "A complete home electrical repair service outside coverage.",
    priceBdt: 1500, coverImageUrl: null, districtCode: "chattogram",
    areaLabels: ["Agrabad"], areaKeys: ["agrabad"],
    searchTokens: ["electrical", "repair"], status: "active",
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
});

test("blocking requires a shared booking and prevents stale booking creation", { skip: !emulatorAvailable }, async () => {
  const firestore = customerDb();
  await assertFails(setDoc(doc(firestore, "blocks/customer/users/stranger"), {
    blockedUid: "stranger", displayNameSnapshot: "Stranger User",
    bookingId: "accepted", createdAt: serverTimestamp(),
  }));
  await assertSucceeds(setDoc(doc(firestore, "blocks/customer/users/provider"), {
    blockedUid: "provider", displayNameSnapshot: "Provider User",
    bookingId: "accepted", createdAt: serverTimestamp(),
  }));
  const batch = writeBatch(firestore);
  batch.set(doc(firestore, "bookings/blocked-booking"), {
    ...bookingData("pending", {
      lastEventId: "blocked-event", createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  });
  batch.set(doc(firestore, "bookings/blocked-booking/private/contact"), {
    customerPhone: "+8801700000001", providerPhone: "",
    address: "House 20, Dhanmondi, Dhaka", landmark: "Near lake",
  });
  batch.set(doc(firestore, "bookings/blocked-booking/events/blocked-event"), {
    type: "pending", actorId: "customer", createdAt: serverTimestamp(),
  });
  await assertFails(batch.commit());
});
