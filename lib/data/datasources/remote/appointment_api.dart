import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../../data/models/appointment_dto.dart';
import '../../domain/entities/appointment.dart';
import '../../data/datasources/remote/auth_api.dart';

class AppointmentApi {
  final String _baseUrl = AppConstants.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthApi().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Appointment>> getAppointments({int? page, int? limit}) async {
    try {
      final queryParams = <String>[];
      if (page != null) queryParams.add('page=$page');
      if (limit != null) queryParams.add('limit=$limit');
      final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      
      final resp = await http.get(Uri.parse('$_baseUrl/appointments/$queryString'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => AppointmentDto.fromMap(m).toEntity()).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Appointment>> getAppointmentsByOwner(String username) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/appointments/by-owner/$username'),
        headers: await _getHeaders(),
      ).timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => AppointmentDto.fromMap(m).toEntity()).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Appointment>> getAppointmentsByWasher(String username) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/appointments/by-washer/$username'),
        headers: await _getHeaders(),
      ).timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => AppointmentDto.fromMap(m).toEntity()).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> createAppointment(Appointment appointment) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/appointments/'),
        headers: await _getHeaders(),
        body: jsonEncode(appointment.toMap()),
      ).timeout(AppConstants.timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateAppointment(Appointment appointment) async {
    try {
      final resp = await http.put(
        Uri.parse('$_baseUrl/appointments/${appointment.id}'),
        headers: await _getHeaders(),
        body: jsonEncode(appointment.toMap()),
      ).timeout(AppConstants.timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAppointment(String id) async {
    try {
      final resp = await http.delete(Uri.parse('$_baseUrl/appointments/$id'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleAppointmentFavorite(String id) async {
    try {
      await http.put(Uri.parse('$_baseUrl/appointments/$id/favorite'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
    } catch (_) {}
  }

  Future<void> clearAdminModifiedFlag(String id) async {
    try {
      await http.put(Uri.parse('$_baseUrl/appointments/$id/clear-admin-modified'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
    } catch (_) {}
  }

  Future<void> markAppointmentSeen(String id) async {
    try {
      await http.put(Uri.parse('$_baseUrl/appointments/$id/seen'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
    } catch (_) {}
  }
}
