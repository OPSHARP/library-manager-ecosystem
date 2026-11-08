import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {randomInt} from "crypto";
import {enforceHourlyRateLimit} from "./rate_limit";

const db = admin.firestore();

const MAX_JOIN_PER_HOUR = 30;
const MAX_VERIFY_PER_HOUR = 30;

const ID_REGEX = /^[A-Za-z0-9_-]{6,128}$/;
const STUDENT_ID_REGEX = /^[A-Za-z0-9]{4,32}$/;

const PROFILE_NAME_MAX = 100;
const PROFILE_MOBILE_MAX = 20;
const PROFILE_ADDRESS_MAX = 300;

// NOTE: These are v1 callable functions — the handler signature is
// `(data, context)`, NOT a single request object. `context.auth` holds the
// verified Firebase Auth user (populated from the ID token the client
// attaches); `data` is the client payload.

function sanitizeProfileInput(data: Record<string, unknown>) {
  return {
    name: typeof data.name === "string" ? data.name.trim().slice(0, PROFILE_NAME_MAX) : "",
    mobile: typeof data.mobile === "string" ? data.mobile.trim().slice(0, PROFILE_MOBILE_MAX) : "",
    parentMobile:
      typeof data.parentMobile === "string"
        ? data.parentMobile.trim().slice(0, PROFILE_MOBILE_MAX)
        : "",
    address:
      typeof data.address === "string"
        ? data.address.trim().slice(0, PROFILE_ADDRESS_MAX)
        : "",
  };
}

function validateProfileIdentity(input: {
  name: string;
  mobile: string;
  parentMobile: string;
  address: string;
}) {
  if (!input.name) {
    throw new functions.https.HttpsError("invalid-argument", "Name is required.");
  }
  if (!input.mobile || input.mobile.replace(/\D/g, "").length < 10) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Enter a valid mobile number.",
    );
  }
  if (!input.parentMobile || input.parentMobile.replace(/\D/g, "").length < 10) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Enter a valid parent mobile number.",
    );
  }
}

/**
 * Creates the student's own profile SERVER-SIDE and generates the unique
 * student ID. The client never writes to Firestore directly for its profile —
 * this keeps every piece of student data server-managed.
 */
export const createStudentProfile = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to create your profile.",
    );
  }
  const uid = context.auth.uid;
  const raw =
    data && typeof data === "object" ? (data as Record<string, unknown>) : {};
  const input = sanitizeProfileInput(raw);
  validateProfileIdentity(input);

  const email =
    typeof raw.email === "string"
      ? raw.email.trim().slice(0, 200)
      : typeof context.auth.token.email === "string"
        ? context.auth.token.email
        : "";

  await enforceHourlyRateLimit("student_profile_create", uid, 10);

  // Reject if the profile already exists — a student can only create once.
  const existing = await db.doc(`student_profiles/${uid}`).get();
  if (existing.exists) {
    throw new functions.https.HttpsError(
      "already-exists",
      "Profile already exists.",
    );
  }

  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  const studentUniqueId = Array.from({length: 8}, () =>
    chars[randomInt(0, chars.length)],
  ).join("");

  await db.doc(`student_profiles/${uid}`).set({
    profileId: uid,
    studentUniqueId,
    name: input.name,
    email,
    mobile: input.mobile,
    parentMobile: input.parentMobile,
    address: input.address,
    joinedLibraries: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {studentUniqueId};
});

/**
 * Updates the student's own profile identity fields SERVER-SIDE. The client
 * can never write its profile directly — this is the only write path.
 */
export const updateStudentProfile = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to update your profile.",
    );
  }
  const uid = context.auth.uid;
  const raw =
    data && typeof data === "object" ? (data as Record<string, unknown>) : {};
  const input = sanitizeProfileInput(raw);
  validateProfileIdentity(input);

  await enforceHourlyRateLimit("student_profile_update", uid, 20);

  const profileRef = db.doc(`student_profiles/${uid}`);
  const snap = await profileRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "Profile not found. Create your profile first.",
    );
  }

  await profileRef.update({
    name: input.name,
    mobile: input.mobile,
    parentMobile: input.parentMobile,
    address: input.address,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {success: true};
});

/**
 * Lets an authenticated student join a library. The library linkage
 * (currentOwnerUid / currentLibraryId / joinedLibraries) is written
 * SERVER-SIDE after verifying the owner's library document exists — a client
 * can no longer point its profile at an arbitrary owner uid to gain access.
 */
