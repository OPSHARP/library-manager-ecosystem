import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around the platform keystore-backed secure storage
/// (Android Keystore/EncryptedSharedPreferences, iOS Keychain).
///
/// Used for anything sensitive on the device — the student session (PII:
/// name, email, phones, address, student unique id) and library linkage.
/// Non-sensitive preferences (theme, language, ad config) stay in
/// SharedPreferences.
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  static SecureStorageService get instance => _instance;

  factory SecureStorageService() {
    return _instance;
  }

  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Saves a string value securely.
  Future<void> saveString(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Retrieves a saved string value.
  Future<String?> getString(String key) async {
    return await _storage.read(key: key);
  }

  /// Deletes a specific value.
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Removes a list of keys in one call.
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await _storage.delete(key: key);
    }
  }

  /// Clears all secure storage data.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
