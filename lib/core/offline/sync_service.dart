import 'dart:convert';

import '../api_client_adapter.dart';
import 'offline_repository.dart';

class SyncService {
  final OfflineRepository _repository;
  final ApiClientAdapter _apiClient;

  SyncService(this._repository, this._apiClient);

  /// Synchronize pending actions. Returns list of IDs that failed.
  Future<List<String>> sync() async {
    final failed = <String>[];
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
      } catch (e) {
        await _repository.incrementRetry(action.id);
        failed.add(action.id);
      }
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