export const joinLibrary = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to join a library.",
    );
  }
  const uid = context.auth.uid;
  const payload =
    data && typeof data === "object"
      ? (data as {
          ownerUid?: unknown;
          libraryId?: unknown;
          libraryName?: unknown;
          phone?: unknown;
          address?: unknown;
        })
      : {};

  const ownerUid = typeof payload.ownerUid === "string" ? payload.ownerUid : "";
  const libraryId = typeof payload.libraryId === "string" ? payload.libraryId : "";
  const libraryName =
    typeof payload.libraryName === "string" ? payload.libraryName.slice(0, 100) : "";
  const phone = typeof payload.phone === "string" ? payload.phone.slice(0, 20) : "";
  const address =
    typeof payload.address === "string" ? payload.address.slice(0, 200) : "";

  if (!ownerUid || !ID_REGEX.test(ownerUid)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Invalid library owner.",
    );
  }
  // Library documents are stored as users/{owner}/libraries/lib_{owner}.
  if (libraryId !== `lib_${ownerUid}`) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Invalid library id.",
    );
  }

  // The owner's library document must actually exist.
  const libRef = db.doc(`users/${ownerUid}/libraries/${libraryId}`);
  const libSnap = await libRef.get();
  if (!libSnap.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "Library not found. Check the code or QR and try again.",
    );
  }

  await enforceHourlyRateLimit("student_join", uid, MAX_JOIN_PER_HOUR);

  const profileRef = db.doc(`student_profiles/${uid}`);
  await profileRef.set(
    {
      currentOwnerUid: ownerUid,
      currentLibraryId: libraryId,
      joinedLibraries: admin.firestore.FieldValue.arrayUnion({
        ownerUid,
        libraryId,
        libraryName,
      }),
    },
    {merge: true},
  );

  const libData = libSnap.data();
  return {
    success: true,
    libraryName:
      (typeof libData?.libraryName === "string" ? libData.libraryName : "") ||
      libraryName,
    phone,
    address,
  };
});

/**
 * Verifies a student's unique ID against the owner's registry and binds the
 * student's device (authUid) to that record — atomically, server-side. This
 * replaces the client-side claim that allowed any user to take over an
 * unclaimed student record. After binding, the student may read their own
 * private records (fees/attendance/books) via the Firestore rules.
 */
export const verifyStudentId = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to verify your student ID.",
    );
  }
  const uid = context.auth.uid;
  const payload =
    data && typeof data === "object"
      ? (data as {ownerUid?: unknown; studentUniqueId?: unknown})
      : {};

  const ownerUid = typeof payload.ownerUid === "string" ? payload.ownerUid : "";
  const uniqueId =
    typeof payload.studentUniqueId === "string"
      ? payload.studentUniqueId.trim().toUpperCase()
      : "";

  if (!ownerUid || !ID_REGEX.test(ownerUid)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid owner.");
  }
  if (!uniqueId || !STUDENT_ID_REGEX.test(uniqueId)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Invalid student ID format.",
    );
  }

  await enforceHourlyRateLimit("student_verify", uid, MAX_VERIFY_PER_HOUR);

  const studentRef = db.doc(`users/${ownerUid}/students/${uniqueId}`);
  const profileRef = db.doc(`student_profiles/${uid}`);

  const studentData = await db.runTransaction(async (transaction) => {
    const studentSnap = await transaction.get(studentRef);
    if (!studentSnap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Student ID not found. Ask the library owner to add you.",
      );
    }

    const data = studentSnap.data() ?? {};
    const existingAuthUid = data.authUid as string | undefined;
    if (existingAuthUid && existingAuthUid !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "This Student ID is already linked to another account.",
      );
    }

    // Atomic claim + profile linkage (server-authoritative transaction)
    transaction.set(studentRef, {authUid: uid}, {merge: true});
    transaction.set(
      profileRef,
      {
        studentUniqueId: uniqueId,
        verifiedOwnerUid: ownerUid,
        currentOwnerUid: ownerUid,
        currentLibraryId:
          typeof data.libraryId === "string"
            ? data.libraryId
            : `lib_${ownerUid}`,
      },
      {merge: true},
    );

    return data;
  });

  const name =
    (typeof studentData.name === "string"
      ? studentData.name
      : typeof studentData.studentName === "string"
        ? studentData.studentName
        : "") || "";
  return {exists: true, name};
});

