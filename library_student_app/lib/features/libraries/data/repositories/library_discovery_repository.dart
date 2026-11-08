import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/nearby_library.dart';

/// Discovers libraries registered in the Library Manager & Owner app and
/// locates them using the OpenStreetMap Nominatim geocoding API.
///
/// Only public library info is read (library_registry + libraries docs) —
/// seat assignments and student records are never fetched here.
class LibraryDiscoveryRepository {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// All registered libraries with their public library doc (capacity etc.).
  /// Verifies that the owner's library is active and filters out any library
  /// that was deleted in the Library Manager & Owner app.
  Future<List<NearbyLibrary>> fetchLibraries() async {
    final registry = await _db.collection('registered_libraries').get();

    final futures = registry.docs.map((doc) async {
      final data = doc.data();
      final libraryId = (data['libraryId'] as String? ?? doc.id).trim();
      if (libraryId.isEmpty) return null;
      if (data['isDeleted'] == true) return null;

      final ownerUid = (data['ownerUid'] as String? ?? '').trim();
      if (ownerUid.isEmpty) return null;

      // Verify that the library actually exists under the owner's account.
      // If the owner deleted their library or their account, this doc will not exist.
      try {
        final libDoc =
            await _db.doc('users/$ownerUid/libraries/$libraryId').get();
        if (!libDoc.exists) {
          // Library was deleted by the owner — do NOT show in Nearby!
          return null;
        }

        final libData = libDoc.data();
        if (libData == null || libData['isDeleted'] == true) {
          return null;
        }

        final totalSeats = (libData['seatCapacity'] as num?)?.toInt() ??
            (data['seatCapacity'] as num?)?.toInt() ??
            0;

        final name = (libData['libraryName'] as String?)?.isNotEmpty == true
            ? libData['libraryName'] as String
            : (data['libraryName'] as String? ?? 'Library');

        final address = (libData['address'] as String?)?.isNotEmpty == true
            ? libData['address'] as String
            : (data['address'] as String? ?? '');

        final contactNumber = (libData['contactNumber'] as String?)?.isNotEmpty == true
            ? libData['contactNumber'] as String
            : (data['contactNumber'] as String? ?? '');

        final lat = (libData['latitude'] as num?)?.toDouble() ??
            (data['latitude'] as num?)?.toDouble();

        final lng = (libData['longitude'] as num?)?.toDouble() ??
            (data['longitude'] as num?)?.toDouble();

        return NearbyLibrary(
          ownerUid: ownerUid,
          libraryId: libraryId,
          libraryName: name,
          address: address,
          contactNumber: contactNumber,
          totalSeats: totalSeats,
          latitude: lat,
          longitude: lng,
        );
      } catch (_) {
        // If owner doc or library doc is inaccessible, omit this library.
        return null;
      }
    });

    final allResults = await Future.wait(futures);
    return allResults.whereType<NearbyLibrary>().toList();
  }

  Future<Position?> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      return null;
    }
  }

  /// Geocodes an address to coordinates via OSM Nominatim. Returns null when
  /// the address cannot be resolved (or the request fails).
  Future<LatLng?> geocode(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
        queryParameters: {'q': address.trim(), 'format': 'json', 'limit': '1'},
      );
      final res = await http.get(
        uri,
        headers: const {'User-Agent': 'LMStudents/1.0 (library-student-portal)'},
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as List;
      if (data.isEmpty) return null;
      final lat = double.tryParse(data[0]['lat']?.toString() ?? '');
      final lon = double.tryParse(data[0]['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }
}
