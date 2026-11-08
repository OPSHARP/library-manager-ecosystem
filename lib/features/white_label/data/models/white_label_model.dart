import 'package:cloud_firestore/cloud_firestore.dart';

class WhiteLabelRequestModel {
  final String requestId;
  final String ownerId;
  final String libraryName;
  final String tagline;
  final String primaryColorHex;
  final String secondaryColorHex;
  final String packageTier; // 'standard_4999' or 'premium_9999'
  final String packagePrice; // '₹4,999' or '₹9,999'
  final String contactPhone;
  final String contactEmail;
  final String status; // 'pending', 'in_progress', 'completed'
  final DateTime createdAt;

  const WhiteLabelRequestModel({
    required this.requestId,
    required this.ownerId,
    required this.libraryName,
    required this.tagline,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    required this.packageTier,
    required this.packagePrice,
    required this.contactPhone,
    required this.contactEmail,
    this.status = 'pending',
    required this.createdAt,
  });

  factory WhiteLabelRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return WhiteLabelRequestModel(
      requestId: doc.id,
      ownerId: data['ownerId'] ?? '',
      libraryName: data['libraryName'] ?? '',
      tagline: data['tagline'] ?? '',
      primaryColorHex: data['primaryColorHex'] ?? '#6366F1',
      secondaryColorHex: data['secondaryColorHex'] ?? '#8B5CF6',
      packageTier: data['packageTier'] ?? 'standard_4999',
      packagePrice: data['packagePrice'] ?? '₹4,999',
      contactPhone: data['contactPhone'] ?? '',
      contactEmail: data['contactEmail'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requestId': requestId,
      'ownerId': ownerId,
      'libraryName': libraryName,
      'tagline': tagline,
      'primaryColorHex': primaryColorHex,
      'secondaryColorHex': secondaryColorHex,
      'packageTier': packageTier,
      'packagePrice': packagePrice,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
