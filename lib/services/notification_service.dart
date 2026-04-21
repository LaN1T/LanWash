import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {},
      );

      await _fcm.requestPermission();
      FirebaseMessaging.onMessage.listen(_showLocalNotification);

      _isInitialized = true;
    } catch (e) {
      print("NotificationService error: $e");
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
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }

  Future<String?> getToken() async => await _fcm.getToken();

  Future<void> updateTokenOnServer(String username) async {
    String? token = await getToken();
    if (token != null) await _apiService.saveFcmToken(username, token);
  }
}
