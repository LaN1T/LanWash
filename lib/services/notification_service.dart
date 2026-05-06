import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
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

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Firebase.initializeApp();

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

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        _fcm = FirebaseMessaging.instance;
        
        // Регистрируем токен сразу при получении
        _fcm!.onTokenRefresh.listen((newToken) {
        });

        NotificationSettings settings = await _fcm!.requestPermission();

        String? token = await _fcm!.getToken();
        
        FirebaseMessaging.onMessage.listen((message) {
          _handleMessage(message);
          _showLocalNotification(message);
        });

        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
      } else {
      }

      _isInitialized = true;
    } catch (e, stack) {
    }
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data['type'] == 'appointment_updated') {
      _updateController.add(message.data['id']);
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
        priority: Priority.high
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
    );
  }

  Future<String?> getToken() async {
    if (!_isInitialized || _fcm == null) {
      debugPrint('[DEBUG] NotificationService: Not initialized or _fcm is null.');
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
