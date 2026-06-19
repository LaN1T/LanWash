import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

import 'database_native.dart' if (dart.library.html) 'database_stub.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    CachedWashTypes,
    CachedUsers,
    CachedAppointments,
    CachedShifts,
    PendingActions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    // The web build continues to use the unencrypted Drift WASM database.
    if (kIsWeb) {
      return driftDatabase(
        name: 'lanwash_offline_db',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.dart.js'),
        ),
      );
    }

    // Android, iOS, macOS, Windows, Linux: open an encrypted SQLCipher file.
    return createNativeEncryptedDatabase();
  }
}
