import { applicationDefault, getApps, initializeApp } from "firebase-admin/app";
import { FieldValue } from "firebase-admin/firestore";
import { getFirestore } from "firebase-admin/firestore";
import { fixMateCategories } from "./category_seed";

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
  for (const category of fixMateCategories) {
    batch.set(db.collection("categories").doc(category.id), {
      name: category.name,
      iconKey: category.iconKey,
      order: category.order,
      isActive: true,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  await batch.commit();
  process.stdout.write(`Seeded ${fixMateCategories.length} FixMate categories in ${projectId}.\n`);
}

main().catch((error: unknown) => {
  process.stderr.write(`${String(error)}\n`);
  process.exitCode = 1;
});
