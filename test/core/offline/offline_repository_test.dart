import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanwash/core/offline/database.dart';
import 'package:lanwash/core/offline/offline_repository.dart';

void main() {
  group('OfflineRepository', () {
    late AppDatabase db;
    late OfflineRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = OfflineRepository(db);
    });

    tearDown(() async {
      await repository.clearAll();
      await db.close();
    });

    test('save and get wash types', () async {
      final items = [
        {
          'id': 'wt-1',
          'code': 'basic',
          'name': 'Basic Wash',
          'description': 'Standard wash',
          'basePrice': 500,
          'durationMinutes': 30,
          'sortOrder': 1,
        },
        {
          'id': 'wt-2',
          'code': 'premium',
          'name': 'Premium Wash',
          'description': 'Full detail',
          'basePrice': 1200,
          'durationMinutes': 60,
          'sortOrder': 2,
        },
      ];

      await repository.saveWashTypes(items);
      final result = await repository.getWashTypes();

      expect(result.length, 2);
      expect(result, containsAll(items));
    });

    test('queue pending action and retrieve it', () async {
      await repository.queueAction(
        id: 'action-1',
        action: 'create_appointment',
        endpoint: '/appointments',
        method: 'POST',
        payload: '{"slotId":"slot-1"}',
      );

      final actions = await repository.getPendingActions();

      expect(actions.length, 1);
      expect(actions.first.id, 'action-1');
      expect(actions.first.action, 'create_appointment');
      expect(actions.first.endpoint, '/appointments');
      expect(actions.first.method, 'POST');
      expect(actions.first.payload, '{"slotId":"slot-1"}');
      expect(actions.first.retryCount, 0);
      expect(actions.first.createdAtStr, isNotEmpty);
    });

    test('remove pending action', () async {
      await repository.queueAction(
        id: 'action-1',
        action: 'create_appointment',
        endpoint: '/appointments',
        method: 'POST',
        payload: '{}',
      );

      await repository.removePendingAction('action-1');

      final actions = await repository.getPendingActions();
      expect(actions, isEmpty);
    });

    test('pending actions are ordered by createdAt ascending', () async {
      await repository.queueAction(
        id: 'action-2',
        action: 'b',
        endpoint: '/b',
        method: 'POST',
        payload: '{}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repository.queueAction(
        id: 'action-1',
        action: 'a',
        endpoint: '/a',
        method: 'POST',
        payload: '{}',
      );

      final actions = await repository.getPendingActions();

      expect(actions.map((a) => a.id).toList(), ['action-2', 'action-1']);
    });

    test('increment retry increases retryCount', () async {
      await repository.queueAction(
        id: 'action-1',
        action: 'create_appointment',
        endpoint: '/appointments',
        method: 'POST',
        payload: '{}',
      );

      await repository.incrementRetry('action-1');
      await repository.incrementRetry('action-1');

      final actions = await repository.getPendingActions();
      expect(actions.first.retryCount, 2);
    });

    test('clearAll truncates cached tables and pending actions', () async {
      await repository.saveWashTypes([
        {
          'id': 'wt-1',
          'code': 'basic',
          'name': 'Basic Wash',
          'basePrice': 500,
          'durationMinutes': 30,
          'sortOrder': 1,
        },
      ]);
      await repository.queueAction(
        id: 'action-1',
        action: 'a',
        endpoint: '/a',
        method: 'POST',
        payload: '{}',
      );

      await repository.clearAll();

      expect(await repository.getWashTypes(), isEmpty);
      expect(await repository.getPendingActions(), isEmpty);
    });
  });
}
