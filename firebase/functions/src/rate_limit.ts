import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

const db = admin.firestore();

/**
 * Simple hourly sliding-window rate limiter backed by Firestore.
 * One document per (bucket, uid, hour) window; concurrent calls are counted
 * via FieldValue.increment. Throws `resource-exhausted` when the cap is hit.
 */
export async function enforceHourlyRateLimit(
  bucket: string,
  uid: string,
  max: number,
): Promise<void> {
  const windowMs = 60 * 60 * 1000;
  const window = Math.floor(Date.now() / windowMs);
  const ref = db.doc(`rate_limits/${bucket}_${uid}_${window}`);

  try {
    await ref.update({count: admin.firestore.FieldValue.increment(1)});
  } catch (error) {
    // First call in the window: the doc doesn't exist yet.
    const msg = String(error instanceof Error ? error.message : error);
    const isNotFound =
      (error as {code?: number | string})?.code === 5 ||
      msg.includes("NOT_FOUND") ||
      msg.includes("not-found");
    if (!isNotFound) throw error;
    await ref.set({
      count: 1,
      uid,
      window,
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000),
    });
  }

  const snap = await ref.get();
  const count = (snap.data()?.count as number | undefined) ?? 1;
  if (count > max) {
    throw new functions.https.HttpsError(
      "resource-exhausted",
      "Too many attempts. Please try again later.",
    );
  }
}
