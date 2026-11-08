import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();
const auth = admin.auth();

/**
 * Triggered when a new user is created in Firebase Auth.
 * Sets safe default custom claims and creates user document.
 */
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  const {uid, email, displayName, phoneNumber} = user;
  const isAnonymous = !user.providerData || user.providerData.length === 0;
  const role = isAnonymous ? "student" : "user";

  // Set default custom claims safely (never default to owner)
  await auth.setCustomUserClaims(uid, {
    role,
    libraryId: null,
  });

  // Create user document if not exists
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) {
    await db.collection("users").doc(uid).set({
      uid,
      name: displayName || "",
      email: email || "",
      phone: phoneNumber || "",
      role,
      photoUrl: null,
      libraryId: null,
      fcmToken: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLogin: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});
