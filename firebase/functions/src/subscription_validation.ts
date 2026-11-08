import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {google} from "googleapis";
import {createHash} from "crypto";
import {enforceHourlyRateLimit} from "./rate_limit";

// ---------------------------------------------------------------------------
// Subscription Cloud Functions
// ---------------------------------------------------------------------------
// These functions validate Google Play Billing purchase receipts and update
// Firestore accordingly. Server-side validation is required to prevent
// fraudulent purchases and to ensure the subscription state is authoritative.
//
// PREREQUISITES
// 1. Enable the Google Play Android Developer API in your GCP project.
// 2. Grant the service account used by Cloud Functions the role:
//    "Service Account User" on your Play Console account.
// 3. In your Play Console -> Users & Permissions -> invite your
//    Firebase service-account email and grant "Finance - View" (at minimum).
// ---------------------------------------------------------------------------

const PRODUCT_ID_MONTHLY = "pro_monthly";   // $9.99
const PRODUCT_ID_YEARLY  = "pro_yearly";    // $99.99

// The owning app's Play package name. MUST match the applicationId in
// android/app/build.gradle.kts and the Play Console listing.
const PACKAGE_NAME = "com.librarymanager.owner";

// ---------------------------------------------------------------------------
// Helper - verify a purchase token against the Google Play Developer API
// ---------------------------------------------------------------------------
async function verifyPlayPurchase(
  packageName: string,
  productId: string,
  purchaseToken: string,
): Promise<{
  verified: boolean;
  expiryTimeMillis?: number;
  purchaseState?: number;
  autoRenewing?: boolean;
}> {
  try {
    // Auth using the default service-account credentials already available
    // in the Cloud Functions runtime.
    const auth = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });

    const androidPublisher = google.androidpublisher({version: "v3", auth});

    // Validate the subscription purchase.
    const response = await androidPublisher.purchases.subscriptions.get({
      packageName,
      subscriptionId: productId,
      token: purchaseToken,
    });

    const data = response.data;

    // Validate based on paymentState:
    //   0 = Payment pending (not confirmed)  -> reject
    //   1 = Payment received                 -> valid
    //   2 = Free trial                       -> valid
    // Any other / missing state -> not valid.
    if (data.paymentState !== 1 && data.paymentState !== 2) {
      return {verified: false};
    }

    // Also verify the subscription hasn't expired.
    const expiryTimeMillis = data.expiryTimeMillis
      ? parseInt(data.expiryTimeMillis, 10)
      : undefined;
    if (expiryTimeMillis && Date.now() > expiryTimeMillis) {
      return {verified: false};
    }

    return {
      verified: true,
      expiryTimeMillis,
      autoRenewing: data.autoRenewing ?? false,
    };
  } catch (error) {
    functions.logger.error("Google Play API verification failed", error);
    return {verified: false};
  }
}

// ---------------------------------------------------------------------------
// Helper - write (or overwrite) the subscription document
// ---------------------------------------------------------------------------
async function writeSubscription(
  uid: string,
  data: {
    isActive: boolean;
    planType: string;
    purchaseToken: string;
    productId: string;
    purchasedAt: admin.firestore.Timestamp;
    expiresAt: admin.firestore.Timestamp;
    autoRenewEnabled: boolean;
  },
): Promise<void> {
  const docPath = `users/${uid}/subscription/current`;
  const ref = admin.firestore().doc(docPath);
  await ref.set(data, {merge: true});
}

