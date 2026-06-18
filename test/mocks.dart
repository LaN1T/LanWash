import 'package:mocktail/mocktail.dart';
import 'package:lanwash/providers/auth_provider.dart';
import 'package:lanwash/providers/appointment_provider.dart';
import 'package:lanwash/providers/catalog_provider.dart';
import 'package:lanwash/providers/note_provider.dart';
import 'package:lanwash/providers/favorite_provider.dart';
import 'package:lanwash/services/api_service.dart';
import 'package:lanwash/services/notification_service.dart';

class MockApiService extends Mock implements ApiService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockAuthProvider extends Mock implements AuthProvider {}

class MockAppointmentProvider extends Mock implements AppointmentProvider {}

class MockCatalogProvider extends Mock implements CatalogProvider {}

class MockNoteProvider extends Mock implements NoteProvider {}

class MockFavoriteProvider extends Mock implements FavoriteProvider {}

class FakeAuthProvider extends Fake implements AuthProvider {}

class FakeAppointmentProvider extends Fake implements AppointmentProvider {}

void registerMockFallbacks() {
  registerFallbackValue(FakeAuthProvider());
  registerFallbackValue(FakeAppointmentProvider());
}
