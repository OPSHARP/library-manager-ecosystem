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
  final String? themeColor;
  final int seatCapacity;
  final int totalStudents;
  final int activeStudents;
  final int availableSeats;
  final String currency;
  final List<String> facilities;
  final String? libraryCode;
  final String? qrData;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.themeColor,
    this.seatCapacity = 100,
    this.totalStudents = 0,
    this.activeStudents = 0,
    this.availableSeats = 0,
    this.currency = '\$',
    this.facilities = const [],
    this.libraryCode,
    this.qrData,
    this.createdAt,
    this.updatedAt,
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
      themeColor: json['themeColor'],
      seatCapacity: json['seatCapacity'] ?? 100,
      totalStudents: json['totalStudents'] ?? 0,
      activeStudents: json['activeStudents'] ?? 0,
      availableSeats: json['availableSeats'] ?? 0,
      currency: (json['currency'] as String?) ?? '\$',
      facilities: _listOfString(json['facilities']),
      libraryCode: json['libraryCode'],
      qrData: json['qrData'],
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'libraryId': libraryId,
      'ownerId': ownerId,
      'libraryName': libraryName,
      'address': address,
      'city': city,
      'contactNumber': contactNumber,
      'workingHours': workingHours,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'themeColor': themeColor,
      'seatCapacity': seatCapacity,
      'totalStudents': totalStudents,
      'activeStudents': activeStudents,
      'availableSeats': availableSeats,
      'currency': currency,
      'facilities': facilities,
      'libraryCode': libraryCode,
      'qrData': qrData,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  factory LibraryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return LibraryModel(libraryId: doc.id, ownerId: '', libraryName: '');
    }
    Map<String, String>? wh;
    final whRaw = data['workingHours'];
    if (whRaw is Map) {
      wh = whRaw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return LibraryModel(
      libraryId: data['libraryId'] ?? doc.id,
      ownerId: data['ownerId'] ?? '',
      libraryName: data['libraryName'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
      workingHours: wh ?? const {'open': '09:00', 'close': '22:00'},
      logoUrl: data['logoUrl'],
      bannerUrl: data['bannerUrl'],
      themeColor: data['themeColor'],
      seatCapacity: data['seatCapacity'] ?? 100,
      totalStudents: data['totalStudents'] ?? 0,
      activeStudents: data['activeStudents'] ?? 0,
      availableSeats: data['availableSeats'] ?? 0,
      currency: (data['currency'] as String?) ?? '\$',
      facilities: _listOfString(data['facilities']),
      libraryCode: data['libraryCode'],
      qrData: data['qrData'],
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'libraryId': libraryId,
      'ownerId': ownerId,
      'libraryName': libraryName,
      'address': address,
      'city': city,
      'contactNumber': contactNumber,
      'workingHours': workingHours,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'themeColor': themeColor,
      'seatCapacity': seatCapacity,
      'totalStudents': totalStudents,
      'activeStudents': activeStudents,
      'availableSeats': availableSeats,
      'currency': currency,
      'facilities': facilities,
      'libraryCode': libraryCode,
      'qrData': qrData,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  static const _sentinel = Object();

  LibraryModel copyWith({
    String? libraryName,
    String? address,
    String? city,
    String? contactNumber,
    Map<String, String>? workingHours,
    Object? logoUrl = _sentinel,
    Object? bannerUrl = _sentinel,
    Object? themeColor = _sentinel,
    int? seatCapacity,
    int? totalStudents,
    int? activeStudents,
    int? availableSeats,
    String? currency,
    Object? facilities = _sentinel,
    Object? libraryCode = _sentinel,
    Object? qrData = _sentinel,
  }) {
    return LibraryModel(
      libraryId: libraryId,
      ownerId: ownerId,
      libraryName: libraryName ?? this.libraryName,
      address: address ?? this.address,
      city: city ?? this.city,
      contactNumber: contactNumber ?? this.contactNumber,
      workingHours: workingHours ?? this.workingHours,
      logoUrl: logoUrl == _sentinel ? this.logoUrl : logoUrl as String?,
      bannerUrl: bannerUrl == _sentinel ? this.bannerUrl : bannerUrl as String?,
      themeColor: themeColor == _sentinel ? this.themeColor : themeColor as String?,
      seatCapacity: seatCapacity ?? this.seatCapacity,
      totalStudents: totalStudents ?? this.totalStudents,
      activeStudents: activeStudents ?? this.activeStudents,
      availableSeats: availableSeats ?? this.availableSeats,
      currency: currency ?? this.currency,
      facilities: facilities == _sentinel
          ? this.facilities
          : (facilities as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      libraryCode: libraryCode == _sentinel ? this.libraryCode : libraryCode as String?,
      qrData: qrData == _sentinel ? this.qrData : qrData as String?,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static List<String> _listOfString(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
