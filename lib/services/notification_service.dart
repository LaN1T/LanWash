import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../firebase_options.dart'; // Add this line

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _updateController = StreamController<String>.broadcast();
  Stream<String> get onAppointmentUpdated => _updateController.stream;

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();

  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  Future<void> init() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    try {
      debugPrint('[DEBUG] NotificationService: Starting initialization...');
      // Firebase уже инициализирован в main.dart

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      
      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
        },
      );

      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        _fcm = FirebaseMessaging.instance;
        
        // Зарегистрировать обработчик фоновых сообщений
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Регистрируем токен сразу при получении
        _fcm!.onTokenRefresh.listen((newToken) {
          debugPrint('[DEBUG] NotificationService: Token refreshed: $newToken');
        });

        NotificationSettings settings = await _fcm!.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('[DEBUG] NotificationService: User granted permission: ${settings.authorizationStatus}');

        FirebaseMessaging.onMessage.listen((message) {
          debugPrint('[DEBUG] NotificationService: Received foreground message: ${message.notification?.title}');
          _handleMessage(message);
          _showLocalNotification(message);
        });

        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          debugPrint('[DEBUG] NotificationService: App opened from notification: ${message.notification?.title}');
          _handleMessage(message);
        });
      }

      _isInitialized = true;
      _initCompleter!.complete();
      debugPrint('[DEBUG] NotificationService: Initialization complete.');
    } catch (e, stack) {
      debugPrint('[DEBUG] NotificationService: Initialization error: $e');
      _initCompleter!.completeError(e, stack);
      _initCompleter = null; // Позволяем повторную попытку при ошибке
    }
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data['type'] == 'appointment_updated') {
      _updateController.add(message.data['id']);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    debugPrint('[DEBUG] NotificationService: _showLocalNotification called. Notification: ${notification?.title}');
    if (notification == null) {
      debugPrint('[DEBUG] NotificationService: No notification payload.');
      return;
    }

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
      debugPrint('[DEBUG] NotificationService: Local notification displayed.');
    } catch (e) {
      debugPrint('[DEBUG] NotificationService: Error showing local notification: $e');
    }
  }

  Future<String?> getToken() async {
    if (!_isInitialized) {
      debugPrint('[DEBUG] NotificationService: Not initialized, waiting...');
      if (_initCompleter != null) {
        await _initCompleter!.future.catchError((_) {});
      } else {
        await init().catchError((_) {});
      }
    }

    if (_fcm == null) {
      debugPrint('[DEBUG] NotificationService: _fcm is still null after init.');
      return null;
    }

    try {
      String? token = await _fcm!.getToken();
      debugPrint('[DEBUG] NotificationService: Got token from FCM: $token');
      if (token == null) {
        await Future.delayed(const Duration(seconds: 2));
        token = await _fcm!.getToken();
        debugPrint('[DEBUG] NotificationService: Got token after delay: $token');
      }
      
      return token;
    } catch (e) {
      debugPrint('[DEBUG] NotificationService: Error getting token: $e');
      return null;
    }
  }

  Future<void> updateTokenOnServer(String username) async {
    debugPrint('[DEBUG] NotificationService: Updating token on server for $username');
    String? token = await getToken();
    if (token != null) {
      debugPrint('[DEBUG] NotificationService: Calling apiService.saveFcmToken with token: $token');
      final result = await _apiService.saveFcmToken(username, token);
      debugPrint('[DEBUG] NotificationService: SaveFcmToken result: $result');
    } else {
      debugPrint('[DEBUG] NotificationService: Failed to get token, not updating server.');
    }
  }
}
