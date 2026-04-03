import '../services/database_service.dart';

/// Хранит избранные доп. услуги (чернение шин, воск…) по username
class ExtraFavoritesRepository {
  final _db = DatabaseService.instance;

  Future<Set<String>> getForUser(String username) async {
    final db = await _db.db;
    final rows = await db.query('extra_favorites',
        where: 'username = ?', whereArgs: [username.toLowerCase()]);
    return rows.map((r) => r['serviceName'] as String).toSet();
  }

  Future<void> toggle(String username, String serviceName) async {
    final db = await _db.db;
    final exists = await db.query('extra_favorites',
        where: 'username = ? AND serviceName = ?',
        whereArgs: [username.toLowerCase(), serviceName]);
    if (exists.isNotEmpty) {
      await db.delete('extra_favorites',
          where: 'username = ? AND serviceName = ?',
          whereArgs: [username.toLowerCase(), serviceName]);
    } else {
      await db.insert('extra_favorites',
          {'username': username.toLowerCase(), 'serviceName': serviceName});
    }
  }

  Future<void> clearForUser(String username) async {
    final db = await _db.db;
    await db.delete('extra_favorites',
        where: 'username = ?', whereArgs: [username.toLowerCase()]);
  }
}