/**
 * Sends a join request from a student to a library owner.
 */
export const sendJoinRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  const uid = context.auth.uid;
  const payload = (data ?? {}) as {
    ownerUid?: unknown;
    libraryId?: unknown;
    libraryName?: unknown;
  };
  const ownerUid = typeof payload.ownerUid === "string" ? payload.ownerUid : "";
  const libraryId = typeof payload.libraryId === "string" ? payload.libraryId : "";
  const libraryName = typeof payload.libraryName === "string" ? payload.libraryName.slice(0, 100) : "";

  if (!ownerUid || !ID_REGEX.test(ownerUid)) throw new functions.https.HttpsError("invalid-argument", "Invalid owner.");
  if (libraryId !== `lib_${ownerUid}`) throw new functions.https.HttpsError("invalid-argument", "Invalid library.");

  const libRef = db.doc(`users/${ownerUid}/libraries/${libraryId}`);
  const libSnap = await libRef.get();
  if (!libSnap.exists) throw new functions.https.HttpsError("not-found", "Library not found.");

  await enforceHourlyRateLimit("student_join_request", uid, MAX_JOIN_PER_HOUR);

  const profileSnap = await db.doc(`student_profiles/${uid}`).get();
  const profileData = profileSnap.data() || {};
  const studentUniqueId = profileData.studentUniqueId || "";

  if (!studentUniqueId) {
    throw new functions.https.HttpsError("failed-precondition", "Student profile incomplete.");
  }

  // Create request doc
  const requestRef = db.doc(`users/${ownerUid}/join_requests/${uid}`);
  await requestRef.set({
    uid,
    studentUniqueId,
    name: profileData.name || "",
    phone: profileData.mobile || "",
    parentPhone: profileData.parentMobile || "",
    address: profileData.address || "",
    email: profileData.email || "",
    libraryId,
    libraryName: libSnap.data()?.libraryName || libraryName,
    status: "pending",
    requestedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Also link student to the library PUBLICLY so they can see seats
  await db.doc(`student_profiles/${uid}`).set({
    currentOwnerUid: ownerUid,
    currentLibraryId: libraryId,
    joinedLibraries: admin.firestore.FieldValue.arrayUnion({
      ownerUid,
      libraryId,
      libraryName: libSnap.data()?.libraryName || libraryName,
    }),
  }, {merge: true});

  // Write notification for the owner
  const ownerNotifRef = db.collection(`users/${ownerUid}/notifications`).doc();
  await ownerNotifRef.set({
    notificationId: ownerNotifRef.id,
    title: "New Join Request",
    body: `${profileData.name || "A student"} requested to join your library.`,
    category: "system",
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    data: { studentUid: uid },
  });

  return { success: true };
});

/**
 * Records when a student leaves a library. The owner's student record gets a
 * leave date and is marked inactive — server-side, so a client can never forge
 * a leave timestamp or bypass the student's own profile linkage.
 */
export const recordStudentLeave = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to leave a library.",
    );
  }
  const studentUid = context.auth.uid;

  const profileSnap = await db.doc(`student_profiles/${studentUid}`).get();
  if (!profileSnap.exists) {
    return {success: true};
  }
  const profile = profileSnap.data() ?? {};
  const ownerUid =
    typeof profile.currentOwnerUid === "string" ? profile.currentOwnerUid : "";
  const uniqueId =
    typeof profile.studentUniqueId === "string" ? profile.studentUniqueId : "";

  if (ownerUid && uniqueId) {
    await db.doc(`users/${ownerUid}/students/${uniqueId}`).update({
      isActive: false,
      status: "left",
      leaveDate: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return {success: true};
});

/**
 * Accepts a join request and automatically converts the student.
 */
export const acceptJoinRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  const ownerUid = context.auth.uid;
  const payload = (data ?? {}) as {studentUid?: unknown};
  const studentUid = typeof payload.studentUid === "string" ? payload.studentUid : "";

  if (!studentUid) throw new functions.https.HttpsError("invalid-argument", "Missing student UID.");

  const requestRef = db.doc(`users/${ownerUid}/join_requests/${studentUid}`);
  const requestSnap = await requestRef.get();
  if (!requestSnap.exists) throw new functions.https.HttpsError("not-found", "Request not found.");
  
  const reqData = requestSnap.data() || {};
  const uniqueId = reqData.studentUniqueId;
  
  if (!uniqueId) throw new functions.https.HttpsError("invalid-argument", "Request is missing uniqueId.");

  const batch = db.batch();
  
  // 1. Create student in owner's db
  const studentRef = db.doc(`users/${ownerUid}/students/${uniqueId}`);
  const studentSnap = await studentRef.get();
  
  if (studentSnap.exists) {
    const existingAuthUid = studentSnap.data()?.authUid;
    if (existingAuthUid && existingAuthUid !== studentUid) {
      throw new functions.https.HttpsError("already-exists", "This student profile is already linked to another account.");
    }
  }

  batch.set(studentRef, {
    studentId: uniqueId,
    uniqueId: uniqueId,
    authUid: studentUid,
    name: reqData.name,
    phone: reqData.phone,
    parentPhone: reqData.parentPhone,
    address: reqData.address,
    feePlan: "Monthly",
    feeAmount: 0,
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true}); // Use merge so we don't accidentally overwrite if it exists but is unlinked

  // 2. Update student profile
  batch.set(db.doc(`student_profiles/${studentUid}`), {
    verifiedOwnerUid: ownerUid,
    currentOwnerUid: ownerUid,
    currentLibraryId: reqData.libraryId,
  }, {merge: true});

  // 3. Mark request approved
  batch.delete(requestRef);

  await batch.commit();

  return { success: true };
});

