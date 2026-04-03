import 'dart:convert';
import '../models/appointment.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';

class AppointmentRepository {
  final _db = DatabaseService.instance;

  Map<String, dynamic> _toRow(Appointment a) => {
    'id': a.id,
    'userId': null,
    'clientName': a.clientName,
    'carModel': a.carModel,
    'carNumber': a.carNumber,
    'dateTime': a.dateTime.toIso8601String(),
    'washType': a.washType.name,
    'additionalServices': jsonEncode(a.additionalServices),
    'status': a.status,
    'notes': a.notes,
    'isFavorite': a.isFavorite ? 1 : 0,
    'ownerUsername': a.ownerUsername,
    'promoPrice': a.promoPrice,
    'paidPrice': a.paidPrice,
  };

  Appointment _fromRow(Map<String, dynamic> r) => Appointment(
    id: r['id'],
    clientName: r['clientName'],
    carModel: r['carModel'],
    carNumber: r['carNumber'],
    dateTime: DateTime.parse(r['dateTime']),
    washType: WashTypeX.fromString(r['washType']),
    additionalServices: List<String>.from(
        jsonDecode(r['additionalServices'] ?? '[]')),
    status: r['status'],
    notes: r['notes'] ?? '',
    isFavorite: r['isFavorite'] == 1,
    ownerUsername: r['ownerUsername'] ?? '',
    promoPrice: (r['promoPrice'] as num?)?.toInt() ?? 0,
    paidPrice: (r['paidPrice'] as num?)?.toInt() ?? 0,
  );

  Future<List<Appointment>> getAll() async {
    final db = await _db.db;
    final rows = await db.query('appointments', orderBy: 'dateTime ASC');
    return rows.map(_fromRow).toList();
  }

  Future<List<Appointment>> getByOwner(String username) async {
    final db = await _db.db;
    final rows = await db.query('appointments',
        where: 'ownerUsername = ?',
        whereArgs: [username.toLowerCase()],
        orderBy: 'dateTime ASC');
    return rows.map(_fromRow).toList();
  }

  Future<void> insert(Appointment a) async {
    final db = await _db.db;
    await db.insert('appointments', _toRow(a),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Appointment a) async {
    final db = await _db.db;
    await db.update('appointments', _toRow(a),
        where: 'id = ?', whereArgs: [a.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.db;
    await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleFavorite(String id) async {
    final db = await _db.db;
    await db.rawUpdate(
        'UPDATE appointments SET isFavorite = CASE WHEN isFavorite=1 THEN 0 ELSE 1 END WHERE id=?',
        [id]);
  }

  Future<List<Appointment>> getFavorites() async {
    final db = await _db.db;
    final rows = await db.query('appointments',
        where: 'isFavorite = 1', orderBy: 'dateTime ASC');
    return rows.map(_fromRow).toList();
  }

  Future<Map<String, int>> getStats() async {
    final db = await _db.db;
    final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM appointments')) ?? 0;
    final scheduled = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM appointments WHERE status='scheduled'")) ?? 0;
    final completed = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM appointments WHERE status='completed'")) ?? 0;
    return {'total': total, 'scheduled': scheduled, 'completed': completed};
  }
}