// ---------------------------------------------------------------------------
// Callable function - called from the Flutter app after a Google Play
// purchase succeeds client-side. This function verifies the purchase with
// the Play Developer API before persisting.
// ---------------------------------------------------------------------------
export const validateSubscriptionPurchase = functions.https.onCall(
  async (data, context) => {
    // ---- Auth guard ----
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be signed in to validate a purchase.",
      );
    }
    const uid = context.auth.uid;

    // ---- Input validation ----
    const {productId, purchaseToken} = (data && typeof data === "object"
      ? data
      : {}) as {
      productId?: string;
      purchaseToken?: string;
      packageName?: string;
    };

    if (!productId || !purchaseToken) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: productId, purchaseToken.",
      );
    }

    const validIds = [PRODUCT_ID_MONTHLY, PRODUCT_ID_YEARLY];
    if (!validIds.includes(productId)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Invalid productId. Must be one of ${validIds.join(", ")}.`,
      );
    }
    // ---- Rate limit (anti-abuse) - enforced before external API call ----
    await enforceHourlyRateLimit("purchase_verify", uid, 10);

    // Hard-coded server-side: never trust a client-supplied package name, or a
    // valid purchase token from any other app could be replayed to grant Pro.
    const pkg = PACKAGE_NAME;
    const verification = await verifyPlayPurchase(pkg, productId, purchaseToken);

    if (!verification.verified) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Purchase token could not be verified with Google Play.",
      );
    }

    // ---- Bind the purchase token to the user who redeemed it (atomic transaction) ----
    // Prevents a valid Play token (leaked, refunded, or from another account)
    // from being replayed to grant Pro to an arbitrary uid.
    const tokenHash = createHash("sha256").update(purchaseToken).digest("hex");
    const tokenRef = admin.firestore().doc(`purchase_tokens/${tokenHash}`);
    await admin.firestore().runTransaction(async (transaction) => {
      const tokenSnap = await transaction.get(tokenRef);
      if (tokenSnap.exists) {
        const boundUid = tokenSnap.data()?.uid as string | undefined;
        if (boundUid !== uid) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "This purchase token is already linked to another account.",
          );
        }
      } else {
        transaction.set(tokenRef, {
          uid,
          productId,
          verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });

    // ---- Determine plan & expiry ----
    const planType = productId === PRODUCT_ID_YEARLY ? "yearly" : "monthly";
    const now = admin.firestore.Timestamp.now();

    let expiresAt: admin.firestore.Timestamp;
    if (verification.expiryTimeMillis) {
      expiresAt = admin.firestore.Timestamp.fromMillis(
        verification.expiryTimeMillis,
      );
    } else {
      // Fallback - compute client-side-style expiry
      const days = planType === "yearly" ? 365 : 30;
      expiresAt = admin.firestore.Timestamp.fromMillis(
        now.toMillis() + days * 86400_000,
      );
    }

    // ---- Persist ----
    await writeSubscription(uid, {
      isActive: true,
      planType,
      purchaseToken,
      productId,
      purchasedAt: now,
      expiresAt,
      autoRenewEnabled: verification.autoRenewing ?? true,
    });

    return {success: true};
  },
);

// ---------------------------------------------------------------------------
// Scheduled function - runs daily to deactivate expired subscriptions
// ---------------------------------------------------------------------------
export const cleanupExpiredSubscriptions = functions.pubsub
  .schedule("0 2 * * *") // every day at 02:00 UTC
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const groups = await admin.firestore().collectionGroup("subscription").get();

    let count = 0;
    const expired: admin.firestore.DocumentReference[] = [];

    for (const doc of groups.docs) {
      const data = doc.data();
      if (data.isActive !== true) continue;

      const expiresAt = data.expiresAt as admin.firestore.Timestamp | undefined;
      if (!expiresAt || expiresAt.toMillis() <= now.toMillis()) {
        expired.push(doc.ref);
        count++;
      }
    }

    // Process in chunks of 500 (max batch writes)
    for (let i = 0; i < expired.length; i += 500) {
      final_batch: {
        const batch = admin.firestore().batch();
        const chunk = expired.slice(i, i + 500);
        for (const ref of chunk) {
          batch.update(ref, {isActive: false});
        }
        await batch.commit();
      }
    }

    if (count > 0) {
      functions.logger.info(`Deactivated ${count} expired subscription(s).`);
    } else {
      functions.logger.info("No expired subscriptions found.");
    }
  });
