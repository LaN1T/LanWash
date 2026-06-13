import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:lanwash/core/api_client_adapter.dart';
import 'package:lanwash/core/api_result.dart';
import 'package:lanwash/core/offline/database.dart';
import 'package:lanwash/core/offline/offline_repository.dart';
import 'package:lanwash/core/offline/sync_service.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClientAdapter {}

void main() {
  group('SyncService', () {
    late AppDatabase db;
    late OfflineRepository repo;
    late MockApiClient api;
    late SyncService sync;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = OfflineRepository(db);
      api = MockApiClient();
      sync = SyncService(repo, api);
    });

    tearDown(() async {
      await db.close();
    });

    test('removes successful actions', () async {
      await repo.queueAction(
        id: 'a1',
        action: 'delete_shift',
        endpoint: '/shifts/1',
        method: 'DELETE',
        payload: '{}',
      );
      when(() => api.delete('/shifts/1'))
          .thenAnswer((_) async => const Success(<String, dynamic>{}));

      final failed = await sync.sync();

      expect(failed, isEmpty);
      expect(await repo.getPendingActions(), isEmpty);
    });

    test('drains pending actions in order', () async {
      await repo.queueAction(
        id: 'a1',
        action: 'delete_shift',
        endpoint: '/shifts/1',
        method: 'DELETE',
        payload: '{}',
      );
      await repo.queueAction(
        id: 'a2',
        action: 'create_appointment',
        endpoint: '/appointments',
        method: 'POST',
        payload: '{"userId": 1}',
      );
      await repo.queueAction(
        id: 'a3',
        action: 'update_shift',
        endpoint: '/shifts/1',
        method: 'PUT',
        payload: '{"status":"started"}',
      );

      when(() => api.delete('/shifts/1'))
          .thenAnswer((_) async => const Success(<String, dynamic>{}));
      when(() => api.post('/appointments', body: {'userId': 1}))
          .thenAnswer((_) async => const Success(<String, dynamic>{}));
      when(() => api.put('/shifts/1', body: {'status': 'started'}))
          .thenAnswer((_) async => const Success(<String, dynamic>{}));

      final failed = await sync.sync();

      expect(failed, isEmpty);
      expect(await repo.getPendingActions(), isEmpty);
      verifyInOrder([
        () => api.delete('/shifts/1'),
        () => api.post('/appointments', body: {'userId': 1}),
        () => api.put('/shifts/1', body: {'status': 'started'}),
      ]);
    });

    test('failed actions stay in queue with incremented retry', () async {
      await repo.queueAction(
        id: 'a1',
        action: 'delete_shift',
        endpoint: '/shifts/1',
        method: 'DELETE',
        payload: '{}',
      );
      when(() => api.delete('/shifts/1'))
          .thenAnswer((_) async => Failure(AppError.network()));

      final failed = await sync.sync();

      expect(failed, ['a1']);
      final pending = await repo.getPendingActions();
      expect(pending.length, 1);
      expect(pending.first.retryCount, 1);
    });

    test('keeps action in queue when api throws an exception', () async {
      await repo.queueAction(
        id: 'a1',
        action: 'delete_shift',
        endpoint: '/shifts/1',
        method: 'DELETE',
        payload: '{}',
      );
      when(() => api.delete('/shifts/1')).thenThrow(Exception('boom'));

      final failed = await sync.sync();

      expect(failed, ['a1']);
      final pending = await repo.getPendingActions();
      expect(pending.length, 1);
      expect(pending.first.retryCount, 1);
    });

    test('mixed success and failure leaves only failed action', () async {
      await repo.queueAction(
        id: 'a1',
        action: 'delete_shift',
        endpoint: '/shifts/1',
        method: 'DELETE',
        payload: '{}',
      );
      await repo.queueAction(
        id: 'a2',
        action: 'update_shift',
        endpoint: '/shifts/2',
        method: 'PUT',
        payload: '{"status":"started"}',
      );

      when(() => api.delete('/shifts/1'))
          .thenAnswer((_) async => const Success(<String, dynamic>{}));
      when(() => api.put('/shifts/2', body: {'status': 'started'}))
          .thenAnswer((_) async => Failure(AppError.server(500)));

      final failed = await sync.sync();

      expect(failed, ['a2']);
      final pending = await repo.getPendingActions();
      expect(pending.length, 1);
      expect(pending.first.id, 'a2');
      expect(pending.first.retryCount, 1);
    });
  });
}
