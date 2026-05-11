import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../../domain/entities/service.dart';
import '../../data/datasources/remote/auth_api.dart';

class ServiceApi {
  final String _baseUrl = AppConstants.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthApi().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Service>> getServices() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/services/'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => Service.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> createService(Service service) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/services/'),
        headers: await _getHeaders(),
        body: jsonEncode(service.toMap()),
      ).timeout(AppConstants.timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateService(Service service) async {
    try {
      final resp = await http.put(
        Uri.parse('$_baseUrl/services/${service.id}'),
        headers: await _getHeaders(),
        body: jsonEncode(service.toMap()),
      ).timeout(AppConstants.timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteService(String id) async {
    try {
      final resp = await http.delete(Uri.parse('$_baseUrl/services/$id'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleServiceFavorite(String user, String id) async {
    try {
      await http.put(
        Uri.parse('$_baseUrl/services/$id/favorite?user=$user'),
        headers: await _getHeaders(),
      ).timeout(AppConstants.timeout);
    } catch (_) {}
  }

  Future<void> toggleExtraFavorite(String user, String serviceId) async {
    try {
      await http.put(
        Uri.parse('$_baseUrl/services/extra/$serviceId/favorite?user=$user'),
        headers: await _getHeaders(),
      ).timeout(AppConstants.timeout);
    } catch (_) {}
  }
}
