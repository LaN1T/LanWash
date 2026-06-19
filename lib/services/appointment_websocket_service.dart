import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import 'notification_service.dart';

class AppointmentWebSocketService {
  static final AppointmentWebSocketService _instance =
      AppointmentWebSocketService._internal();
  factory AppointmentWebSocketService() => _instance;
  AppointmentWebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _shouldReconnect = false;

  AuthProvider? _auth;
  AppointmentProvider? _provider;

  final _authFailureController = StreamController<void>.broadcast();
  Stream<void> get onAuthFailure => _authFailureController.stream;

  void connect(AuthProvider auth, AppointmentProvider provider) {
    disconnect();
    _auth = auth;
    _provider = provider;
    _shouldReconnect = true;
    _reconnectAttempt = 0;
    _connect();
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      _subscription?.cancel();
    } catch (_) {}
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _auth = null;
    _provider = null;
  }

  Future<void> _connect() async {
    final auth = _auth;
    final provider = _provider;
    if (auth == null || provider == null) return;

    final token = await ApiClient.getToken();
    if (token == null || token.isEmpty) {
      _scheduleReconnect();
      return;
    }

    final base = AppConfig.baseUrl;
    final host = base.endsWith('/api')
        ? base.substring(0, base.length - 4)
        : base;
    final wsUrl = '${host.replaceFirst('http', 'ws')}/ws/appointments';

    if (kDebugMode) debugPrint('[AppointmentWS] connecting to $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
      _reconnectAttempt = 0;

      _subscription = _channel!.stream.listen(
        (event) => _handleEvent(event as String, provider, auth),
        onError: (_) => _scheduleReconnect(),
        onDone: () {
          if (_shouldReconnect) _scheduleReconnect();
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AppointmentWS] connect error: $e');
      _scheduleReconnect();
    }
  }

  void _handleEvent(
    String event,
    AppointmentProvider provider,
    AuthProvider auth,
  ) {
    try {
      final data = jsonDecode(event) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'appointment_updated') {
        final map = data['appointment'] as Map<String, dynamic>;
        final eventName = data['event']?.toString() ?? 'updated';
        final id = map['id']?.toString() ?? '';
        provider.applyWebSocketAppointment(map, eventName, auth);
        NotificationService().emitAppointmentUpdated(id);
      } else if (type == 'auth_failed') {
        _authFailureController.add(null);
        disconnect();
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('[AppointmentWS] event error: $e\n$st');
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    final delaySeconds =
        [1, 2, 4, 8, 16, 30][(_reconnectAttempt < 5) ? _reconnectAttempt : 5];
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_shouldReconnect) _connect();
    });
  }
}
