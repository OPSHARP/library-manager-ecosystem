import 'dart:convert';
import 'package:crypto/crypto.dart';

const String _pepper = 'L1br4ryM4n4g3r#2025!';
const int _iterations = 120000;
const int _keyLength = 32;

/// Computes PBKDF2-HMAC-SHA256 manually (the `crypto` package did not export
/// Pbkdf2 at the time of writing).
List<int> _pbkdf2({
  required List<int> password,
  required List<int> salt,
  required int iterations,
  required int keyLength,
}) {
  final hmac = Hmac(sha256, password);
  final blockCount = (keyLength / 32).ceil();

  List<int> derived = [];
  for (int block = 1; block <= blockCount; block++) {
    final blockSalt = [...salt, ..._to4Bytes(block)];
    var u = hmac.convert(blockSalt).bytes;
    var t = List<int>.from(u);

    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int j = 0; j < u.length; j++) {
        t[j] ^= u[j];
      }
    }
    derived.addAll(t);
  }
  return derived.take(keyLength).toList();
}

List<int> _to4Bytes(int value) {
  return [
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];
}

/// Hashes [password] using PBKDF2-HMAC-SHA256 with a salt derived from
/// [_pepper] and an optional per-user [salt] (e.g. the user's email or uid).
///
/// Returns a colon-delimited string:  "iterations:saltBase64:derivedKeyBase64"
/// The stored hash is self-describing so that iteration count can be increased
/// in the future without breaking existing hashes.
String hashPassword(String password, {String? salt}) {
  final effectiveSalt = utf8.encode('${salt ?? ''}:$_pepper');
  final key = _pbkdf2(
    password: utf8.encode(password),
    salt: effectiveSalt,
    iterations: _iterations,
    keyLength: _keyLength,
  );
  final saltB64 = base64Encode(effectiveSalt);
  final keyB64 = base64Encode(key);
  return '$_iterations:$saltB64:$keyB64';
}

/// Verifies [password] against a hash previously produced by [hashPassword].
///
/// Supports both the legacy SHA-256 format and the current PBKDF2 format so
/// that existing passwords continue to work after upgrading the algorithm.
bool verifyPassword(String password, String storedHash, {String? salt}) {
  // ── Legacy SHA-256 format (no colons or not starting with a digit) ──
  if (!storedHash.contains(':') || !RegExp(r'^\d+:').hasMatch(storedHash)) {
    final key = salt ?? _pepper;
    final bytes = utf8.encode('$key:$password');
    return sha256.convert(bytes).toString() == storedHash;
  }

  // ── Current PBKDF2 format ──
  final parts = storedHash.split(':');
  if (parts.length != 3) return false;
  final iterations = int.tryParse(parts[0]) ?? _iterations;
  final saltBytes = base64Decode(parts[1]);
  final expectedKey = base64Decode(parts[2]);

  final key = _pbkdf2(
    password: utf8.encode(password),
    salt: saltBytes,
    iterations: iterations,
    keyLength: expectedKey.length,
  );
  return _secureCompare(key, expectedKey);
}

/// Constant-time comparison to prevent timing attacks.
bool _secureCompare(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a[i] ^ b[i];
  }
  return result == 0;
}
