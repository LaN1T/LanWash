import 'api_client.dart';
import 'api_result.dart';

/// Adapter that wraps static [ApiClient] methods so they can be injected
/// and mocked in tests.
class ApiClientAdapter {
  Future<ApiResult<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      ApiClient.post(path, body: body);

  Future<ApiResult<Map<String, dynamic>>> put(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      ApiClient.put(path, body: body);

  Future<ApiResult<Map<String, dynamic>>> delete(String path) =>
      ApiClient.delete(path);
}
