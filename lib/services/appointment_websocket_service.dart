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
    _cleanupConnection();
    _auth = null;
    _provider = null;
  }

  void dispose() {
    disconnect();
    if (!_authFailureController.isClosed) {
      _authFailureController.close();
    }
  }

  void _cleanupConnection() {
    try {
      _subscription?.cancel();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppointmentWS] subscription cancel error: $e');
      }
    }
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppointmentWS] sink close error: $e');
      }
    }
    _channel = null;
  }

  Future<void> _connect() async {
    final auth = _auth;
    final provider = _provider;
    if (auth == null || provider == null) return;

    _cleanupConnection();

    final token = await ApiClient.getToken();
    if (!_shouldReconnect) return;
    if (token == null || token.isEmpty) {
      _scheduleReconnect();
      return;
    }

    final base = AppConfig.baseUrl;
    final host =
        base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
    final wsUrl = '${host.replaceFirst('http', 'ws')}/ws/appointments';

    if (kDebugMode) debugPrint('[AppointmentWS] connecting to $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
      _reconnectAttempt = 0;

      _subscription = _channel!.stream.listen(
        (dynamic event) => _handleEvent(event, provider, auth),
        onError: (dynamic e) {
          if (kDebugMode) debugPrint('[AppointmentWS] stream error: $e');
          _cleanupConnection();
          _scheduleReconnect();
        },
        onDone: () {
          _cleanupConnection();
          if (_shouldReconnect) _scheduleReconnect();
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AppointmentWS] connect error: $e');
      _cleanupConnection();
      _scheduleReconnect();
    }
  }

  void _handleEvent(
    dynamic event,
    AppointmentProvider provider,
    AuthProvider auth,
  ) {
    if (event is! String) return;
    try {
      final data = jsonDecode(event) as Map<String, dynamic>?;
      if (data == null) return;
      final type = data['type'] as String?;

      if (type == 'appointment_updated') {
        final appointment = data['appointment'];
        if (appointment is! Map<String, dynamic>) return;
        final eventName = data['event']?.toString() ?? 'updated';
        final id = appointment['id']?.toString() ?? '';
        provider.applyWebSocketAppointment(appointment, eventName, auth);
        NotificationService().emitAppointmentUpdated(id);
      } else if (type == 'auth_failed') {
        if (!_authFailureController.isClosed) {
          _authFailureController.add(null);
        }
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
