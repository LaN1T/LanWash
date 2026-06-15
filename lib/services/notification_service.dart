import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../firebase_options.dart';
import 'package:lanwash/core/service_locator.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _updateController = StreamController<String>.broadcast();
  Stream<String> get onAppointmentUpdated => _updateController.stream;

  final _supportChatController = StreamController<int>.broadcast();
  Stream<int> get onSupportChatMessage => _supportChatController.stream;

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiService _apiService = sl<ApiService>();

  bool _isInitialized = false;
  Completer<void>? _initCompleter;
  String? _lastKnownUsername;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;

  Future<void> init() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Обработка нажатия на уведомление
        },
      );

      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        _fcm = FirebaseMessaging.instance;

        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);

        _tokenRefreshSub = _fcm!.onTokenRefresh.listen((newToken) async {
          if (_lastKnownUsername != null && newToken.isNotEmpty) {
            try {
              await _apiService.saveFcmToken(_lastKnownUsername!, newToken);
            } catch (e) {
              if (kDebugMode) debugPrint('saveFcmToken error: $e');
            }
          }
        });

        await _fcm!.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
          _handleMessage(message);
          _showLocalNotification(message);
        });

        _onMessageOpenedAppSub =
            FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _handleMessage(message);
        });
      }

      _isInitialized = true;
      _initCompleter!.complete();
    } catch (e, stack) {
      _initCompleter!.completeError(e, stack);
      _initCompleter = null;
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _onMessageSub?.cancel();
    _onMessageSub = null;
    _onMessageOpenedAppSub?.cancel();
    _onMessageOpenedAppSub = null;
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data['type'] == 'appointment_updated') {
      _updateController.add(message.data['id']);
    }
    if (message.data['type'] == 'support_chat') {
      final chatId = int.tryParse(message.data['chat_id']?.toString() ?? '');
      if (chatId != null) {
        _supportChatController.add(chatId);
      }
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'lanwash_channel',
        'LanWash',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: details,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('showLocalNotification error: $e');
    }
  }

  Future<String?> getToken() async {
    if (!_isInitialized) {
      if (_initCompleter != null) {
        await _initCompleter!.future.catchError((_) {});
      } else {
        await init().catchError((_) {});
      }
    }

    if (_fcm == null) return null;

    try {
      String? token = await _fcm!.getToken();
      if (token == null) {
        await Future.delayed(const Duration(seconds: 2));
        token = await _fcm!.getToken();
      }
      return token;
    } catch (e) {
      return null;
    }
  }

  void setUsername(String? username) {
    _lastKnownUsername = username;
  }

  Future<void> updateTokenOnServer(String username) async {
    _lastKnownUsername = username;
    final token = await getToken();
    if (token != null) {
      await _apiService.saveFcmToken(username, token);
    }
  }
}