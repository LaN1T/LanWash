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

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();

  bool _isInitialized = false;

  Future<void> init() async {
    debugPrint('[NotificationService] +++ init() method called');
    if (_isInitialized) return;

    try {
      debugPrint('[NotificationService] Firebase.initializeApp() start');
      await Firebase.initializeApp();
      debugPrint('[NotificationService] Firebase.initializeApp() success');

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        debugPrint('[NotificationService] Platform is mobile, initializing FCM...');
        _fcm = FirebaseMessaging.instance;
        
        // Регистрируем токен сразу при получении
        _fcm!.onTokenRefresh.listen((newToken) {
          debugPrint('[NotificationService] NEW TOKEN: $newToken');
        });

        debugPrint('[NotificationService] Requesting permission...');
        NotificationSettings settings = await _fcm!.requestPermission();
        debugPrint('[NotificationService] Permission status: ${settings.authorizationStatus}');

        debugPrint('[NotificationService] Attempting to get token...');
        String? token = await _fcm!.getToken();
        debugPrint('[!!!] СКОПИРУЙ ЭТОТ ТОКЕН: $token');
        
        FirebaseMessaging.onMessage.listen(_showLocalNotification);
      } else {
        debugPrint('[NotificationService] Skipping FCM (not a mobile platform)');
      }

      _isInitialized = true;
      debugPrint('[NotificationService] init() completed successfully');
    } catch (e, stack) {
      debugPrint("[NotificationService] CRITICAL ERROR: $e");
      debugPrint("[NotificationService] STACK TRACE: $stack");
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
      debugPrint('[NotificationService] Not initialized or FCM null');
      return null;
    }

    try {
      String? token = await _fcm!.getToken();
      if (token == null) {
        debugPrint('[NotificationService] Token is null, waiting for APNS...');
        await Future.delayed(const Duration(seconds: 2));
        token = await _fcm!.getToken();
      }
      
      debugPrint('[NotificationService] Token retrieved: $token');
      return token;
    } catch (e) {
      debugPrint('[NotificationService] Error getting token: $e');
      return null;
    }
  }

  Future<void> updateTokenOnServer(String username) async {
    String? token = await getToken();
    debugPrint('[NotificationService] Updating token for $username: $token');
    if (token != null) {
      await _apiService.saveFcmToken(username, token);
      debugPrint('[NotificationService] Token save request sent to API');
    } else {
      debugPrint('[NotificationService] Token is null, cannot save to server');
    }
  }
}
