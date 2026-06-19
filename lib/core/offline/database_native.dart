import 'dart:developer';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import 'database_key.dart';

/// Opens an encrypted SQLCipher-backed Drift database for native platforms.
QueryExecutor createNativeEncryptedDatabase() {
  return LazyDatabase(() async {
    // The workaround uses a platform channel, so it must run on the main
    // isolate before drift spawns its background isolate.
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();

    final docsDir = await getApplicationDocumentsDirectory();
    final encryptedPath = p.join(docsDir.path, 'lanwash_offline_db.enc');
    final oldPlainPath = p.join(docsDir.path, 'lanwash_offline_db.sqlite');
    final key = await DatabaseKey.getOrCreate();

    return NativeDatabase.createInBackground(
      File(encryptedPath),
      isolateSetup: () {
        // On Android we have to tell the sqlite3 package to load libsqlcipher
        // instead of the system's libsqlite3. This override must also be set
        // in the background isolate used by drift.
        if (Platform.isAndroid) {
          open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
        }

        // Migration from the old unencrypted Drift database is intentionally
        // simple: SQLCipher cannot easily import a plain SQLite file, and the
        // offline cache can be rebuilt from the backend. We drop the old file
        // so the user starts with a fresh encrypted database.
        _removeOldUnencryptedDatabase(oldPlainPath, encryptedPath);
      },
      setup: (rawDb) {
        final cipherResult = rawDb.select('PRAGMA cipher_version;');
        if (cipherResult.isEmpty) {
          throw UnsupportedError('SQLCipher is not available');
        }

        final escapedKey = key.replaceAll("'", "''");
        rawDb.execute("PRAGMA key = '$escapedKey';");
        rawDb.config.doubleQuotedStringLiterals = false;
      },
    );
  });
}

void _removeOldUnencryptedDatabase(String oldPath, String encryptedPath) {
  final oldFile = File(oldPath);
  final encryptedFile = File(encryptedPath);

  if (oldFile.existsSync() && !encryptedFile.existsSync()) {
    log(
      'Unencrypted offline DB found at $oldPath. '
      'Removing it and starting fresh with an encrypted database.',
      name: 'AppDatabase',
    );
    try {
      oldFile.deleteSync();
    } on Object catch (e) {
      log('Failed to delete old unencrypted DB: $e', name: 'AppDatabase');
    }
  }
}
