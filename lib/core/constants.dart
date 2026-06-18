import 'config.dart';

/// @deprecated Используйте [AppConfig] напрямую.
/// Оставлено для обратной совместимости со старым ApiService.
class ApiConstants {
  static String get baseUrl => AppConfig.baseUrl;
  static const Duration requestTimeout = AppConfig.requestTimeout;
}
