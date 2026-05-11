import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../../domain/entities/log_entry.dart'; // Import LogEntry entity
import '../../data/datasources/remote/auth_api.dart';

class LogApi {
  final String _baseUrl = AppConstants.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthApi().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<LogEntry>> getLogs({int limit = 200}) async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/logs/?limit=$limit'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => LogEntry.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<LogEntry>> getLogsByUser(String username) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/logs/by-user/$username'),
        headers: await _getHeaders(),
      ).timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => LogEntry.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> createLog(String username, String action, String details) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/logs/'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'username': username,
          'action': action,
          'details': details,
        }),
      ).timeout(AppConstants.timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearLogs() async {
    try {
      final resp = await http.delete(Uri.parse('$_baseUrl/logs/'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
