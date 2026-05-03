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
    if (_isInitialized) return;

    try {
      await Firebase.initializeApp();

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        _fcm = FirebaseMessaging.instance;
        
        // Регистрируем токен сразу при получении
        _fcm!.onTokenRefresh.listen((newToken) {
        });

        NotificationSettings settings = await _fcm!.requestPermission();

        String? token = await _fcm!.getToken();
        
        FirebaseMessaging.onMessage.listen(_showLocalNotification);
      } else {
      }

      _isInitialized = true;
    } catch (e, stack) {
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
      return null;
    }

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

  Future<void> updateTokenOnServer(String username) async {
    String? token = await getToken();
    if (token != null) {
      await _apiService.saveFcmToken(username, token);
    } else {
    }
  }
}
