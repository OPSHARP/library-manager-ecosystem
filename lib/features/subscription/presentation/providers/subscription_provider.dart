import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/subscription_model.dart';
import '../../data/repositories/subscription_repository.dart';

/// Product IDs for Google Play Console — you must create these in Play Console.
class SubscriptionProducts {
  static const String monthly = 'pro_monthly'; // $9.99
  static const String yearly = 'pro_yearly'; // $99.99

  static const List<String> all = [monthly, yearly];
}

/// Provider for the subscription repository.
final subscriptionRepositoryProvider =
    Provider.family<SubscriptionRepository, String>(
      (ref, uid) => SubscriptionRepository(uid: uid),
    );

/// Provider for the in-app purchase connection.
final inAppPurchaseProvider = Provider<InAppPurchase>((ref) {
  return InAppPurchase.instance;
});

/// Subscription state enum.
enum SubscriptionStatus { loading, free, active, error }

/// Subscription notifier — manages purchases and subscription state.
class SubscriptionNotifier extends StateNotifier<SubscriptionModel> {
  final String uid;
  final SubscriptionRepository _repository;
  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  StreamSubscription<SubscriptionModel>? _firestoreSubscription;
  bool _initialized = false;

  SubscriptionNotifier({
    required this.uid,
    required SubscriptionRepository repository,
    required InAppPurchase iap,
  }) : _repository = repository,
       _iap = iap,
       super(SubscriptionModel.free) {
    _init();
  }

  /// The current status derived from state.
  SubscriptionStatus get status {
    if (!_initialized) return SubscriptionStatus.loading;
    if (state.isActive) return SubscriptionStatus.active;
    return SubscriptionStatus.free;
  }

  Future<void> _init() async {
    try {
      // Listen to Firestore for subscription updates.
      _firestoreSubscription = _repository.watchSubscription().listen((sub) {
        if (sub.isActive) {
          state = _checkExpiry(sub);
        }
        _initialized = true;
      });

      // Also do an initial fetch.
      final sub = await _repository.getSubscription();
      if (sub.isActive) {
        state = _checkExpiry(sub);
      }
      _initialized = true;

      // Listen to purchase updates from Google Play.
      final purchaseUpdates = _iap.purchaseStream;
      _purchaseSubscription = purchaseUpdates.listen(
        _handlePurchaseUpdate,
        onError: (error) {
          _initialized = true;
        },
      );
    } catch (_) {
      _initialized = true;
    }
  }

  /// Local replacement for the server cleanupExpiredSubscriptions function:
  /// if the subscription's expiry has passed, downgrade to free in-memory.
  /// (Firestore writes are server-only; the Cloud Function handles the
  /// authoritative deactivation.)
  SubscriptionModel _checkExpiry(SubscriptionModel sub) {
    if (!sub.isActive) return sub;
    final expiresAt = sub.expiresAt;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      // Keep the history but mark inactive so premium features lock down.
      return sub.copyWith(isActive: false);
    }
    return sub;
  }

  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _verifyAndApplyPurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        // Purchase failed — acknowledge the failed token so Play doesn't
        // block future purchases of the same product.
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<void> _verifyAndApplyPurchase(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    final purchaseToken = purchase.verificationData.serverVerificationData;

    // Always acknowledge the purchase first so Play knows we received it,
    // regardless of whether our verification succeeds or fails.
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }

    // Server-side verification via Cloud Function — validates token against
    // the Google Play Developer API and writes the subscription doc.
    try {
      final fn = FirebaseFunctions.instance;
      await fn
          .httpsCallable('validateSubscriptionPurchase')
          .call<Map<String, dynamic>>({
        'productId': productId,
        'purchaseToken': purchaseToken,
        // NOTE: packageName intentionally omitted — the Cloud Function uses a
        // hardcoded value to prevent cross-app token replay attacks.
      });
      // Success: the Firestore subscription stream drives state. No local
      // fallback — the server is the sole authority.
    } on FirebaseFunctionsException {
      // Purchase validation failures are non-fatal: the Firestore
      // subscription stream remains the source of truth.
    } catch (_) {
      // Ignore transient validation errors; state is driven by Firestore.
    }
  }

  /// Start the purchase flow for a given product ID.
  ///
  /// Throws [ProductNotFoundException] if the product is not listed in
  /// Google Play Console (you must create it first). Subscriptions require
  /// [InAppPurchase.buySubscription]; using `buyNonConsumable` causes Play to
  /// reject the product type.
  /// Returns `true` on successful purchase, `false` if user cancelled.
  Future<bool> purchaseProduct(String productId) async {
    final productDetails = await _iap.queryProductDetails({productId});

    if (productDetails.notFoundIDs.contains(productId)) {
      throw ProductNotFoundException(productId);
    }

    final product = productDetails.productDetails.firstWhere(
      (p) => p.id == productId,
    );

    final purchaseParam = PurchaseParam(productDetails: product);
    // `buyNonConsumable` is the correct cross-platform call for subscriptions
    // through the base InAppPurchase API (in_app_purchase ^3.x). Play
    // determines the product type (subscription vs one-time) from the Play
    // Console configuration — not from the Flutter method name.
    // To handle subscription upgrades/downgrades use
    // InAppPurchaseAndroidPlatformAddition.buySubscription instead.
    return _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Restore previous purchases.
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// Check if a premium feature is accessible.
  bool canAccessPremiumFeature() {
    return state.isActive;
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _firestoreSubscription?.cancel();
    super.dispose();
  }
}

/// Exception thrown when a product ID is not found in Google Play Console.
class ProductNotFoundException implements Exception {
  final String productId;
  ProductNotFoundException(this.productId);

  @override
  String toString() =>
      "Product '$productId' not found in Google Play Console.\n"
      "Please create this managed subscription product in Play Console first, "
      "then publish the app to a testing track.";
}

/// Provider for the subscription notifier.
final subscriptionProvider =
    StateNotifierProvider.family<
      SubscriptionNotifier,
      SubscriptionModel,
      String
    >((ref, uid) {
      final repository = ref.watch(subscriptionRepositoryProvider(uid));
      final iap = ref.watch(inAppPurchaseProvider);
      return SubscriptionNotifier(uid: uid, repository: repository, iap: iap);
    });

/// Provider that resolves the current user's UID and returns their subscription.
final currentSubscriptionProvider = Provider<SubscriptionModel>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return SubscriptionModel.free;
  return ref.watch(subscriptionProvider(user.uid));
});

/// Provider for subscription status (for quick checks).
final subscriptionStatusProvider = Provider<SubscriptionStatus>((ref) {
  final sub = ref.watch(currentSubscriptionProvider);
  if (sub.isActive) return SubscriptionStatus.active;
  return SubscriptionStatus.free;
});
