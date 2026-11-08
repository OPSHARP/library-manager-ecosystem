import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  /// Clears all secure storage data.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
