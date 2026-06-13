import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/offline/connectivity_monitor.dart';
import '../core/offline/offline_repository.dart';
import '../core/offline/sync_service.dart';

/// Exposes connectivity and pending-mutation state to the UI.
class OfflineProvider extends ChangeNotifier {
  final ConnectivityMonitor _monitor;
  final SyncService _syncService;
  final OfflineRepository _repository;

  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingCount = 0;

  OfflineProvider({
    required ConnectivityMonitor monitor,
    required SyncService syncService,
    required OfflineRepository repository,
  })  : _monitor = monitor,
        _syncService = syncService,
        _repository = repository {
    _monitor.onChanged = _onConnectivityChanged;
    _monitor.start();
    refresh();
  }

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  bool get hasPendingActions => _pendingCount > 0;

  void _onConnectivityChanged(bool isOnline) {
    final wasOnline = _isOnline;
    _isOnline = isOnline;
    notifyListeners();
    if (isOnline && !wasOnline) {
      sync();
    }
  }

  /// Refreshes the pending action count from local storage.
  Future<void> refresh() async {
    try {
      _pendingCount = await _repository.getPendingCount();
    } catch (e, st) {
      if (kDebugMode) debugPrint('OfflineProvider refresh error: $e\n$st');
      _pendingCount = 0;
    }
    notifyListeners();
  }

  /// Drains the pending-action queue and refreshes the count.
  /// Returns the number of actions that still failed.
  Future<int> sync() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    notifyListeners();

    int failed;
    try {
      failed = (await _syncService.sync()).length;
    } catch (e, st) {
      if (kDebugMode) debugPrint('OfflineProvider sync error: $e\n$st');
      failed = 0;
    } finally {
      _isSyncing = false;
    }

    await refresh();
    return failed;
  }

  @override
  void dispose() {
    // The monitor is an app-wide singleton; we only stop listening to avoid
    // notifying a disposed ChangeNotifier. Stopping the monitor itself would
    // break background sync for the whole app.
    _monitor.onChanged = (_) {};
    super.dispose();
  }
}
