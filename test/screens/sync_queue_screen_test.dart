import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lanwash/core/offline/connectivity_monitor.dart';
import 'package:lanwash/core/offline/database.dart';
import 'package:lanwash/core/offline/offline_repository.dart';
import 'package:lanwash/core/offline/sync_service.dart';
import 'package:lanwash/providers/offline_provider.dart';
import 'package:lanwash/screens/shared/sync_queue_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockSyncService extends Mock implements SyncService {}

class FakeConnectivityMonitor implements ConnectivityMonitor {
  bool _online = true;

  @override
  ConnectivityChangedCallback onChanged = (_) {};

  void setOnline(bool value) {
    _online = value;
    onChanged(value);
  }

  @override
  void start() => onChanged(_online);

  @override
  void stop() {}

  @override
  Future<bool> checkNow() async => _online;
}

void main() {
  late AppDatabase db;
  late OfflineRepository repo;
  late FakeConnectivityMonitor monitor;
  late MockSyncService sync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = OfflineRepository(db);
    monitor = FakeConnectivityMonitor();
    sync = MockSyncService();

    final sl = GetIt.instance;
    if (sl.isRegistered<OfflineRepository>()) {
      sl.unregister<OfflineRepository>();
    }
    sl.registerSingleton<OfflineRepository>(repo);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester, OfflineProvider provider) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<OfflineProvider>.value(
          value: provider,
          child: const SyncQueueScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state when no pending actions', (tester) async {
    final provider = OfflineProvider(
      monitor: monitor,
      syncService: sync,
      repository: repo,
    );
    addTearDown(provider.dispose);

    await pumpScreen(tester, provider);

    expect(find.text('Очередь пуста'), findsOneWidget);
    expect(find.text('Всё синхронизировано'), findsOneWidget);
  });

  testWidgets('shows pending actions list', (tester) async {
    await repo.queueAction(
      id: 'a1',
      action: 'create_appointment',
      endpoint: '/appointments',
      method: 'POST',
      payload: '{}',
    );
    final provider = OfflineProvider(
      monitor: monitor,
      syncService: sync,
      repository: repo,
    );
    addTearDown(provider.dispose);

    await pumpScreen(tester, provider);

    expect(find.text('Ожидают отправки (1)'), findsOneWidget);
    expect(find.text('/appointments'), findsOneWidget);
    expect(find.text('POST'), findsOneWidget);
  });

  testWidgets('shows offline status', (tester) async {
    monitor.setOnline(false);
    final provider = OfflineProvider(
      monitor: monitor,
      syncService: sync,
      repository: repo,
    );
    addTearDown(provider.dispose);

    await pumpScreen(tester, provider);

    expect(find.text('Нет подключения к сети'), findsOneWidget);
  });
}
