import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Helper for reading or creating the 256-bit SQLCipher key for the offline
/// Drift database. The key is stored in the platform keychain/keystore via
/// [FlutterSecureStorage].
class DatabaseKey {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'lanwash_db_key';

  /// Returns the existing hex-encoded 256-bit key or generates a new one.
  static Future<String> getOrCreate() async {
    var key = await _storage.read(key: _keyName);
    if (key != null && key.length == 64) return key;

    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _keyName, value: key);
    return key;
  }
}
