import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api_client_adapter.dart';
import 'offline_repository.dart';

class SyncService {
  final OfflineRepository _repository;
  final ApiClientAdapter _apiClient;

  bool _isSyncing = false;

  SyncService(this._repository, this._apiClient);

  /// Synchronize pending actions. Returns list of IDs that failed.
  Future<List<String>> sync() async {
    if (_isSyncing) return [];
    _isSyncing = true;

    final failed = <String>[];
    try {
      final actions = await _repository.getPendingActions();
      for (final action in actions) {
        try {
          final success = await _execute(
            action.method,
            action.endpoint,
            action.payload,
          );
          if (success) {
            await _repository.removePendingAction(action.id);
          } else {
            await _repository.incrementRetry(action.id);
            failed.add(action.id);
          }
        } catch (e, st) {
          debugPrint('Sync failed for action ${action.id}: $e\n$st');
          await _repository.incrementRetry(action.id);
          failed.add(action.id);
        }
      }
    } finally {
      _isSyncing = false;
    }

    return failed;
  }

  Future<bool> _execute(String method, String endpoint, String payload) async {
    final body = payload.isEmpty
        ? null
        : jsonDecode(payload) as Map<String, dynamic>?;
    switch (method.toUpperCase()) {
      case 'POST':
        final result = await _apiClient.post(endpoint, body: body);
        return result.isSuccess;
      case 'PUT':
        final result = await _apiClient.put(endpoint, body: body);
        return result.isSuccess;
      case 'DELETE':
        final result = await _apiClient.delete(endpoint);
        return result.isSuccess;
      default:
        return false;
    }
  }
}
