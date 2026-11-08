import 'dart:math';

import 'package:latlong2/latlong.dart';

/// A library registered by a Library Manager & Owner app user, as seen by a
/// student browsing nearby libraries. Only PUBLIC info (name, address,
/// contact, capacity) is exposed — seat-level data stays owner/joined-only.
class NearbyLibrary {
  final String ownerUid;
  final String libraryId;
  final String libraryName;
  final String address;
  final String contactNumber;
  final int totalSeats;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  const NearbyLibrary({
    required this.ownerUid,
    required this.libraryId,
    required this.libraryName,
    this.address = '',
    this.contactNumber = '',
    this.totalSeats = 0,
    this.latitude,
    this.longitude,
    this.distanceKm,
  });

  NearbyLibrary copyWith({double? latitude, double? longitude, double? distanceKm}) {
    return NearbyLibrary(
      ownerUid: ownerUid,
      libraryId: libraryId,
      libraryName: libraryName,
      address: address,
      contactNumber: contactNumber,
      totalSeats: totalSeats,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  LatLng? get latLng =>
      (latitude != null && longitude != null) ? LatLng(latitude!, longitude!) : null;

  String get distanceDisplay {
    final d = distanceKm;
    if (d == null) return '—';
    if (d < 1) return '${(d * 1000).round()} m';
    return '${d.toStringAsFixed(1)} km';
  }

  /// Haversine distance in km from [from] to this library's coordinates.
  static double distanceBetween(LatLng a, LatLng b) {
    const r = 6371.0; // Earth radius in km
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(a.latitude)) * cos(_rad(b.latitude)) *
            sin(dLon / 2) * sin(dLon / 2);
    return 2 * r * asin(sqrt(h));
  }

  static double _rad(double deg) => deg * pi / 180;
}
