import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const projectId = process.env.GOOGLE_CLOUD_PROJECT;
if (!projectId) throw new Error("GOOGLE_CLOUD_PROJECT is required");
initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();
const [control, active, recent] = await Promise.all([
  db.collection("cityPreparationControl").doc("global").get(),
  db.collection("cityPreparationActive").limit(20).get(),
  db.collection("cityPreparationJobs").orderBy("updatedAt", "desc").limit(20).get(),
]);
process.stdout.write(`${JSON.stringify({
  projectId,
  control: control.data() ?? null,
  active: active.docs.map((doc) => doc.data()),
  recent: recent.docs.map((doc) => {
    const data = doc.data();
    return { id: doc.id, cityQid: data.cityQid, status: data.status, qualifiedCount: data.qualifiedCount, failureCode: data.failureCode ?? null };
  }),
}, null, 2)}\n`);

