import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart';
import 'api_result.dart';

/// Централизованный HTTP-клиент.
///
/// Оборачивает все запросы в [ApiResult<T>], автоматически добавляет
/// JWT-заголовок и обрабатывает типичные ошибки.
class ApiClient {
  static const _storage = FlutterSecureStorage();
  static String? _cachedToken;
  static Completer<String?>? _refreshCompleter;
  static http.Client _httpClient = http.Client();

  /// Для тестов: позволяет подменить HTTP-клиент.
  @visibleForTesting
  static set httpClient(http.Client client) => _httpClient = client;

  /// Для тестов: позволяет установить токен без обращения к хранилищу.
  @visibleForTesting
  static set token(String? token) => _cachedToken = token;

  static Future<String?> getToken() async {
    try {
      _cachedToken ??= await _storage.read(key: 'jwt_token');
    } catch (e) {
      if (kDebugMode) debugPrint('getToken error: $e');
    }
    return _cachedToken;
  }

  static Future<void> setToken(String token) async {
    _cachedToken = token;
    try {
      await _storage.write(key: 'jwt_token', value: token);
    } catch (e) {
      if (kDebugMode) debugPrint('setToken error: $e');
    }
  }

  static Future<void> deleteToken() async {
    _cachedToken = null;
    try {
      await _storage.delete(key: 'jwt_token');
    } catch (e) {
      if (kDebugMode) debugPrint('deleteToken error: $e');
    }
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static void _log(String method, String url, {Object? body, int? status}) {
    if (!AppConfig.enableLogging) return;
    final buf = StringBuffer();
    buf.write('⬆️ $method $url');
    if (body != null) {
      final bodyMap = body as Map<String, dynamic>?;
      if (bodyMap != null) {
        final keys = bodyMap.keys.join(', ');
        buf.write(' | body keys: [$keys]');
      } else {
        buf.write(' | body: <${(body.toString().length)} chars>');
      }
    }
    if (status != null) buf.write(' | status: $status');
    if (kDebugMode) debugPrint(buf.toString());
  }

  // ─── HTTP Methods ──────────────────────────────────────────────────────────

  static Future<ApiResult<Map<String, dynamic>>> get(String path) async {
    return _request(
      method: 'GET',
      path: path,
      requestFn: (url, headers) => _httpClient.get(url, headers: headers),
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _request(
      method: 'POST',
      path: path,
      body: body,
      requestFn: (url, headers) => _httpClient.post(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _request(
      method: 'PUT',
      path: path,
      body: body,
      requestFn: (url, headers) => _httpClient.put(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> delete(String path) async {
    return _request(
      method: 'DELETE',
      path: path,
      requestFn: (url, headers) => _httpClient.delete(url, headers: headers),
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _request(
      method: 'PATCH',
      path: path,
      body: body,
      requestFn: (url, headers) => _httpClient.patch(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  // ─── Token refresh ─────────────────────────────────────────────────────────

  static Future<String?> _refreshToken() async {
    // Если refresh уже в процессе — ждём его результат
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();
    try {
      final token = _cachedToken;
      if (token == null) {
        _refreshCompleter!.complete(null);
        return null;
      }

      final refreshResponse = await _httpClient.post(
        Uri.parse('${AppConfig.baseUrl}/auth/refresh'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (refreshResponse.statusCode == 200) {
        final data = jsonDecode(refreshResponse.body);
        if (data is Map && data['access_token'] != null) {
          final newToken = data['access_token'] as String;
          await setToken(newToken);
          _refreshCompleter!.complete(newToken);
          return newToken;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Token refresh failed: $e');
    } finally {
      // Если completer ещё не завершён — завершим с null
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(null);
      }
      _refreshCompleter = null;
    }
    await deleteToken();
    return null;
  }

  // ─── Core request handler ──────────────────────────────────────────────────

  static Future<ApiResult<Map<String, dynamic>>> _request({
    required String method,
    required String path,
    required Future<http.Response> Function(
            Uri url, Map<String, String> headers)
        requestFn,
    Map<String, dynamic>? body,
    int retryCount = 0,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}$path');
    final headers = await _headers();

    _log(method, url.toString(), body: body);

    try {
      final response =
          await requestFn(url, headers).timeout(AppConfig.requestTimeout);
      _log(method, url.toString(), status: response.statusCode);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : <String, dynamic>{};
        return Success(data as Map<String, dynamic>);
      }

      if (response.statusCode == 401) {
        if (retryCount < 1) {
          final newToken = await _refreshToken();
          if (newToken != null) {
            return _request(
              method: method,
              path: path,
              requestFn: requestFn,
              body: body,
              retryCount: retryCount + 1,
            );
          }
        }
        return Failure(AppError.unauthorized());
      }

      String message = 'Ошибка сервера';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['detail'] != null) {
          message = data['detail'].toString();
        }
      } catch (_) {}

      // В release не показываем детали серверных ошибок пользователю
      if (!kDebugMode && response.statusCode >= 500) {
        message = 'Ошибка сервера. Попробуйте позже.';
      }

      return Failure(AppError.server(response.statusCode, message));
    } on http.ClientException catch (e) {
      return Failure(AppError.network(e));
    } on FormatException catch (e) {
      return Failure(AppError.unknown(e));
    } on Exception catch (e) {
      return Failure(AppError.network(e));
    }
  }

  // ─── Helpers for common response types ─────────────────────────────────────

  static Future<ApiResult<List<dynamic>>> getList(String path) async {
    final result = await rawGet(path);
    return result.when(
      success: (resp) {
        final data = jsonDecode(resp.body);
        if (data is List) return Success(data);
        return Failure(
            AppError.validation('Expected list, got ${data.runtimeType}'));
      },
      failure: (err) => Failure(err),
    );
  }

  // ─── Сырой запрос (для не-JSON или кастомного парсинга) ────────────────────

  static Future<ApiResult<http.Response>> rawGet(String path) async {
    return _rawRequest(
      path: path,
      requestFn: (url, headers) => _httpClient.get(url, headers: headers),
    );
  }

  static Future<ApiResult<http.Response>> _rawRequest({
    required String path,
    required Future<http.Response> Function(Uri url, Map<String, String> headers)
        requestFn,
    int retryCount = 0,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}$path');
    final headers = await _headers();
    try {
      final resp = await requestFn(url, headers).timeout(AppConfig.requestTimeout);
      if (resp.statusCode >= 200 && resp.statusCode < 300) return Success(resp);

      if (resp.statusCode == 401) {
        if (retryCount < 1) {
          final newToken = await _refreshToken();
          if (newToken != null) {
            return _rawRequest(
              path: path,
              requestFn: requestFn,
              retryCount: retryCount + 1,
            );
          }
        }
        return Failure(AppError.unauthorized());
      }
      return Failure(AppError.server(resp.statusCode));
    } catch (e) {
      if (kDebugMode) debugPrint('rawGet error: $e | url: $url');
      return Failure(AppError.network(e));
    }
  }
}
