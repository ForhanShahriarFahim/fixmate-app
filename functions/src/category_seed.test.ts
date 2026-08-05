import assert from "node:assert/strict";
import test from "node:test";
import { fixMateCategories } from "./category_seed";

test("category seed manifest has the six stable FixMate documents", () => {
  assert.deepEqual(fixMateCategories, [
    { id: "electrical", name: "Electrical", iconKey: "electrical", order: 1 },
    { id: "plumbing", name: "Plumbing", iconKey: "plumbing", order: 2 },
    { id: "cleaning", name: "Cleaning", iconKey: "cleaning", order: 3 },
    { id: "ac-repair", name: "AC repair", iconKey: "ac", order: 4 },
    { id: "appliance-repair", name: "Appliance repair", iconKey: "appliance", order: 5 },
    { id: "painting", name: "Painting", iconKey: "painting", order: 6 },
  ]);
  assert.equal(new Set(fixMateCategories.map(({ id }) => id)).size, 6);
});
