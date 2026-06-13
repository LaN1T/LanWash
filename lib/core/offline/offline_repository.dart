import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

class OfflineRepository {
  final AppDatabase _db;

  OfflineRepository(this._db);

  //region Wash types

  Future<void> saveWashTypes(List<Map<String, dynamic>> items) async {
    await _db.transaction(() async {
      for (final item in items) {
        await _db.into(_db.cachedWashTypes).insertOnConflictUpdate(
              CachedWashTypesCompanion.insert(
                id: _asString(item['id'])!,
                code: _asString(item['code'])!,
                name: _asString(item['name'])!,
                description: Value(_asString(item['description']) ?? ''),
                basePrice: Value(_asInt(item['basePrice']) ?? 0),
                durationMinutes: Value(_asInt(item['durationMinutes']) ?? 30),
                sortOrder: Value(_asInt(item['sortOrder']) ?? 0),
              ),
            );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getWashTypes() async {
    final rows = await _db.select(_db.cachedWashTypes).get();
    return rows.map((r) => r.toJson()).toList();
  }

  //endregion

  //region Users

  Future<void> saveUsers(List<Map<String, dynamic>> items) async {
    await _db.transaction(() async {
      for (final item in items) {
        await _db.into(_db.cachedUsers).insertOnConflictUpdate(
              CachedUsersCompanion.insert(
                id: Value(_asInt(item['id']) ?? 0),
                username: _asString(item['username'])!,
                displayName: _asString(item['displayName'])!,
                role: _asString(item['role'])!,
                avatarUrl: Value(_asString(item['avatarUrl'])),
              ),
            );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final rows = await _db.select(_db.cachedUsers).get();
    return rows.map((r) => r.toJson()).toList();
  }

  //endregion

  //region Appointments

  Future<void> saveAppointments(List<Map<String, dynamic>> items) async {
    await _db.transaction(() async {
      for (final item in items) {
        await _db.into(_db.cachedAppointments).insertOnConflictUpdate(
              CachedAppointmentsCompanion.insert(
                id: _asString(item['id'])!,
                userId: _asInt(item['userId']) ?? 0,
                ownerUsername: _asString(item['ownerUsername']) ?? '',
                dateTimeStr: _asString(item['dateTimeStr']) ??
                    _asString(item['dateTime']) ??
                    '',
                status: _asString(item['status']) ?? '',
                dataJson: jsonEncode(item),
              ),
            );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAppointments() async {
    final rows = await _db.select(_db.cachedAppointments).get();
    return rows
        .map((r) => jsonDecode(r.dataJson) as Map<String, dynamic>)
        .toList();
  }

  //endregion

  //region Shifts

  Future<void> saveShifts(List<Map<String, dynamic>> items) async {
    await _db.transaction(() async {
      for (final item in items) {
        await _db.into(_db.cachedShifts).insertOnConflictUpdate(
              CachedShiftsCompanion.insert(
                id: Value(_asInt(item['id']) ?? 0),
                userId: _asInt(item['userId']) ?? 0,
                date: _asString(item['date'])!,
                startTime: _asString(item['startTime'])!,
                endTime: _asString(item['endTime'])!,
                status: _asString(item['status'])!,
              ),
            );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getShifts() async {
    final rows = await _db.select(_db.cachedShifts).get();
    return rows.map((r) => r.toJson()).toList();
  }

  //endregion

  //region Pending actions

  Future<void> queueAction({
    required String id,
    required String action,
    required String endpoint,
    required String method,
    required String payload,
  }) async {
    await _db.into(_db.pendingActions).insertOnConflictUpdate(
          PendingActionsCompanion.insert(
            id: id,
            action: action,
            endpoint: endpoint,
            method: method,
            payload: payload,
            createdAtStr: DateTime.now().toIso8601String(),
          ),
        );
  }

  Future<List<PendingAction>> getPendingActions() async {
    return (_db.select(_db.pendingActions)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAtStr)]))
        .get();
  }

  Future<void> removePendingAction(String id) async {
    await (_db.delete(_db.pendingActions)..where((t) => t.id.equals(id))).go();
  }

  Future<void> incrementRetry(String id) async {
    await _db.customStatement(
      'UPDATE pending_actions SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  //endregion

  Future<void> clearAll() async {
    await _db.batch((batch) {
      batch.deleteAll(_db.cachedWashTypes);
      batch.deleteAll(_db.cachedUsers);
      batch.deleteAll(_db.cachedAppointments);
      batch.deleteAll(_db.cachedShifts);
      batch.deleteAll(_db.pendingActions);
    });
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
