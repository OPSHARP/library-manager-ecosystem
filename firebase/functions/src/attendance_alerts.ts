import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Triggered when an attendance document is updated.
 * Sends alerts to the library owner for significant attendance events.
 */
export const sendAttendanceAlerts = functions.firestore
  .document("users/{uid}/attendance/{date}")
  .onUpdate(async (change, context) => {
    const {uid, date} = context.params;
    const after = change.after.data();

    const totalPresent = after.totalPresent || 0;
    const totalAbsent = after.totalAbsent || 0;
    const totalStudents = totalPresent + totalAbsent;

    if (totalStudents === 0) return;

    const attendanceRate = (totalPresent / totalStudents) * 100;

    if (attendanceRate < 50 && totalStudents > 5) {
      const userDoc = await db.collection("users").doc(uid).get();
      const fcmToken = userDoc.data()?.fcmToken;
      if (!fcmToken) return;

      await messaging.send({
        token: fcmToken,
        notification: {
          title: "Low Attendance Alert",
          body: `Only ${totalPresent} of ${totalStudents} students present today (${attendanceRate.toFixed(0)}%)`,
        },
        data: {
          type: "attendance_alert",
          uid,
          date,
        },
      });

      await db.collection(`users/${uid}/notifications`).add({
        title: "Low Attendance Alert",
        body: `Only ${totalPresent} of ${totalStudents} students present today`,
        category: "attendance",
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
