import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the subscription status for a user.
class SubscriptionModel {
  /// Whether the user has an active subscription.
  final bool isActive;

  /// The plan type: 'monthly' or 'yearly'.
  final String? planType;

  /// The purchase token from Google Play.
  final String? purchaseToken;

  /// The product ID from Google Play.
  final String? productId;

  /// When the subscription was purchased.
  final DateTime? purchasedAt;

  /// When the subscription expires (null if lifetime).
  final DateTime? expiresAt;

  /// Whether auto-renew is enabled.
  final bool autoRenewEnabled;

  const SubscriptionModel({
    this.isActive = false,
    this.planType,
    this.purchaseToken,
    this.productId,
    this.purchasedAt,
    this.expiresAt,
    this.autoRenewEnabled = true,
  });

  /// Create from Firestore document.
  factory SubscriptionModel.fromMap(Map<String, dynamic> data) {
    return SubscriptionModel(
      isActive: data['isActive'] as bool? ?? false,
      planType: data['planType'] as String?,
      purchaseToken: data['purchaseToken'] as String?,
      productId: data['productId'] as String?,
      purchasedAt: (data['purchasedAt'] as dynamic) is Timestamp
          ? (data['purchasedAt'] as Timestamp).toDate()
          : null,
      expiresAt: (data['expiresAt'] as dynamic) is Timestamp
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      autoRenewEnabled: data['autoRenewEnabled'] as bool? ?? true,
    );
  }

  /// Convert to Firestore document.
  Map<String, dynamic> toMap() {
    return {
      'isActive': isActive,
      'planType': planType,
      'purchaseToken': purchaseToken,
      'productId': productId,
      'purchasedAt': purchasedAt,
      'expiresAt': expiresAt,
      'autoRenewEnabled': autoRenewEnabled,
    };
  }

  /// Default free subscription.
  static const SubscriptionModel free = SubscriptionModel(
    isActive: false,
    autoRenewEnabled: false,
  );

  /// Copy with modified fields.
  SubscriptionModel copyWith({
    bool? isActive,
    String? planType,
    String? purchaseToken,
    String? productId,
    DateTime? purchasedAt,
    DateTime? expiresAt,
    bool? autoRenewEnabled,
  }) {
    return SubscriptionModel(
      isActive: isActive ?? this.isActive,
      planType: planType ?? this.planType,
      purchaseToken: purchaseToken ?? this.purchaseToken,
      productId: productId ?? this.productId,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      autoRenewEnabled: autoRenewEnabled ?? this.autoRenewEnabled,
    );
  }

  /// Human-readable plan name.
  String get planName {
    if (!isActive) return 'Free';
    return planType == 'yearly' ? 'Pro Yearly' : 'Pro Monthly';
  }
}
