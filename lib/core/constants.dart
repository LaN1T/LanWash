import 'package:flutter/foundation.dart';

/// Базовый URL бэкенда в зависимости от платформы.
/// Для веба используем тот же origin (при проксировании) или localhost.
class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) {
      // При разработке бэкенд обычно на localhost:8000.
      // Для продакшена можно проксировать /api на тот же origin.
      return 'http://localhost:8000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android эмулятор
      return 'http://10.0.2.2:8000/api';
    }
    // iOS, desktop
    return 'http://127.0.0.1:8000/api';
  }

  static const Duration requestTimeout = Duration(seconds: 10);
}
