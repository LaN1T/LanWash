import '../services/database_service.dart';

class ServiceFavoritesRepository {
  final _db = DatabaseService.instance;

  Future<Set<String>> getForUser(String username) async {
    final db = await _db.db;
    final rows = await db.query('service_favorites',
        where: 'username = ?', whereArgs: [username.toLowerCase()]);
    return rows.map((r) => r['serviceId'] as String).toSet();
  }

  Future<void> toggle(String username, String serviceId) async {
    final db = await _db.db;
    final existing = await db.query('service_favorites',
        where: 'username = ? AND serviceId = ?',
        whereArgs: [username.toLowerCase(), serviceId]);
    if (existing.isEmpty) {
      await db.insert('service_favorites',
          {'username': username.toLowerCase(), 'serviceId': serviceId});
    } else {
      await db.delete('service_favorites',
          where: 'username = ? AND serviceId = ?',
          whereArgs: [username.toLowerCase(), serviceId]);
    }
  }
}
