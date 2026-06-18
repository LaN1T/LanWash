import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lanwash/core/api_client.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    mockClient = MockHttpClient();
    ApiClient.httpClient = mockClient;
    ApiClient.token = 'test_token';
  });

  tearDown(() {
    ApiClient.httpClient = http.Client();
    ApiClient.token = null;
  });

  group('ApiClient GET', () {
    test('returns Success on 200 with JSON body', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('{"ok":true}', 200));

      final result = await ApiClient.get('/test');

      expect(result.isSuccess, isTrue);
      expect(result.data, equals({'ok': true}));
    });

    test('returns Success on 204 empty body', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('', 204));

      final result = await ApiClient.get('/test');

      expect(result.isSuccess, isTrue);
      expect(result.data, equals(<String, dynamic>{}));
    });

    test('returns Failure on 401', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Unauthorized', 401));
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('{"error":"invalid"}', 401));

      final result = await ApiClient.get('/test');

      expect(result.isFailure, isTrue);
      expect(result.error!.statusCode, equals(401));
    });

    test('returns Failure on 500 with detail message', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (_) async => http.Response('{"detail":"Server down"}', 500));

      final result = await ApiClient.get('/test');

      expect(result.isFailure, isTrue);
      expect(result.error!.message, contains('Server down'));
    });

    test('returns network error on SocketException', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(const SocketException('No internet'));

      final result = await ApiClient.get('/test');

      expect(result.isFailure, isTrue);
      expect(result.error!.message, contains('сети'));
    });
  });

  group('ApiClient POST', () {
    test('sends JSON body and returns Success', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('{"id":"1"}', 201));

      final result = await ApiClient.post('/create', body: {'name': 'Test'});

      expect(result.isSuccess, isTrue);
      expect(result.data, equals({'id': '1'}));
    });

    test('returns Failure on 400 validation error', () async {
      when(() => mockClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer(
              (_) async => http.Response('{"detail":"Invalid input"}', 400));

      final result = await ApiClient.post('/create', body: {'bad': 'data'});

      expect(result.isFailure, isTrue);
      expect(result.error!.message, contains('Invalid input'));
    });
  });

  group('ApiClient PUT', () {
    test('returns Success on 200', () async {
      when(() => mockClient.put(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('{"updated":true}', 200));

      final result = await ApiClient.put('/update', body: {'x': 1});

      expect(result.isSuccess, isTrue);
      expect(result.data, equals({'updated': true}));
    });
  });

  group('ApiClient DELETE', () {
    test('returns Success on 200', () async {
      when(() => mockClient.delete(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('{"deleted":true}', 200));

      final result = await ApiClient.delete('/remove');

      expect(result.isSuccess, isTrue);
      expect(result.data, equals({'deleted': true}));
    });
  });

  group('ApiClient getList', () {
    test('returns List on 200', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('[{"id":1},{"id":2}]', 200));

      final result = await ApiClient.getList('/items');

      expect(result.isSuccess, isTrue);
      expect(result.data, isA<List>());
      expect((result.data as List).length, equals(2));
    });

    test('returns Failure when response is not a list', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('{"id":1}', 200));

      final result = await ApiClient.getList('/items');

      expect(result.isFailure, isTrue);
    });
  });

  group('ApiClient rawGet', () {
    test('returns http.Response on 200', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('raw', 200));

      final result = await ApiClient.rawGet('/raw');

      expect(result.isSuccess, isTrue);
      expect((result.data as http.Response).body, equals('raw'));
    });
  });
}
