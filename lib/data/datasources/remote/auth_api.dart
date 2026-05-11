import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/constants.dart';
import '../../domain/entities/user.dart'; // Import User entity

class AuthApi {
  final String _baseUrl = AppConstants.baseUrl;
  final _storage = FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> setToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'jwt_token');
  }

  Future<User?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(AppConstants.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setToken(data['access_token']);
        return User.fromMap(data['user']);
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }

  Future<User?> register(String username, String password, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password, 'role': role}),
      ).timeout(AppConstants.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setToken(data['access_token']);
        return User.fromMap(data['user']);
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }

  Future<List<User>> getWashers() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/auth/washers'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => User.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }
}
