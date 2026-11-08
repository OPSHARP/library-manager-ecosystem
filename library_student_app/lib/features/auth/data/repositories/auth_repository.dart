import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/secure_storage_service.dart';

/// Persists the student's session.
///
/// All session data — including PII (name, email, phones, address) and the
/// student unique id / profile id — is stored in platform keystore-backed
/// SECURE storage (Android Keystore / iOS Keychain) via
/// [SecureStorageService], never in plain SharedPreferences.
///
/// A one-time migration moves any session a previous version left in
/// SharedPreferences into secure storage and clears the legacy copy.
class AuthRepository {
  /// Keys that make up the persisted session.
  static const List<String> _sessionKeys = [
    AppConstants.prefProfileId,
    AppConstants.prefStudentUniqueId,
    AppConstants.prefName,
    AppConstants.prefEmail,
    AppConstants.prefMobile,
    AppConstants.prefParentMobile,
    AppConstants.prefAddress,
    AppConstants.prefRequestPending,
    AppConstants.prefLeaveRequestPending,
    AppConstants.prefOwnerUid,
    AppConstants.prefLibraryId,
    AppConstants.prefLibraryName,
    AppConstants.prefLibraryPhone,
    AppConstants.prefLibraryAddress,
  ];

  /// Library-linkage keys (removed when the student leaves a library while
  /// the account + profile session stay intact).
  static const List<String> _libraryKeys = [
    AppConstants.prefOwnerUid,
    AppConstants.prefLibraryId,
    AppConstants.prefLibraryName,
    AppConstants.prefLibraryPhone,
    AppConstants.prefLibraryAddress,
    AppConstants.prefRequestPending,
    AppConstants.prefLeaveRequestPending,
  ];

