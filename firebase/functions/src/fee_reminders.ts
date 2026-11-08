import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();
const messaging = admin.messaging();

const BATCH_LIMIT = 500; // Firestore batch limit

/**
 * Scheduled function that runs daily at 9 AM IST.
 * Checks for upcoming and overdue fee due dates and sends FCM notifications.
 *
 * NOTE: the queries below require a composite index on fees:
 *   status ASC, dueDate ASC
 * (defined in firestore.indexes.json).
 */
export const sendFeeReminders = functions.pubsub
  .schedule("0 9 * * *")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const now = new Date();
    const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);

    // Get all users who have libraries
    const usersSnapshot = await db.collection("users").get();

    const results = await Promise.allSettled(
      usersSnapshot.docs.map((userDoc) =>
        processOwnerReminders(userDoc.id, now, threeDaysFromNow),
      ),
    );

    let failed = 0;
    for (const r of results) {
      if (r.status === "rejected") {
        failed++;
        functions.logger.error("Fee reminder processing failed", r.reason);
      }
    }
    if (failed > 0) {
      functions.logger.warn(`${failed}/${results.length} owners failed`);
    }
    return null;
  });

async function processOwnerReminders(
  uid: string,
  now: Date,
  threeDaysFromNow: Date,
): Promise<void> {
  try {
    const ownerDoc = await db.collection("users").doc(uid).get();
    const ownerFcmToken = ownerDoc.data()?.fcmToken as string | undefined;
    if (!ownerFcmToken) return;

    const userLibsSnapshot = await db
      .collection(`users/${uid}/libraries`)
      .limit(1)
      .get();
    if (userLibsSnapshot.empty) return;

    const feesCol = db.collection(`users/${uid}/fees`);

    // Check for fees due in 3 days
    const upcomingFees = await feesCol
      .where("status", "==", "pending")
      .where("dueDate", "<=", admin.firestore.Timestamp.fromDate(threeDaysFromNow))
      .where("dueDate", ">=", admin.firestore.Timestamp.fromDate(now))
      .get();

    // Check for overdue fees
    const overdueFees = await feesCol
      .where("status", "==", "pending")
      .where("dueDate", "<", admin.firestore.Timestamp.fromDate(now))
      .get();

    // Send notification for upcoming fees
    if (!upcomingFees.empty) {
      const names = upcomingFees.docs
        .map((doc) => doc.data().studentName)
        .filter((n): n is string => typeof n === "string")
        .slice(0, 3);
      const studentNames = names.join(", ");

      const message =
        upcomingFees.docs.length <= 3
          ? `${studentNames}'s fee is due in 3 days`
          : `${studentNames} and ${upcomingFees.docs.length - 3} more fees due soon`;

      await sendReminder(ownerFcmToken, uid, "Fee Reminder", message, "fee_reminder");

      await db.collection(`users/${uid}/notifications`).add({
        title: "Fee Reminder",
        body: message,
        category: "fee",
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Send notification for overdue fees
    if (!overdueFees.empty) {
      const totalOverdue = overdueFees.docs.reduce(
        (sum, doc) => sum + (Number(doc.data().amount) || 0), 0
      );

      await sendReminder(
        ownerFcmToken,
        uid,
        "Overdue Fees Alert",
        `${overdueFees.docs.length} fees overdue totaling ${totalOverdue.toLocaleString("en-IN")}`,
        "fee_overdue",
      );

      // Update status to "overdue" in bounded batches (500 per commit).
      for (let i = 0; i < overdueFees.docs.length; i += BATCH_LIMIT) {
        const chunk = overdueFees.docs.slice(i, i + BATCH_LIMIT);
        const batch = db.batch();
        for (const feeDoc of chunk) {
          batch.update(feeDoc.ref, {status: "overdue"});
        }
        await batch.commit();
      }
    }
  } catch (error) {
    functions.logger.error(`Fee reminders failed for owner ${uid}`, error);
    throw error;
  }
}

/** Sends a single FCM push, isolating push failures from the rest of the flow. */
async function sendReminder(
  token: string,
  uid: string,
  title: string,
  body: string,
  type: string,
): Promise<void> {
  try {
    await messaging.send({
      token,
      notification: {title, body},
      data: {type, uid},
    });
  } catch (error) {
    functions.logger.warn(`FCM send failed (${type}) for ${uid}`, error);
  }
}
