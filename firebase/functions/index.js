const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

exports.sendPasswordResetOtp = functions.firestore
    .document('users/{ownerUid}/password_resets/{resetId}')
    .onCreate(async (snap, context) => {
      const { ownerUid, resetId } = context.params;
      const data = snap.data();
      const { studentId, otp, expiresAt } = data;

      if (!studentId || !otp) {
        console.log('Missing studentId or otp');
        return null;
      }

      try {
        const studentDoc = await db
            .collection('users')
            .doc(ownerUid)
            .collection('students')
            .doc(studentId)
            .get();

        if (!studentDoc.exists) {
          console.log(`Student ${studentId} not found`);
          return null;
        }

        const studentData = studentDoc.data();
        const fcmToken = studentData?.fcmToken;

        if (!fcmToken) {
          console.log(`No FCM token for student ${studentId}`);
          return null;
        }

        const message = {
          token: fcmToken,
          notification: {
            title: 'Password Reset OTP',
            body: `Your OTP is: ${otp}. Valid for 5 minutes.`,
          },
          data: {
            otp: otp,
            studentId: studentId,
            ownerUid: ownerUid,
            resetId: resetId,
            type: 'password_reset',
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'password_reset_channel',
              priority: 'high',
              color: '#4F46E5',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        };

        const response = await admin.messaging().send(message);
        console.log(`FCM sent successfully to ${studentId}: ${response}`);
        return response;

      } catch (error) {
        console.error(`Error sending FCM to ${studentId}:`, error);
        return null;
      }
    });
