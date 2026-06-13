import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

typedef ConnectivityChangedCallback = void Function(bool isOnline);

class ConnectivityMonitor {
  final Connectivity _connectivity;
  final ConnectivityChangedCallback onChanged;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityMonitor({
    required this.onChanged,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  void start() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet,
      );
      onChanged(isOnline);
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<bool> checkNow() async {
    final result = await _connectivity.checkConnectivity();
    return result.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );
  }
}
