import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_model.dart';
import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/firestore_service.dart';

class LibraryRepository {
  final FirestoreService _fs;

  LibraryRepository(this._fs);

  static const String _currentLibKey = 'current_library_id';

  static const String _registryCol = 'library_registry';

  CollectionReference<Map<String, dynamic>> get _registry =>
      FirebaseFirestore.instance.collection(_registryCol);

  Stream<LibraryModel?> getLibrary(String libraryId) {
    return _fs.librariesCol.doc(libraryId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LibraryModel.fromFirestore(doc);
    });
  }

  Future<LibraryModel?> getLibrarySync(String libraryId) async {
    final doc = await _fs.librariesCol.doc(libraryId).get();
    if (!doc.exists) return null;
    return LibraryModel.fromFirestore(doc);
  }

  Stream<String?> getLibraryIdForUser(String userId) {
    return _fs.librariesCol
        .where('ownerId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.id;
    });
  }

  Future<String?> getLibraryIdForUserSync(String userId) async {
    final snapshot = await _fs.librariesCol
        .where('ownerId', isEqualTo: userId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  Future<void> updateLibrary(String libraryId, LibraryModel library) async {
    await _fs.librariesCol
        .doc(libraryId)
        .set(library.toFirestore(), SetOptions(merge: true));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentLibKey, libraryId);
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  /// Partial update for branding fields only (logo, banner, theme color).
  Future<void> updateBranding(
    String libraryId, {
    String? logoUrl,
    String? bannerUrl,
    String? themeColor,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (logoUrl != null) data['logoUrl'] = logoUrl;
    if (bannerUrl != null) data['bannerUrl'] = bannerUrl;
    if (themeColor != null) data['themeColor'] = themeColor;
    await _fs.librariesCol.doc(libraryId).set(data, SetOptions(merge: true));
  }

  Future<String> generateUniqueCode() async {
    final rng = Random();
    for (int attempt = 0; attempt < 20; attempt++) {
      final code = List.generate(6, (_) =>
          'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[rng.nextInt(30)]).join();
      final doc = await _registry.doc(code).get();
      if (!doc.exists) return code;
    }
    final fallback = DateTime.now().millisecondsSinceEpoch.toRadixString(36)
        .substring(4, 10).toUpperCase();
    return fallback;
  }

  Future<void> registerLibraryCode(String code, String ownerUid,
      String libraryId, String libraryName,
      {String? contactNumber, String? address, double? latitude, double? longitude,
      int? seatCapacity, List<String> facilities = const []}) async {
    // merge: true so both the first save (create) and later saves (update)
    // of the same code succeed under the Firestore rules.
    await _registry.doc(code).set({
      'ownerUid': ownerUid,
      'libraryId': libraryId,
      'libraryName': libraryName,
      'contactNumber': contactNumber ?? '',
      'address': address ?? '',
      'seatCapacity': seatCapacity ?? 0,
      'facilities': facilities,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Also save to the registered_libraries collection for the map feature
    final mapData = <String, dynamic>{
      'ownerUid': ownerUid,
      'libraryId': libraryId,
      'libraryName': libraryName,
      'libraryCode': code,
      'address': address ?? '',
      'seatCapacity': seatCapacity ?? 0,
      'facilities': facilities,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (latitude != null) mapData['latitude'] = latitude;
    if (longitude != null) mapData['longitude'] = longitude;

    await FirebaseFirestore.instance.collection('registered_libraries').doc(libraryId).set(mapData, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> lookupLibraryByCode(String code) async {
    final doc = await _registry.doc(code.toUpperCase()).get();
    return doc.data();
  }

  /// Pings / updates the library's public location shown to all students.
  /// Writes coordinates + address to the public registry (`registered_libraries`),
  /// the owner's library document, and the code registry so the student map and
  /// dashboard stay in sync.
  Future<void> updateLibraryLocation({
    required String libraryId,
    required String ownerUid,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    final now = Timestamp.fromDate(DateTime.now());
    final lib = await getLibrarySync(libraryId);
    final name = lib?.libraryName ?? 'Library';
    final contact = lib?.contactNumber ?? '';
    final code = lib?.libraryCode ?? '';
    final seatCapacity = lib?.seatCapacity ?? 0;
    final facilities = lib?.facilities ?? const <String>[];

    final mapData = <String, dynamic>{
      'ownerUid': ownerUid,
      'libraryId': libraryId,
      'libraryName': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'contactNumber': contact,
      'seatCapacity': seatCapacity,
      'facilities': facilities,
      'updatedAt': now,
    };
    await FirebaseFirestore.instance
        .collection('registered_libraries')
        .doc(libraryId)
        .set(mapData, SetOptions(merge: true));

    await _fs.librariesCol.doc(libraryId).set({
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': now,
    }, SetOptions(merge: true));

    if (code.isNotEmpty) {
      await _registry.doc(code).set({
        'ownerUid': ownerUid,
        'libraryId': libraryId,
        'libraryName': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'seatCapacity': seatCapacity,
        'facilities': facilities,
        'updatedAt': now,
      }, SetOptions(merge: true));
    }

    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  /// Reads the currently published library location (if any) from the public
  /// registry used by the student "Nearby Libraries" map.
  Future<Map<String, dynamic>?> getLibraryLocation(String libraryId) async {
    final doc = await FirebaseFirestore.instance
        .collection('registered_libraries')
        .doc(libraryId)
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    final lat = (data?['latitude'] as num?)?.toDouble();
    final lng = (data?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return {
      'latitude': lat,
      'longitude': lng,
      'address': data?['address'] as String? ?? '',
      'updatedAt': data?['updatedAt'],
    };
  }

  /// Removes the library's location from the public registered_libraries
  /// collection and clears coordinates from the owner's library doc,
  /// immediately removing it from the student app's Nearby Libraries map.
  Future<void> removeLibraryLocation(String libraryId) async {
    try {
      await FirebaseFirestore.instance
          .collection('registered_libraries')
          .doc(libraryId)
          .delete();
    } catch (_) {}

    try {
      await _fs.librariesCol.doc(libraryId).update({
        'latitude': FieldValue.delete(),
        'longitude': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> unregisterLibraryCode(String code, {String? libraryId}) async {
    await _registry.doc(code).delete();
    if (libraryId != null && libraryId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('registered_libraries')
            .doc(libraryId)
            .delete();
      } catch (_) {}
    }
  }

  /// Permanently deletes the library document from the owner's account and removes
  /// its public presence from both `registered_libraries` (Nearby map) and
  /// `library_registry` (code lookup).
  Future<void> deleteLibrary(String libraryId, {String? code}) async {
    // 1. Remove from public nearby catalog
    try {
      await FirebaseFirestore.instance
          .collection('registered_libraries')
          .doc(libraryId)
          .delete();
    } catch (_) {}

    try {
      final regSnap = await FirebaseFirestore.instance
          .collection('registered_libraries')
          .where('ownerUid', isEqualTo: _fs.uid)
          .get();
      for (final doc in regSnap.docs) {
        if (doc.id == libraryId || doc.data()['libraryId'] == libraryId) {
          await doc.reference.delete();
        }
      }
    } catch (_) {}

    // 2. Remove code registration if known
    if (code != null && code.isNotEmpty) {
      try {
        await _registry.doc(code).delete();
      } catch (_) {}
    } else {
      try {
        final doc = await _fs.librariesCol.doc(libraryId).get();
        final libCode = doc.data()?['libraryCode'] as String?;
        if (libCode != null && libCode.isNotEmpty) {
          await _registry.doc(libCode).delete();
        }
      } catch (_) {}
    }

    // 3. Delete the owner's library doc
    try {
      await _fs.librariesCol.doc(libraryId).delete();
    } catch (_) {}

    // 4. Clear local stored library preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentLibKey);
  }

  Future<void> saveCurrentLibraryId(String libraryId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentLibKey, libraryId);
  }

  Future<String?> getCurrentLibraryId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentLibKey);
  }
}
