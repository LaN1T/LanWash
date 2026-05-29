import 'package:mocktail/mocktail.dart';
import 'package:lanwash/providers/auth_provider.dart';
import 'package:lanwash/providers/app_provider.dart';
import 'package:lanwash/services/api_service.dart';
import 'package:lanwash/services/notification_service.dart';

class MockApiService extends Mock implements ApiService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockAuthProvider extends Mock implements AuthProvider {}

class MockAppProvider extends Mock implements AppProvider {}

class FakeAuthProvider extends Fake implements AuthProvider {}

class FakeAppProvider extends Fake implements AppProvider {}

void registerMockFallbacks() {
  registerFallbackValue(FakeAuthProvider());
  registerFallbackValue(FakeAppProvider());
}
