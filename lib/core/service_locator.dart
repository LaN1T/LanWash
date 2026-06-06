import 'package:get_it/get_it.dart';
import '../services/api_service.dart';
import '../services/car_catalog_service.dart';
import '../services/notification_service.dart';

/// Глобальный DI-контейнер.
/// Регистрирует все зависимости приложения как singleton'ы.
final GetIt sl = GetIt.instance;

/// Инициализация DI. Вызывать до `runApp()`.
void setupServiceLocator() {
  // Сервисы (singleton — создаются один раз)
  sl.registerLazySingleton<ApiService>(() => ApiService());
  sl.registerLazySingleton<NotificationService>(() => NotificationService());
  sl.registerSingleton<CarCatalogService>(CarCatalogService());
}
