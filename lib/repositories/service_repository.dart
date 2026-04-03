import 'package:sqflite/sqflite.dart';
import '../models/service.dart';
import '../services/database_service.dart';

class ServiceRepository {
  final _db = DatabaseService.instance;

  Map<String, dynamic> _toRow(Service s) => {
    'id': s.id,
    'name': s.name,
    'description': s.description,
    'price': s.price,
    'durationMinutes': s.durationMinutes,
    'category': s.category,
    'isFavorite': s.isFavorite ? 1 : 0,
    'isFromApi': s.isFromApi ? 1 : 0,
    'updatedAt': DateTime.now().toIso8601String(),
  };

  Service _fromRow(Map<String, dynamic> r) => Service(
    id: r['id']?.toString() ?? '',
    name: r['name'] ?? '',
    description: r['description'] ?? '',
    price: (r['price'] as num?)?.toInt() ?? 0,
    durationMinutes: (r['durationMinutes'] as num?)?.toInt() ?? 30,
    category: r['category'] ?? '',
    isFavorite: r['isFavorite'] == 1,
    isFromApi: r['isFromApi'] == 1,
  );

  Future<List<Service>> getAll() async {
    final db = await _db.db;
    final rows = await db.query('services', orderBy: 'category ASC, name ASC');
    return rows.map(_fromRow).toList();
  }

  Future<List<Service>> getByCategory(String category) async {
    final db = await _db.db;
    final rows = await db.query('services',
        where: 'category = ?', whereArgs: [category]);
    return rows.map(_fromRow).toList();
  }

  Future<List<Service>> getFavorites() async {
    final db = await _db.db;
    final rows = await db.query('services',
        where: 'isFavorite = 1', orderBy: 'name ASC');
    return rows.map(_fromRow).toList();
  }

  Future<List<Service>> getPromos() async {
    final db = await _db.db;
    final rows = await db.query('services',
        where: 'isFromApi = 1', orderBy: 'price ASC');
    return rows.map(_fromRow).toList();
  }

  Future<void> insert(Service s) async {
    final db = await _db.db;
    await db.insert('services', _toRow(s),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Service s) async {
    final db = await _db.db;
    await db.update('services', _toRow(s),
        where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.db;
    await db.delete('services', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleFavorite(String id) async {
    final db = await _db.db;
    await db.rawUpdate(
        'UPDATE services SET isFavorite = CASE WHEN isFavorite=1 THEN 0 ELSE 1 END WHERE id=?',
        [id]);
  }

  /// Обновляем акции из API — удаляем старые, вставляем новые
  Future<void> replacePromos(List<Service> promos) async {
    final db = await _db.db;
    final batch = db.batch();
    batch.delete('services', where: 'isFromApi = 1');
    for (final p in promos) {
      batch.insert('services', _toRow(p),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<String>> getCategories() async {
    final db = await _db.db;
    final rows = await db.rawQuery(
        'SELECT DISTINCT category FROM services WHERE isFromApi=0 ORDER BY category');
    return rows.map((r) => r['category'] as String).toList();
  }
}
