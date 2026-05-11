import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../../domain/entities/promo.dart';
import '../../data/datasources/remote/auth_api.dart';

class PromoApi {
  final String _baseUrl = AppConstants.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthApi().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Promo>> getPromos() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/promos/'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => Promo.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }
}
