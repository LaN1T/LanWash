import 'package:flutter/foundation.dart';

/// Централизованная конфигурация приложения.
///
/// API URL можно задать через dart-define при сборке:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000/api
///
/// Если не задан — используется fallback для текущей платформы.
class AppConfig {
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_apiBaseUrl.isNotEmpty) {
      return _apiBaseUrl;
    }
    // Fallback для локальной разработки
    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  static const Duration requestTimeout = Duration(seconds: 10);

  // Фича-флаги
  static const bool enableLogging = kDebugMode;
}