  Future<bool> saveSession({
    required String profileId,
    required String studentUniqueId,
    String? name,
    String? email,
    String? mobile,
    String? parentMobile,
    String? address,
    String? ownerUid,
    String? libraryId,
    String? libraryName,
    String? libraryPhone,
    String? libraryAddress,
    bool? requestPending,
    bool? leaveRequestPending,
  }) async {
    try {
      final storage = SecureStorageService.instance;
      await storage.saveString(AppConstants.prefProfileId, profileId);
      await storage.saveString(AppConstants.prefStudentUniqueId, studentUniqueId);
      if (name != null) await storage.saveString(AppConstants.prefName, name);
      if (email != null) await storage.saveString(AppConstants.prefEmail, email);
      if (mobile != null) await storage.saveString(AppConstants.prefMobile, mobile);
      if (parentMobile != null) {
        await storage.saveString(AppConstants.prefParentMobile, parentMobile);
      }
      if (address != null) await storage.saveString(AppConstants.prefAddress, address);
      if (requestPending != null) {
        await storage.saveString(AppConstants.prefRequestPending, requestPending.toString());
      }
      if (leaveRequestPending != null) {
        await storage.saveString(AppConstants.prefLeaveRequestPending, leaveRequestPending.toString());
      }
      if (ownerUid != null) await storage.saveString(AppConstants.prefOwnerUid, ownerUid);
      if (libraryId != null) await storage.saveString(AppConstants.prefLibraryId, libraryId);
      if (libraryName != null) {
        await storage.saveString(AppConstants.prefLibraryName, libraryName);
      }
      if (libraryPhone != null) {
        await storage.saveString(AppConstants.prefLibraryPhone, libraryPhone);
      }
      if (libraryAddress != null) {
        await storage.saveString(AppConstants.prefLibraryAddress, libraryAddress);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String?>> getSession() async {
    final storage = SecureStorageService.instance;
    await _migrateLegacySession(storage);
    return {
      'profileId': await storage.getString(AppConstants.prefProfileId),
      'studentUniqueId': await storage.getString(AppConstants.prefStudentUniqueId),
      'name': await storage.getString(AppConstants.prefName),
      'email': await storage.getString(AppConstants.prefEmail),
      'mobile': await storage.getString(AppConstants.prefMobile),
      'parentMobile': await storage.getString(AppConstants.prefParentMobile),
      'address': await storage.getString(AppConstants.prefAddress),
      'requestPending':
          (await storage.getString(AppConstants.prefRequestPending)) ?? 'false',
      'leaveRequestPending':
          (await storage.getString(AppConstants.prefLeaveRequestPending)) ?? 'false',
      'ownerUid': await storage.getString(AppConstants.prefOwnerUid),
      'libraryId': await storage.getString(AppConstants.prefLibraryId),
      'libraryName': await storage.getString(AppConstants.prefLibraryName),
      'libraryPhone': await storage.getString(AppConstants.prefLibraryPhone),
      'libraryAddress': await storage.getString(AppConstants.prefLibraryAddress),
    };
  }

  /// One-time upgrade: a previous build stored the session in plain
  /// SharedPreferences. Move any such session into secure storage and wipe
  /// the plaintext copy so PII is never left lying around.
  Future<void> _migrateLegacySession(SecureStorageService storage) async {
    // Already migrated — no legacy copy to move.
    if (await storage.getString(AppConstants.prefProfileId) != null) return;

    final prefs = await SharedPreferences.getInstance();
    final legacyProfileId = prefs.getString(AppConstants.prefProfileId);
    if (legacyProfileId == null) return;

    for (final key in _sessionKeys) {
      final value = prefs.get(key);
      if (value != null) {
        await storage.saveString(key, value.toString());
        await prefs.remove(key);
      }
    }
  }

  Future<void> clearSession() async {
    final storage = SecureStorageService.instance;
    await storage.deleteAll(_sessionKeys);
    // Also remove any legacy plaintext keys.
    final prefs = await SharedPreferences.getInstance();
    for (final key in _sessionKeys) {
      await prefs.remove(key);
    }
  }

  /// Clears only the library linkage (keep the account + profile session) so
  /// a student can leave a library and rejoin another without signing in.
  Future<void> clearLibrarySession() async {
    final storage = SecureStorageService.instance;
    await storage.deleteAll(_libraryKeys);
    final prefs = await SharedPreferences.getInstance();
    for (final key in _libraryKeys) {
      await prefs.remove(key);
    }
  }

  Future<Map<String, dynamic>?> searchLibraryByCode(String code) async {
    final registry = await FirestoreService.lookupLibraryByCode(code);
    if (registry == null) return null;

    // Enrich with the public library doc (seat capacity, available seats,
    // facilities, currency, contact, address) so students see live capacity /
    // currency when searching by code or scanning. `users/{owner}/libraries`
    // is readable by any authenticated student under the Firestore rules.
    try {
      final owner = registry['ownerUid'] as String?;
      final libraryId = registry['libraryId'] as String?;
      final lib = await fetchLibraryDoc(owner, libraryId);
      if (lib != null) {
        registry['seatCapacity'] = lib['seatCapacity'] ?? registry['seatCapacity'] ?? 0;
        registry['availableSeats'] = lib['availableSeats'] ?? registry['availableSeats'] ?? 0;
        registry['currency'] = lib['currency'] ?? registry['currency'] ?? '\$';
        registry['facilities'] = lib['facilities'] ?? registry['facilities'] ?? const <String>[];
        if ((registry['contactNumber'] ?? '').toString().isEmpty) {
          registry['contactNumber'] = lib['contactNumber'] ?? '';
        }
        if ((registry['address'] ?? '').toString().isEmpty) {
          registry['address'] = lib['address'] ?? '';
        }
      }
    } catch (_) {
      // Registry data is still usable without the enrichment.
    }
    return registry;
  }

  /// Reads a library's public document fields (readable by any authenticated
  /// student). Returns an empty map when the doc does not exist.
  Future<Map<String, dynamic>?> fetchLibraryDoc(String? ownerUid, String? libraryId) async {
    if (ownerUid == null || ownerUid.isEmpty || libraryId == null || libraryId.isEmpty) {
      return null;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .doc('users/$ownerUid/libraries/$libraryId')
          .get();
      return doc.exists ? doc.data() : null;
    } catch (_) {
      return null;
    }
  }
}
