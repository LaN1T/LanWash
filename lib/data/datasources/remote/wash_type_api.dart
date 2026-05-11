import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../../domain/entities/wash_type.dart';
import '../../data/datasources/remote/auth_api.dart';

class WashTypeApi {
  final String _baseUrl = AppConstants.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthApi().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<WashType>> getWashTypes() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/wash-types/'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => WashType.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> updateWashType(WashType washType) async {
    try {
      final resp = await http.put(
        Uri.parse('$_baseUrl/wash-types/${washType.id}'),
        headers: await _getHeaders(),
        body: jsonEncode(washType.toMap()),
      ).timeout(AppConstants.timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