/**
 * Lets an owner kick a student out of their library. Server-side only:
 * DELETES the student record (so they are auto-removed from the owner's list),
 * releases any assigned seat, clears the student profile's library linkage
 * (so the Students Portal auto-leaves on its next profile sync) and notifies
 * the student.
 */
export const kickStudent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }
  const ownerUid = context.auth.uid;
  const payload = (data ?? {}) as { studentId?: unknown };
  const uniqueId = typeof payload.studentId === "string" ? payload.studentId.trim() : "";

  if (!uniqueId || !STUDENT_ID_REGEX.test(uniqueId)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid student id.");
  }

  const studentRef = db.doc(`users/${ownerUid}/students/${uniqueId}`);
  const snap = await studentRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError("not-found", "Student not found.");
  }
  const s = snap.data() ?? {};
  const profileUid = s.authUid as string | undefined;
  const seatId = s.seatId as string | undefined;

  const batch = db.batch();

  // 1. Delete the student record → auto-removed from the owner's list.
  batch.delete(studentRef);

  // 2. Release any assigned seat and shift assignments.
  if (seatId) {
    const seatRef = db.doc(`users/${ownerUid}/seats/${seatId}`);
    const seatSnap = await seatRef.get();
    if (seatSnap.exists) {
      const seatData = seatSnap.data() || {};
      const shifts = (seatData.shifts as Record<string, { studentId?: string }>) || {};
      const updatedShifts = { ...shifts };
      let shiftRemoved = false;
      for (const [key, val] of Object.entries(updatedShifts)) {
        if (val && val.studentId === uniqueId) {
          delete updatedShifts[key];
          shiftRemoved = true;
        }
      }
      const updateData: Record<string, unknown> = {
        assignedStudentId: admin.firestore.FieldValue.delete(),
        assignedStudentName: admin.firestore.FieldValue.delete(),
        renewalDate: admin.firestore.FieldValue.delete(),
      };
      if (shiftRemoved) {
        if (Object.keys(updatedShifts).length === 0) {
          updateData.shifts = admin.firestore.FieldValue.delete();
          updateData.status = "available";
        } else {
          updateData.shifts = updatedShifts;
        }
      } else {
        updateData.status = "available";
      }
      batch.update(seatRef, updateData);
    }
  }

  // 3. Break the student's library linkage so their portal session auto-leaves.
  if (profileUid) {
    batch.update(db.doc(`student_profiles/${profileUid}`), {
      currentOwnerUid: admin.firestore.FieldValue.delete(),
      currentLibraryId: admin.firestore.FieldValue.delete(),
      verifiedOwnerUid: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // 4. Notify the student (in-app).
  const notifRef = db
    .collection(`users/${ownerUid}/students/${uniqueId}/notifications`)
    .doc();
  batch.set(notifRef, {
    notificationId: notifRef.id,
    title: "Removed from Library",
    body: `You were removed from the library by the owner.`,
    category: "system",
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();
  return { success: true };
});

/**
 * Student requests to leave their library. Creates a pending leave request
 * under the owner (`users/{owner}/leave_requests/{uniqueId}`) and notifies
 * the owner. The student stays a member until the owner approves.
 */
export const requestLibraryLeave = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = context.auth.uid;

  const profileRef = db.doc(`student_profiles/${uid}`);
  const profileSnap = await profileRef.get();
  if (!profileSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Profile not found.");
  }
  const p = profileSnap.data() ?? {};
  const ownerUid = p.currentOwnerUid as string | undefined;
  const uniqueId = p.studentUniqueId as string | undefined;
  const studentName = (p.name as string) || "Student";

  if (!ownerUid || !uniqueId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "You are not a member of any library.",
    );
  }

  const requestRef = db.doc(`users/${ownerUid}/leave_requests/${uniqueId}`);

  // Idempotent — don't stack duplicate pending requests.
  const existing = await requestRef.get();
  if (existing.exists && existing.data()?.status === "pending") {
    return { success: true, alreadyPending: true };
  }

  const batch = db.batch();
batch.set(requestRef, {
    studentId: uniqueId,
    studentUniqueId: uniqueId,
    studentName,
    requestedBy: uid,
    status: "pending",
    requestedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const notifRef = db.collection(`users/${ownerUid}/notifications`).doc();
  batch.set(notifRef, {
    notificationId: notifRef.id,
    title: "Leave Request",
    body: `${studentName} has requested to leave the library.`,
    category: "leave_request",
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    data: { studentUid: uid, studentUniqueId: uniqueId },
  });

  await batch.commit();
  return { success: true };
});

/**
 * Owner approves a student's leave request. Server-side only: marks the
 * student's record as left (with a leave date), releases any assigned seat,
 * clears the student profile's library linkage (so the portal auto-leaves),
 * deletes the request and notifies the student.
 */
export const approveLeaveRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }
  const ownerUid = context.auth.uid;
  const payload = (data ?? {}) as { studentId?: unknown };
  const uniqueId = typeof payload.studentId === "string" ? payload.studentId.trim() : "";

  if (!uniqueId || !STUDENT_ID_REGEX.test(uniqueId)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid student id.");
  }

  const studentRef = db.doc(`users/${ownerUid}/students/${uniqueId}`);
  const snap = await studentRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError("not-found", "Student not found.");
  }
  const s = snap.data() ?? {};
  const profileUid = s.authUid as string | undefined;
  const seatId = s.seatId as string | undefined;

  const batch = db.batch();

  batch.update(studentRef, {
    isActive: false,
    status: "left",
    leaveDate: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  if (seatId) {
    const seatRef = db.doc(`users/${ownerUid}/seats/${seatId}`);
    const seatSnap = await seatRef.get();
    if (seatSnap.exists) {
      const seatData = seatSnap.data() || {};
      const shifts = (seatData.shifts as Record<string, { studentId?: string }>) || {};
      const updatedShifts = { ...shifts };
      let shiftRemoved = false;
      for (const [key, val] of Object.entries(updatedShifts)) {
        if (val && val.studentId === uniqueId) {
          delete updatedShifts[key];
          shiftRemoved = true;
        }
      }
      const updateData: Record<string, unknown> = {
        assignedStudentId: admin.firestore.FieldValue.delete(),
        assignedStudentName: admin.firestore.FieldValue.delete(),
        renewalDate: admin.firestore.FieldValue.delete(),
      };
      if (shiftRemoved) {
        if (Object.keys(updatedShifts).length === 0) {
          updateData.shifts = admin.firestore.FieldValue.delete();
          updateData.status = "available";
        } else {
          updateData.shifts = updatedShifts;
        }
      } else {
        updateData.status = "available";
      }
      batch.update(seatRef, updateData);
    }
  }

  if (profileUid) {
    batch.update(db.doc(`student_profiles/${profileUid}`), {
      currentOwnerUid: admin.firestore.FieldValue.delete(),
      currentLibraryId: admin.firestore.FieldValue.delete(),
      verifiedOwnerUid: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  batch.delete(db.doc(`users/${ownerUid}/leave_requests/${uniqueId}`));

  if (profileUid) {
    const notifRef = db
      .collection(`users/${ownerUid}/students/${uniqueId}/notifications`)
      .doc();
    batch.set(notifRef, {
      notificationId: notifRef.id,
      title: "Leave Approved",
      body: "Your leave request was approved. You can rejoin anytime.",
      category: "system",
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  return { success: true };
});
