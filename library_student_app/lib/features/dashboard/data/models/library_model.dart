import 'package:cloud_firestore/cloud_firestore.dart';

class LibraryModel {
  final String libraryId;
  final String ownerId;
  final String libraryName;
  final String address;
  final String city;
  final String contactNumber;
  final Map<String, String> workingHours;
  final String? logoUrl;
  final String? bannerUrl;
  final int seatCapacity;
  final int availableSeats;
  final String currency;
  final String? themeColor;
  final DateTime? createdAt;

  const LibraryModel({
    required this.libraryId,
    required this.ownerId,
    required this.libraryName,
    this.address = '',
    this.city = '',
    this.contactNumber = '',
    this.workingHours = const {'open': '09:00', 'close': '22:00'},
    this.logoUrl,
    this.bannerUrl,
    this.seatCapacity = 0,
    this.availableSeats = 0,
    this.currency = '\$',
    this.themeColor,
    this.createdAt,
  });

  factory LibraryModel.fromJson(Map<String, dynamic> json) {
    Map<String, String>? wh;
    final whRaw = json['workingHours'];
    if (whRaw is Map) {
      wh = whRaw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return LibraryModel(
      libraryId: json['libraryId'] ?? '',
      ownerId: json['ownerId'] ?? '',
      libraryName: json['libraryName'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      workingHours: wh ?? const {'open': '09:00', 'close': '22:00'},
      logoUrl: json['logoUrl'],
      bannerUrl: json['bannerUrl'],
      seatCapacity: json['seatCapacity'] ?? 0,
      availableSeats: json['availableSeats'] ?? 0,
      currency: (json['currency'] as String?)?.isNotEmpty == true
          ? json['currency'] as String
          : '\$',
      themeColor: json['themeColor'],
      createdAt: _parseDate(json['createdAt']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }
}
