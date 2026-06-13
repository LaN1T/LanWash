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

    test('save and get users', () async {
      final items = [
        {
          'id': 1,
          'username': 'alice',
          'displayName': 'Alice',
          'role': 'admin',
          'avatarUrl': 'https://example.com/a.png',
        },
        {
          'id': 2,
          'username': 'bob',
          'displayName': 'Bob',
          'role': 'washer',
          'avatarUrl': null,
        },
      ];

      await repository.saveUsers(items);
      final result = await repository.getUsers();

      expect(result.length, 2);
      expect(result, containsAll(items));
    });

    test('save and get appointments', () async {
      final items = [
        {
          'id': 'appt-1',
          'userId': 1,
          'ownerUsername': 'alice',
          'dateTimeStr': '2026-06-13T10:00:00.000Z',
          'status': 'confirmed',
          'extraField': 'preserved',
        },
      ];

      await repository.saveAppointments(items);
      final result = await repository.getAppointments();

      expect(result.length, 1);
      expect(result.first, items.first);
    });

    test('save and get shifts', () async {
      final items = [
        {
          'id': 1,
          'userId': 1,
          'date': '2026-06-13',
          'startTime': '08:00',
          'endTime': '16:00',
          'status': 'active',
        },
        {
          'id': 2,
          'userId': 2,
          'date': '2026-06-14',
          'startTime': '09:00',
          'endTime': '17:00',
          'status': 'draft',
        },
      ];

      await repository.saveShifts(items);
      final result = await repository.getShifts();

      expect(result.length, 2);
      expect(result, containsAll(items));
    });

    test('saveWashTypes throws when id is missing', () async {
      expect(
        () => repository.saveWashTypes([
          {'code': 'basic', 'name': 'Basic Wash'},
        ]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('saveShifts throws when id is missing', () async {
      expect(
        () => repository.saveShifts([
          {
            'userId': 1,
            'date': '2026-06-13',
            'startTime': '08:00',
            'endTime': '16:00',
            'status': 'active',
          },
        ]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('saveAppointments throws when userId is missing', () async {
      expect(
        () => repository.saveAppointments([
          {
            'id': 'appt-1',
            'ownerUsername': 'alice',
            'dateTimeStr': '2026-06-13T10:00:00.000Z',
            'status': 'confirmed',
          },
        ]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('upsert updates existing row', () async {
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
      await repository.saveWashTypes([
        {
          'id': 'wt-1',
          'code': 'basic',
          'name': 'Updated Basic Wash',
          'basePrice': 600,
          'durationMinutes': 45,
          'sortOrder': 2,
        },
      ]);

      final result = await repository.getWashTypes();

      expect(result.length, 1);
      expect(result.first['name'], 'Updated Basic Wash');
      expect(result.first['basePrice'], 600);
      expect(result.first['durationMinutes'], 45);
      expect(result.first['sortOrder'], 2);
    });

    test('upsert updates existing user', () async {
      await repository.saveUsers([
        {
          'id': 1,
          'username': 'alice',
          'displayName': 'Alice',
          'role': 'admin',
        },
      ]);
      await repository.saveUsers([
        {
          'id': 1,
          'username': 'alice',
          'displayName': 'Alice Smith',
          'role': 'manager',
        },
      ]);

      final result = await repository.getUsers();

      expect(result.length, 1);
      expect(result.first['displayName'], 'Alice Smith');
      expect(result.first['role'], 'manager');
    });

    test('upsert updates existing appointment', () async {
      await repository.saveAppointments([
        {
          'id': 'appt-1',
          'userId': 1,
          'ownerUsername': 'alice',
          'dateTimeStr': '2026-06-13T10:00:00.000Z',
          'status': 'confirmed',
        },
      ]);
      await repository.saveAppointments([
        {
          'id': 'appt-1',
          'userId': 2,
          'ownerUsername': 'bob',
          'dateTimeStr': '2026-06-14T11:00:00.000Z',
          'status': 'completed',
        },
      ]);

      final result = await repository.getAppointments();

      expect(result.length, 1);
      expect(result.first['userId'], 2);
      expect(result.first['ownerUsername'], 'bob');
      expect(result.first['status'], 'completed');
    });

    test('upsert updates existing shift', () async {
      await repository.saveShifts([
        {
          'id': 1,
          'userId': 1,
          'date': '2026-06-13',
          'startTime': '08:00',
          'endTime': '16:00',
          'status': 'active',
        },
      ]);
      await repository.saveShifts([
        {
          'id': 1,
          'userId': 1,
          'date': '2026-06-13',
          'startTime': '09:00',
          'endTime': '17:00',
          'status': 'completed',
        },
      ]);

      final result = await repository.getShifts();

      expect(result.length, 1);
      expect(result.first['startTime'], '09:00');
      expect(result.first['endTime'], '17:00');
      expect(result.first['status'], 'completed');
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

    test('increment retry on missing action completes without throwing', () async {
      await expectLater(
        repository.incrementRetry('missing-action'),
        completes,
      );
      expect(await repository.getPendingActions(), isEmpty);
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
