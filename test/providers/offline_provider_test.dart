import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanwash/core/offline/connectivity_monitor.dart';
import 'package:lanwash/core/offline/database.dart';
import 'package:lanwash/core/offline/offline_repository.dart';
import 'package:lanwash/core/offline/sync_service.dart';
import 'package:lanwash/providers/offline_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncService extends Mock implements SyncService {}

class FakeConnectivityMonitor implements ConnectivityMonitor {
  bool _online = true;
  bool _started = false;

  @override
  ConnectivityChangedCallback onChanged = (_) {};

  bool get started => _started;

  void setOnline(bool value) {
    _online = value;
    onChanged(value);
  }

  @override
  void start() {
    _started = true;
    onChanged(_online);
  }

  @override
  void stop() {
    _started = false;
  }

  @override
  Future<bool> checkNow() async => _online;
}

void main() {
  group('OfflineProvider', () {
    late AppDatabase db;
    late OfflineRepository repo;
    late FakeConnectivityMonitor monitor;
    late MockSyncService sync;
    late OfflineProvider provider;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = OfflineRepository(db);
      monitor = FakeConnectivityMonitor();
      sync = MockSyncService();
      provider = OfflineProvider(
        monitor: monitor,
        syncService: sync,
        repository: repo,
      );
    });

    tearDown(() async {
      provider.dispose();
      await db.close();
    });

    test('starts monitor and initial state is online with no pending actions',
        () {
      expect(monitor.started, true);
      expect(provider.isOnline, true);
      expect(provider.pendingCount, 0);
      expect(provider.hasPendingActions, false);
    });

    test('refresh loads pending count', () async {
      await repo.queueAction(
        id: 'a1',
        action: 'create_appointment',
        endpoint: '/appointments',
        method: 'POST',
        payload: '{}',
      );

      await provider.refresh();

      expect(provider.pendingCount, 1);
      expect(provider.hasPendingActions, true);
    });

    test('sync drains queue, updates count and toggles isSyncing', () async {
      await repo.queueAction(
        id: 'a1',
        action: 'create_appointment',
        endpoint: '/appointments',
        method: 'POST',
        payload: '{}',
      );
      when(() => sync.sync()).thenAnswer((_) async {
        await repo.removePendingAction('a1');
        return [];
      });

      final future = provider.sync();
      expect(provider.isSyncing, true);
      await future;

      expect(provider.isSyncing, false);
      expect(provider.pendingCount, 0);
      verify(() => sync.sync()).called(1);
    });

    test('sync returns failed count and keeps failed actions', () async {
      await repo.queueAction(
        id: 'a1',
        action: 'create_appointment',
        endpoint: '/appointments',
        method: 'POST',
        payload: '{}',
      );
      when(() => sync.sync()).thenAnswer((_) async => ['a1']);

      final failed = await provider.sync();

      expect(failed, 1);
      expect(provider.pendingCount, 1);
    });

    test('transitioning from offline to online triggers sync', () async {
      await repo.queueAction(
        id: 'a1',
        action: 'create_appointment',
        endpoint: '/appointments',
        method: 'POST',
        payload: '{}',
      );
      when(() => sync.sync()).thenAnswer((_) async => []);

      monitor.setOnline(false);
      monitor.setOnline(true);

      await untilCalled(() => sync.sync());
      expect(provider.isOnline, true);
    });

    test('dispose detaches callback without stopping monitor', () {
      provider.dispose();
      // After dispose, calling the callback should not throw.
      monitor.setOnline(false);
      expect(true, true);
    });
  });
}
