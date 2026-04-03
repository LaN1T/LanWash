import '../models/log_entry.dart';
import '../services/database_service.dart';

class LogRepository {
  final _db = DatabaseService.instance;

  Future<void> insert(LogEntry entry) async {
    final db = await _db.db;
    await db.insert('logs', entry.toMap());
  }

  Future<List<LogEntry>> getAll({int limit = 200}) async {
    final db = await _db.db;
    final rows = await db.query('logs',
        orderBy: 'timestamp DESC', limit: limit);
    return rows.map(LogEntry.fromMap).toList();
  }

  Future<List<LogEntry>> getByUser(String username) async {
    final db = await _db.db;
    final rows = await db.query('logs',
        where: 'username = ?',
        whereArgs: [username.toLowerCase()],
        orderBy: 'timestamp DESC');
    return rows.map(LogEntry.fromMap).toList();
  }

  Future<void> clearAll() async {
    final db = await _db.db;
    await db.delete('logs');
  }
}
