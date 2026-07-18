import assert from "node:assert/strict";
import test from "node:test";
import { canTransition, dhakaDateKey, isValidDhakaDateKey, normalizeKey } from "./domain";

test("booking state machine permits only planned transitions", () => {
  assert.equal(canTransition("pending", "accepted"), true);
  assert.equal(canTransition("pending", "completed"), false);
  assert.equal(canTransition("accepted", "inProgress"), true);
  assert.equal(canTransition("inProgress", "cancelled"), false);
  assert.equal(canTransition("completionRequested", "completed"), true);
  assert.equal(canTransition("completed", "pending"), false);
});

test("normalizes service area keys", () => {
  assert.equal(normalizeKey("  Cox's  Bazar "), "cox-s-bazar");
  assert.equal(normalizeKey("Dhanmondi-27"), "dhanmondi-27");
});

test("creates an ISO-style Dhaka date key", () => {
  assert.match(dhakaDateKey(new Date("2026-07-18T18:30:00.000Z")), /^2026-07-19$/);
});

test("rejects impossible Dhaka schedule dates", () => {
  assert.equal(isValidDhakaDateKey("2026-02-28"), true);
  assert.equal(isValidDhakaDateKey("2026-02-30"), false);
  assert.equal(isValidDhakaDateKey("2026-13-01"), false);
});
