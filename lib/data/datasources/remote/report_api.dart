import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../../domain/entities/report_entry.dart'; // Assuming MonthlyReport, PopularServicesReport, ConsumablesUsageReport are entities
import '../../data/datasources/remote/auth_api.dart';

class ReportApi {
  final String _baseUrl = AppConstants.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthApi().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<MonthlyReport?> getAverageCheckReport(String? date) async {
    try {
      final url = date != null 
          ? '$_baseUrl/reports/monthly-check-vs-price/?date=$date'
          : '$_baseUrl/reports/monthly-check-vs-price/';
      final resp = await http.get(Uri.parse(url), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        return MonthlyReport.fromJson(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  Future<PopularServicesReport?> getPopularAdditionalServices(String? date, {String? category}) async {
    try {
      String url = date != null 
          ? '$_baseUrl/reports/popular-additional-services/?date=$date'
          : '$_baseUrl/reports/popular-additional-services/';
      if (category != null && category != 'Все') {
        url += '&category=$category';
      }
      final resp = await http.get(Uri.parse(url), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        return PopularServicesReport.fromJson(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  Future<ConsumablesUsageReport?> getConsumablesUsageReport(String? date, {String? category}) async {
    try {
      var url = '$_baseUrl/reports/consumables-usage/';
      final params = <String>[];
      if (date != null) params.add('date=$date');
      if (category != null && category != 'Все') params.add('category=$category');
      
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }
      
      final resp = await http.get(Uri.parse(url), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        return ConsumablesUsageReport.fromJson(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }
}
