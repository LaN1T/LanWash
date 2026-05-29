import 'package:flutter_test/flutter_test.dart';
import 'package:lanwash/core/api_result.dart';

void main() {
  group('ApiResult<T>', () {
    test('Success holds value and isSuccess is true', () {
      const result = Success<int>(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.data, equals(42));
      expect(result.error, isNull);
    });

    test('Failure holds error and isFailure is true', () {
      const err = AppError(message: 'boom', statusCode: 500);
      const result = Failure<int>(err);
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.data, isNull);
      expect(result.error, equals(err));
    });

    test('when returns success branch', () {
      const result = Success<String>('ok');
      final value = result.when(
        success: (s) => 'got $s',
        failure: (e) => 'error ${e.message}',
      );
      expect(value, equals('got ok'));
    });

    test('when returns failure branch', () {
      const err = AppError(message: 'fail');
      const result = Failure<String>(err);
      final value = result.when(
        success: (s) => 'got $s',
        failure: (e) => 'error ${e.message}',
      );
      expect(value, equals('error fail'));
    });
  });

  group('AppError factories', () {
    test('network creates correct message', () {
      final e = AppError.network();
      expect(e.message, contains('сети'));
      expect(e.statusCode, isNull);
    });

    test('unauthorized has statusCode 401', () {
      final e = AppError.unauthorized();
      expect(e.statusCode, equals(401));
    });

    test('server includes statusCode', () {
      final e = AppError.server(503);
      expect(e.statusCode, equals(503));
    });

    test('validation includes custom message', () {
      final e = AppError.validation('bad input');
      expect(e.message, equals('bad input'));
      expect(e.statusCode, equals(400));
    });
  });
}
