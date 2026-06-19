import 'package:drift/drift.dart';

/// Stub for web builds. The actual web database is opened in [database.dart]
/// via [driftDatabase], so this function is never called.
QueryExecutor createNativeEncryptedDatabase() {
  throw UnsupportedError(
    'Native encrypted database is not supported on the web',
  );
}
