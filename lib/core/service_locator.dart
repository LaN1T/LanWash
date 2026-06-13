import 'package:get_it/get_it.dart';
import '../providers/offline_provider.dart';
import '../services/api_service.dart';
import '../services/car_catalog_service.dart';
import '../services/notification_service.dart';
import 'api_client_adapter.dart';
import 'offline/connectivity_monitor.dart';
import 'offline/database.dart';
import 'offline/offline_repository.dart';
import 'offline/sync_service.dart';

/// Глобальный DI-контейнер.
/// Регистрирует все зависимости приложения как singleton'ы.
final GetIt sl = GetIt.instance;

/// Инициализация DI. Вызывать до `runApp()`.
void setupServiceLocator() {
  // Сервисы (singleton — создаются один раз)
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase());
  sl.registerLazySingleton<OfflineRepository>(
      () => OfflineRepository(sl<AppDatabase>()));
  sl.registerLazySingleton<ApiClientAdapter>(() => ApiClientAdapter());
  sl.registerLazySingleton<SyncService>(
    () => SyncService(sl<OfflineRepository>(), sl<ApiClientAdapter>()),
  );
  sl.registerLazySingleton<ConnectivityMonitor>(
    () => ConnectivityMonitor(
      onChanged: (_) {}, // replaced by OfflineProvider
    ),
  );
  sl.registerLazySingleton<OfflineProvider>(
    () => OfflineProvider(
      monitor: sl<ConnectivityMonitor>(),
      syncService: sl<SyncService>(),
      repository: sl<OfflineRepository>(),
    ),
  );
  sl.registerLazySingleton<ApiService>(
    () => ApiService(offlineRepository: sl<OfflineRepository>()),
  );
  sl.registerLazySingleton<NotificationService>(() => NotificationService());
  sl.registerSingleton<CarCatalogService>(CarCatalogService());
}
