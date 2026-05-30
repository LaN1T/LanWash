import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lanwash/core/api_client.dart';
import 'package:lanwash/models/appointment.dart';
import 'package:lanwash/models/service.dart';
import 'package:lanwash/services/api_service.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

/// Хелпер: создаёт http.Response с UTF-8 body и правильными headers.
http.Response _jsonResponse(dynamic data, int statusCode,
    {Map<String, String>? extraHeaders}) {
  final body = jsonEncode(data);
  final headers = {
    'content-type': 'application/json; charset=utf-8',
    if (extraHeaders != null) ...extraHeaders,
  };
  return http.Response(body, statusCode, headers: headers);
}

void main() {
  late MockHttpClient mockClient;
  late ApiService apiService;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Мокаем FlutterSecureStorage channel
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    mockClient = MockHttpClient();
    ApiClient.httpClient = mockClient;
    ApiClient.token = 'test_token';
    apiService = ApiService();
  });

  tearDown(() {
    ApiClient.httpClient = http.Client();
    ApiClient.token = null;
  });

  // ─── Auth ───────────────────────────────────────────────────────────────────

  group('ApiService Auth', () {
    test('login returns User on success', () async {
      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _jsonResponse({
                'access_token': 'tok123',
                'user': {
                  'id': 1,
                  'username': 'test',
                  'passwordHash': 'h',
                  'role': 'client',
                  'displayName': 'Test',
                  'createdAt': '2024-01-01T00:00:00Z',
                }
              }, 200));

      final user = await apiService.login('test', 'pass');
      expect(user, isNotNull);
      expect(user!.username, equals('test'));
    });

    test('login returns null on failure', () async {
      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('Unauthorized', 401));

      final user = await apiService.login('test', 'wrong');
      expect(user, isNull);
    });

    test('register returns user data on success', () async {
      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _jsonResponse({
                'access_token': 'tok',
                'user': {'id': 2, 'username': 'new'}
              }, 200));

      final result = await apiService.register(
        username: 'new',
        password: 'Pass123!',
        displayName: 'New User',
      );
      expect(result, isNotNull);
      expect(result!['user'], isNotNull);
    });

    test('register returns error on 400', () async {
      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _jsonResponse({'detail': 'Username taken'}, 400));

      final result = await apiService.register(
        username: 'exists',
        password: 'Pass123!',
        displayName: 'Exists',
      );
      expect(result, isNotNull);
      expect(result!['error'], contains('Username taken'));
    });
  });

  // ─── Appointments ───────────────────────────────────────────────────────────

  group('ApiService Appointments', () {
    test('getAppointments returns PaginatedAppointments', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _jsonResponse([
                {'id': 'a1', 'clientName': 'Client', 'carModel': 'Camry', 'carNumber': 'А123БВ77', 'dateTime': '2024-01-01T10:00:00Z', 'washTypeId': 'w1', 'additionalServices': '[]', 'status': 'scheduled', 'notes': '', 'isFavorite': false, 'ownerUsername': 'client', 'promoPrice': 0, 'paidPrice': 500, 'originalPrice': 500, 'assignedWasher': '[]', 'box_index': 0}
              ], 200, extraHeaders: {
                'x-total-pages': '5',
                'x-current-page': '2',
                'x-current-date': '2024-01-01',
                'x-unique-dates': jsonEncode(['2024-01-01', '2024-01-02']),
              }));

      final result = await apiService.getAppointments(page: 2);
      expect(result.appointments.length, equals(1));
      expect(result.totalPages, equals(5));
      expect(result.currentPage, equals(2));
      expect(result.uniqueDates.length, equals(2));
    });

    test('createAppointment returns true on success', () async {
      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _jsonResponse({'ok': true}, 200));

      final appt = Appointment(
        id: 'a1',
        clientName: 'Test',
        carModel: 'Camry',
        carNumber: 'А123БВ77',
        dateTime: DateTime.now(),
        washTypeId: 'w1',
        additionalServices: [],
        status: 'scheduled',
      );

      final ok = await apiService.createAppointment(appt);
      expect(ok, isTrue);
    });

    test('deleteAppointment returns true on success', () async {
      when(() => mockClient.delete(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _jsonResponse({'ok': true}, 200));

      final ok = await apiService.deleteAppointment('a1');
      expect(ok, isTrue);
    });

    test('deleteAppointment returns false on failure', () async {
      when(() => mockClient.delete(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Forbidden', 403));

      final ok = await apiService.deleteAppointment('a1');
      expect(ok, isFalse);
    });
  });

  // ─── Services ───────────────────────────────────────────────────────────────

  group('ApiService Services', () {
    test('getServices returns list on success', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _jsonResponse([
                {'id': 's1', 'name': 'Мойка', 'description': '', 'price': 500, 'durationMinutes': 30, 'category': 'Мойка', 'isFavorite': false, 'isFromApi': false}
              ], 200));

      final services = await apiService.getServices();
      expect(services.length, equals(1));
      expect(services.first.name, equals('Мойка'));
    });

    test('createService returns true on success', () async {
      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _jsonResponse({'ok': true}, 200));

      final service = Service(
        id: 's1',
        name: 'Тест',
        description: '',
        price: 100,
        durationMinutes: 15,
        category: 'cat',
      );

      final ok = await apiService.createService(service);
      expect(ok, isTrue);
    });

    test('deleteService returns true on success', () async {
      when(() => mockClient.delete(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _jsonResponse({'ok': true}, 200));

      final ok = await apiService.deleteService('s1');
      expect(ok, isTrue);
    });
  });

  // ─── Notes ──────────────────────────────────────────────────────────────────

  group('ApiService Notes', () {
    test('getNotes returns list on success', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _jsonResponse([
                {'id': 1, 'username': 'washer', 'title': 'Заметка', 'message': 'Текст', 'category': 'general', 'isRead': 0, 'createdAt': '2024-01-01T00:00:00Z'}
              ], 200));

      final notes = await apiService.getNotes();
      expect(notes.length, equals(1));
      expect(notes.first.title, equals('Заметка'));
    });

    test('createNote returns Note on success', () async {
      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _jsonResponse(
                {'id': 2, 'username': 'washer', 'title': 'Новая', 'message': '', 'category': 'general', 'isRead': 0, 'createdAt': '2024-01-01T00:00:00Z'},
                200,
              ));

      final note = await apiService.createNote('washer', 'Новая', '', 'general');
      expect(note, isNotNull);
      expect(note!.title, equals('Новая'));
    });

    test('markNoteRead returns true on success', () async {
      when(() => mockClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _jsonResponse({'ok': true}, 200));

      final ok = await apiService.markNoteRead(1);
      expect(ok, isTrue);
    });
  });
}
