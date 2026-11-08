import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * Scheduled function that runs on the 1st of every month at 6 AM IST.
 * Generates monthly reports for all libraries.
 */
export const generateMonthlyReport = functions.pubsub
  .schedule("0 6 1 * *")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const now = new Date();
    const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const monthKey = `${lastMonth.getFullYear()}-${String(lastMonth.getMonth() + 1).padStart(2, "0")}`;

    const usersSnapshot = await db.collection("users").get();

    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;
      const userData = userDoc.data();

      const feesSnapshot = await db
        .collection(`users/${uid}/fees`)
        .where("month", "==", monthKey)
        .get();

      let totalRevenue = 0;
      let collectedRevenue = 0;
      let pendingRevenue = 0;
      let feeCount = feesSnapshot.docs.length;

      for (const feeDoc of feesSnapshot.docs) {
        const feeData = feeDoc.data();
        const amount = feeData.amount || 0;
        if (feeData.status === "paid") {
          collectedRevenue += amount;
        } else {
          pendingRevenue += amount;
        }
        totalRevenue += amount;
      }

      const attendanceSnapshot = await db
        .collection(`users/${uid}/attendance`)
        .get();

      let totalAttendanceDays = 0;
      let totalPresent = 0;
      for (const attDoc of attendanceSnapshot.docs) {
        const attData = attDoc.data();
        totalPresent += attData.totalPresent || 0;
        totalAttendanceDays++;
      }

      const studentsSnapshot = await db
        .collection(`users/${uid}/students`)
        .where("isActive", "==", true)
        .get();

      const seatsSnapshot = await db
        .collection(`users/${uid}/seats`)
        .get();

      let occupiedSeats = 0;
      for (const seatDoc of seatsSnapshot.docs) {
        if (seatDoc.data().status === "occupied") occupiedSeats++;
      }

      await db.collection(`users/${uid}/reports`).add({
        month: monthKey,
        totalRevenue,
        collectedRevenue,
        pendingRevenue,
        feeCount,
        totalAttendanceDays,
        totalPresent,
        averageAttendance: totalAttendanceDays > 0
          ? Math.round(totalPresent / totalAttendanceDays)
          : 0,
        activeStudents: studentsSnapshot.docs.length,
        totalSeats: seatsSnapshot.docs.length,
        occupiedSeats,
        occupancyRate: seatsSnapshot.docs.length > 0
          ? Math.round((occupiedSeats / seatsSnapshot.docs.length) * 100)
          : 0,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const fcmToken = userData.fcmToken as string | undefined;
      if (fcmToken) {
        const messaging = admin.messaging();
        await messaging.send({
          token: fcmToken,
          notification: {
            title: "Monthly Report Ready",
            body: `Your ${lastMonth.toLocaleString("default", {month: "long", year: "numeric"})} report is ready. Revenue: ${collectedRevenue.toLocaleString("en-IN")}`,
          },
          data: {
            type: "monthly_report",
            uid,
            month: monthKey,
          },
        });
      }
    }
  });

/**
 * Scheduled function that runs weekly on Sundays at 3 AM IST.
 * Creates a backup of critical library data.
 */
export const autoBackup = functions.pubsub
  .schedule("0 3 * * 0")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const usersSnapshot = await db.collection("users").get();

    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;

      const studentsSnapshot = await db
        .collection(`users/${uid}/students`)
        .get();
      const students = studentsSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      const seatsSnapshot = await db
        .collection(`users/${uid}/seats`)
        .get();
      const seats = seatsSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      await db.collection(`users/${uid}/backups`).add({
        students,
        seats,
        studentCount: students.length,
        seatCount: seats.length,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    console.log("Weekly backup completed");
  });
