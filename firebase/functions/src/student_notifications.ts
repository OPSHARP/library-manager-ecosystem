import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {enforceHourlyRateLimit} from "./rate_limit";

// ---------------------------------------------------------------------------
// Student notifications
// ---------------------------------------------------------------------------
// The library owner sends an instant update to one student or broadcasts to
// every student in their library. Each notification is:
//   1. Written to  users/{ownerUid}/students/{studentId}/notifications/{id}
//      → shows instantly in the student app's in-app notification list.
//   2. Pushed via FCM to every device token registered on that student doc
//      → shows in the device notification bar.
//
// Notifications only reach students who have the portal app installed AND
// joined this library: an FCM token is only stored on the student document
// after the student registers it (the app only does so once the student has
// connected to this specific owner's library). Students who have not joined
// have no token, so they receive nothing.

const MAX_TOKENS_PER_BATCH = 500; // FCM multicast limit

async function sendFcmPush(
  tokens: string[],
  title: string,
  body: string,
  notificationId: string,
): Promise<void> {
  for (let i = 0; i < tokens.length; i += MAX_TOKENS_PER_BATCH) {
    const chunk = tokens.slice(i, i + MAX_TOKENS_PER_BATCH);
    try {
      const result = await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: {title, body},
        data: {
          type: "student_update",
          notificationId,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {priority: "high"},
      });
      functions.logger.info(
        `FCM: ${result.successCount} sent, ${result.failureCount} failed`,
      );
    } catch (error) {
      functions.logger.warn("FCM multicast failed", error);
    }
  }
}

// ---------------------------------------------------------------------------
// Callable – owner sends an update to one or all students
// ---------------------------------------------------------------------------
const MAX_STUDENT_TARGETS = 500;
const MAX_TITLE_LENGTH = 100;
const MAX_BODY_LENGTH = 2000;
const CONCURRENCY = 10;

export const sendStudentNotification = functions.https.onCall(
  async (data, context) => {
    // ---- Auth guard: only the library owner may send ----
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be signed in to send notifications.",
      );
    }
    const ownerUid = context.auth.uid;

    // ---- Anti-abuse: per-owner notification quota ----
    await enforceHourlyRateLimit("student_notify", ownerUid, 60);

    // ---- Input validation ----
    const payload =
      data && typeof data === "object"
        ? (data as {
            studentIds?: string[] | "all";
            title?: string;
            body?: string;
            category?: string;
          })
        : {};

    const title = payload.title ? String(payload.title).trim() : "";
    const body = payload.body ? String(payload.body).trim() : "";

    if (title.length === 0 || title.length > MAX_TITLE_LENGTH) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `A title between 1 and ${MAX_TITLE_LENGTH} characters is required.`,
      );
    }
    if (body.length === 0 || body.length > MAX_BODY_LENGTH) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `A message body between 1 and ${MAX_BODY_LENGTH} characters is required.`,
      );
    }
    const category =
      payload.category && String(payload.category).trim().length > 0
        ? String(payload.category).trim().slice(0, 40)
        : "student_update";

    // ---- Resolve target students (bounded) ----
    const db = admin.firestore();
    const studentsCol = db.collection(`users/${ownerUid}/students`);
    const targetIds: string[] = [];

    if (payload.studentIds === "all") {
      const snapshot = await studentsCol.get();
      for (const doc of snapshot.docs) {
        targetIds.push(doc.id);
      }
    } else if (Array.isArray(payload.studentIds)) {
      for (const id of payload.studentIds) {
        if (typeof id === "string" && id.trim().length > 0) {
          targetIds.push(id.trim());
        }
      }
    }

    if (targetIds.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "No target students provided.",
      );
    }
    if (targetIds.length > MAX_STUDENT_TARGETS) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `A maximum of ${MAX_STUDENT_TARGETS} students can be notified at once.`,
      );
    }

    // ---- Write + push per student, bounded concurrency, error-isolated ----
    const cleanTitle = title;
    const cleanBody = body;

    // Batch-read all target student docs in one round trip.
    const refs = targetIds.map((id) => studentsCol.doc(id));
    const studentDocs = await db.getAll(...refs);

    const results = await runWithConcurrency(
      targetIds.map((studentId, index) => () =>
        deliverToStudent(ownerUid, studentId, studentDocs[index], {
          title: cleanTitle,
          body: cleanBody,
          category,
        }),
      ),
      CONCURRENCY,
    );

    let delivered = 0;
    let failed = 0;
    for (const r of results) {
      if (r.status === "fulfilled") {
        delivered++;
      } else {
        failed++;
        functions.logger.warn(
          `Notification delivery failed for a student`,
          r.reason,
        );
      }
    }

    return {success: failed === 0, delivered, failed};
  },
);

interface DeliveryInput {
  title: string;
  body: string;
  category: string;
}

async function deliverToStudent(
  ownerUid: string,
  studentId: string,
  studentDoc: admin.firestore.DocumentSnapshot,
  input: DeliveryInput,
): Promise<void> {
  if (!studentDoc.exists) return;

  const tokenField = studentDoc.data()?.fcmTokens;
  const tokens: string[] = Array.isArray(tokenField)
    ? tokenField.filter((t): t is string => typeof t === "string")
    : [];

  const studentRef = admin
    .firestore()
    .doc(`users/${ownerUid}/students/${studentId}`);

  const notificationId = studentRef.collection("notifications").doc().id;
  await studentRef.collection("notifications").doc(notificationId).set({
    id: notificationId,
    title: input.title,
    body: input.body,
    category: input.category,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  if (tokens.length > 0) {
    await sendFcmPush(tokens, input.title, input.body, notificationId);
  }
}

/** Runs a list of async tasks with a bounded concurrency. */
async function runWithConcurrency<T>(
  tasks: Array<() => Promise<T>>,
  limit: number,
): Promise<PromiseSettledResult<T>[]> {
  const results: PromiseSettledResult<T>[] = new Array(tasks.length);
  let index = 0;

  async function worker(): Promise<void> {
    while (index < tasks.length) {
      const current = index++;
      try {
        results[current] = {status: "fulfilled", value: await tasks[current]()};
      } catch (reason) {
        results[current] = {status: "rejected", reason};
      }
    }
  }

  const workers = Array.from(
    {length: Math.min(limit, tasks.length)},
    () => worker(),
  );
  await Promise.all(workers);
  return results;
}
