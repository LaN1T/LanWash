import 'dart:convert';
import 'dart:io';
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

  static Future<String?> getToken() async {
    _cachedToken ??= await _storage.read(key: 'jwt_token');
    return _cachedToken;
  }

  static Future<void> setToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: 'jwt_token', value: token);
  }

  static Future<void> deleteToken() async {
    _cachedToken = null;
    await _storage.delete(key: 'jwt_token');
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
    if (body != null) buf.write(' | body: $body');
    if (status != null) buf.write(' | status: $status');
    debugPrint(buf.toString());
  }

  // ─── HTTP Methods ──────────────────────────────────────────────────────────

  static Future<ApiResult<Map<String, dynamic>>> get(String path) async {
    return _request(
      method: 'GET',
      path: path,
      requestFn: (url, headers) => http.get(url, headers: headers),
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
      requestFn: (url, headers) => http.post(
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
      requestFn: (url, headers) => http.put(
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
      requestFn: (url, headers) => http.delete(url, headers: headers),
    );
  }

  // ─── Core request handler ──────────────────────────────────────────────────

  static Future<ApiResult<Map<String, dynamic>>> _request({
    required String method,
    required String path,
    required Future<http.Response> Function(
            Uri url, Map<String, String> headers)
        requestFn,
    Map<String, dynamic>? body,
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
        return Failure(AppError.unauthorized());
      }

      String message = 'Ошибка сервера';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['detail'] != null)
          message = data['detail'].toString();
      } catch (_) {}

      return Failure(AppError.server(response.statusCode, message));
    } on SocketException catch (e) {
      return Failure(AppError.network(e));
    } on FormatException catch (e) {
      return Failure(AppError.unknown(e));
    } on Exception catch (e) {
      return Failure(AppError.unknown(e));
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

  // ─── Raw request (for non-JSON or custom parsing) ──────────────────────────

  static Future<ApiResult<http.Response>> rawGet(String path) async {
    final url = Uri.parse('${AppConfig.baseUrl}$path');
    final headers = await _headers();
    try {
      final resp = await http
          .get(url, headers: headers)
          .timeout(AppConfig.requestTimeout);
      if (resp.statusCode >= 200 && resp.statusCode < 300) return Success(resp);
      if (resp.statusCode == 401) return Failure(AppError.unauthorized());
      return Failure(AppError.server(resp.statusCode));
    } catch (e) {
      return Failure(AppError.network(e));
    }
  }
}
