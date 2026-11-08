import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription_model.dart';

/// Repository for managing subscription data in Firestore.
///
/// Subscription documents are stored at:
///   users/{uid}/subscription/current
class SubscriptionRepository {
  final FirebaseFirestore _firestore;
  final String uid;

  SubscriptionRepository({required this.uid})
    : _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection('users')
      .doc(uid)
      .collection('subscription')
      .doc('current');

  /// Fetch the current subscription status from Firestore.
  Future<SubscriptionModel> getSubscription() async {
    try {
      final doc = await _doc.get();
      if (!doc.exists) return SubscriptionModel.free;
      return SubscriptionModel.fromMap(doc.data()!);
    } catch (_) {
      return SubscriptionModel.free;
    }
  }

  /// Listen to real-time subscription updates.
  Stream<SubscriptionModel> watchSubscription() {
    return _doc.snapshots().map((snapshot) {
      if (!snapshot.exists) return SubscriptionModel.free;
      return SubscriptionModel.fromMap(snapshot.data()!);
    });
  }
}
