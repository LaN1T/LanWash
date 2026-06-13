import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// Repository that abstracts reads and writes to the local offline cache
/// and the pending-actions queue.
class OfflineRepository {
  final AppDatabase _db;

  OfflineRepository(this._db);

  //region Wash types

  Future<void> saveWashTypes(List<Map<String, dynamic>> items) async {
    await _db.batch((b) {
      b.insertAllOnConflictUpdate(
        _db.cachedWashTypes,
        items.map((item) {
          return CachedWashTypesCompanion.insert(
            id: _requireString(item, 'id'),
            code: _requireString(item, 'code'),
            name: _requireString(item, 'name'),
            description: Value(_asString(item['description']) ?? ''),
            basePrice: Value(_asInt(item['basePrice']) ?? 0),
            durationMinutes: Value(_asInt(item['durationMinutes']) ?? 30),
            sortOrder: Value(_asInt(item['sortOrder']) ?? 0),
          );
        }).toList(),
      );
    });
  }

  Future<List<Map<String, dynamic>>> getWashTypes() async {
    final rows = await _db.select(_db.cachedWashTypes).get();
    return rows.map((r) => r.toJson()).toList();
  }

  //endregion

  //region Users

  Future<void> saveUsers(List<Map<String, dynamic>> items) async {
    await _db.batch((b) {
      b.insertAllOnConflictUpdate(
        _db.cachedUsers,
        items.map((item) {
          return CachedUsersCompanion.insert(
            id: Value(_requireInt(item, 'id')),
            username: _requireString(item, 'username'),
            displayName: _requireString(item, 'displayName'),
            role: _requireString(item, 'role'),
            avatarUrl: Value(_asString(item['avatarUrl'])),
          );
        }).toList(),
      );
    });
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final rows = await _db.select(_db.cachedUsers).get();
    return rows.map((r) => r.toJson()).toList();
  }

  //endregion

  //region Appointments

  Future<void> saveAppointments(List<Map<String, dynamic>> items) async {
    await _db.batch((b) {
      b.insertAllOnConflictUpdate(
        _db.cachedAppointments,
        items.map((item) {
          return CachedAppointmentsCompanion.insert(
            id: _requireString(item, 'id'),
            userId: _requireInt(item, 'userId'),
            ownerUsername: _requireString(item, 'ownerUsername'),
            dateTimeStr: _requireDateTimeStr(item),
            status: _requireString(item, 'status'),
            dataJson: jsonEncode(item),
          );
        }).toList(),
      );
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
    await _db.batch((b) {
      b.insertAllOnConflictUpdate(
        _db.cachedShifts,
        items.map((item) {
          return CachedShiftsCompanion.insert(
            id: Value(_requireInt(item, 'id')),
            userId: _requireInt(item, 'userId'),
            date: _requireString(item, 'date'),
            startTime: _requireString(item, 'startTime'),
            endTime: _requireString(item, 'endTime'),
            status: _requireString(item, 'status'),
          );
        }).toList(),
      );
    });
  }

  Future<List<Map<String, dynamic>>> getShifts() async {
    final rows = await _db.select(_db.cachedShifts).get();
    return rows.map((r) => r.toJson()).toList();
  }

  //endregion

  //region Pending actions

  /// Queues an action for later synchronization. The [id] must be unique;
  /// calling this again with the same [id] will overwrite the existing action.
  /// Actions are returned by [getPendingActions] in FIFO order by creation time.
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
    final action =
        await (_db.select(_db.pendingActions)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    if (action == null) return;
    await _db.update(_db.pendingActions).replace(
          action.copyWith(retryCount: action.retryCount + 1),
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

  int _requireInt(Map<String, dynamic> item, String key) {
    final value = _asInt(item[key]);
    if (value == null) {
      throw ArgumentError('Missing required int field "$key" in $item');
    }
    return value;
  }

  String _requireString(Map<String, dynamic> item, String key) {
    final value = _asString(item[key]);
    if (value == null || value.isEmpty) {
      throw ArgumentError('Missing required string field "$key" in $item');
    }
    return value;
  }

  String _requireDateTimeStr(Map<String, dynamic> item) {
    final value = _asString(item['dateTimeStr']) ?? _asString(item['dateTime']);
    if (value == null || value.isEmpty) {
      throw ArgumentError(
          'Missing required string field "dateTimeStr" in $item');
    }
    return value;
  }
}
