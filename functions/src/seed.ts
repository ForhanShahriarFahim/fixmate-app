import { applicationDefault, getApps, initializeApp } from "firebase-admin/app";
import { FieldValue } from "firebase-admin/firestore";
import { getFirestore } from "firebase-admin/firestore";

const categories = [
  { id: "electrical", name: "Electrical", iconKey: "electrical", order: 1 },
  { id: "plumbing", name: "Plumbing", iconKey: "plumbing", order: 2 },
  { id: "cleaning", name: "Cleaning", iconKey: "cleaning", order: 3 },
  { id: "ac-repair", name: "AC repair", iconKey: "ac", order: 4 },
  { id: "appliance-repair", name: "Appliance repair", iconKey: "appliance", order: 5 },
  { id: "painting", name: "Painting", iconKey: "painting", order: 6 },
];

async function main(): Promise<void> {
  const projectFlag = process.argv.indexOf("--project");
  const projectId = projectFlag >= 0 ? process.argv[projectFlag + 1] : process.env.GOOGLE_CLOUD_PROJECT;
  if (!projectId) {
    throw new Error("Pass --project <firebase-project-id> when seeding categories.");
  }
  if (getApps().length === 0) {
    initializeApp({ credential: applicationDefault(), projectId });
  }
  const db = getFirestore();
  const batch = db.batch();
  for (const category of categories) {
    batch.set(db.collection("categories").doc(category.id), {
      name: category.name,
      iconKey: category.iconKey,
      order: category.order,
      isActive: true,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  await batch.commit();
  process.stdout.write(`Seeded ${categories.length} FixMate categories in ${projectId}.\n`);
}

main().catch((error: unknown) => {
  process.stderr.write(`${String(error)}\n`);
  process.exitCode = 1;
});
