import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/service.dart';
import '../models/appointment.dart';
import '../models/log_entry.dart';
import '../models/note.dart';
import '../models/user.dart';
import '../models/report_entry.dart';
import '../models/promo.dart';
import '../models/wash_type.dart';

class ApiService {
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    } else {
      return 'http://127.0.0.1:8000/api';
    }
  }
  // ─── Auth ───────────────────────────────────────────────────────────────────
  Future<User?> login(String username, String password) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return User.fromMap(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> register({
    required String username,
    required String password,
    required String displayName,
    String phone = '',
    String carModel = '',
    String carNumber = '',
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'displayName': displayName,
          'phone': phone,
          'carModel': carModel,
          'carNumber': carNumber,
        }),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return {'user': jsonDecode(resp.body)};
      }
      final err = jsonDecode(resp.body);
      return {'error': err['detail'] ?? 'Ошибка регистрации'};
    } catch (e) {
      return {'error': 'Нет связи с сервером'};
    }
  }

  Future<User?> updateProfile(int userId, {
    String? displayName,
    String? phone,
    String? carModel,
    String? carNumber,
    String? newPassword,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (displayName != null) body['displayName'] = displayName;
      if (phone != null) body['phone'] = phone;
      if (carModel != null) body['carModel'] = carModel;
      if (carNumber != null) body['carNumber'] = carNumber;
      if (newPassword != null) body['newPassword'] = newPassword;

      final resp = await http.put(
        Uri.parse('$_baseUrl/auth/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return User.fromMap(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  // ─── Appointments ───────────────────────────────────────────────────────────
  Future<List<Appointment>> getAppointments() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/appointments/'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => Appointment.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Appointment>> getAppointmentsByOwner(String username) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/appointments/by-owner/$username'),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => Appointment.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> createAppointment(Appointment a) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/appointments/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(a.toMap()),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateAppointment(Appointment a) async {
    try {
      final resp = await http.put(
        Uri.parse('$_baseUrl/appointments/${a.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(a.toMap()),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAppointment(String id) async {
    try {
      final resp = await http.delete(Uri.parse('$_baseUrl/appointments/$id'))
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasDeletedNotification(String username) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/appointments/deleted-notification/$username'),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body)['hasNotification'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> clearDeletedNotification(String username) async {
    try {
      final resp = await http.delete(
        Uri.parse('$_baseUrl/appointments/deleted-notification/$username'),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {}
    return false;
  }

  Future<bool> clearAdminModifiedFlag(String id) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/appointments/$id/clear-admin-flag'),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleAppointmentFavorite(String id) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/appointments/$id/toggle-favorite'),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, int>> getAppointmentStats() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/appointments/stats'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final m = jsonDecode(resp.body);
        return {
          'total': m['total'] ?? 0,
          'scheduled': m['scheduled'] ?? 0,
          'completed': m['completed'] ?? 0,
        };
      }
    } catch (_) {}
    return {'total': 0, 'scheduled': 0, 'completed': 0};
  }

  Future<List<Appointment>> getAppointmentsByWasher(String username) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/appointments/by-washer/$username'),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => Appointment.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> assignWasher(String appointmentId, String washerUsername) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/appointments/$appointmentId/assign-washer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'washerUsername': washerUsername}),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<User>> getWashers() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/auth/washers'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => User.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── Services ───────────────────────────────────────────────────────────────
  Future<List<Service>> getServices() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/services/'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => Service.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<String>> getServiceCategories() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/services/categories'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.cast<String>();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> createService(Service s) async {
    try {
      final body = s.toMap();
      body['updatedAt'] = DateTime.now().toIso8601String();
      final resp = await http.post(
        Uri.parse('$_baseUrl/services/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateService(Service s) async {
    try {
      final body = s.toMap();
      body['updatedAt'] = DateTime.now().toIso8601String();
      final resp = await http.put(
        Uri.parse('$_baseUrl/services/${s.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteService(String id) async {
    try {
      final resp = await http.delete(Uri.parse('$_baseUrl/services/$id'))
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Service Favorites ────────────────────────────────────────────────────
  Future<Set<String>> getServiceFavorites(String username) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/services/favorites/$username'),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.cast<String>().toSet();
      }
    } catch (_) {}
    return {};
  }

  Future<bool> toggleServiceFavorite(String username, String serviceId) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/services/favorites/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'serviceId': serviceId}),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Extra Favorites ──────────────────────────────────────────────────────
  Future<Set<String>> getExtraFavorites(String username) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/services/extra-favorites/$username'),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.cast<String>().toSet();
      }
    } catch (_) {}
    return {};
  }

  Future<bool> toggleExtraFavorite(String username, String serviceId) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/services/extra-favorites/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'serviceId': serviceId}),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Promos ────────────────────────────────────────────────────────────────
  Future<List<Promo>> getPromos() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/services/promos'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => Promo.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── Wash Types ────────────────────────────────────────────────────────────
  Future<List<WashType>> getWashTypes() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/wash-types/'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => WashType.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<WashType?> updateWashType(WashType wt) async {
    try {
      final resp = await http.put(
        Uri.parse('$_baseUrl/wash-types/${wt.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(wt.toMap()),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return WashType.fromMap(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  // ─── Logs ─────────────────────────────────────────────────────────────────
  Future<List<LogEntry>> getLogs({int limit = 200}) async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/logs/?limit=$limit'))
          .timeout(const Duration(seconds: 10));
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
      ).timeout(const Duration(seconds: 10));
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
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'action': action,
          'details': details,
        }),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearLogs() async {
    try {
      final resp = await http.delete(Uri.parse('$_baseUrl/logs/'))
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Notes ────────────────────────────────────────────────────────────────
  Future<List<Note>> getNotes() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/notes/'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => Note.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Note>> getNotesByUser(String username) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/notes/by-user/$username'),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => Note.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<int> getUnreadNotesCount() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/notes/unread-count'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body)['count'] ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<Note?> createNote(String username, String title, String message, String category) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/notes/?username=$username'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'message': message,
          'category': category,
        }),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return Note.fromMap(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  Future<bool> markNoteRead(int noteId) async {
    try {
      final resp = await http.put(Uri.parse('$_baseUrl/notes/$noteId/read'))
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllNotesRead() async {
    try {
      final resp = await http.put(Uri.parse('$_baseUrl/notes/read-all'))
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteNote(int noteId) async {
    try {
      final resp = await http.delete(Uri.parse('$_baseUrl/notes/$noteId'))
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }


  // ─── Reports ───────────────────────────────────────────────────────────────
  Future<MonthlyReport?> getAverageCheckReport(String? date) async {
    try {
      final url = date != null 
          ? '$_baseUrl/reports/monthly-check-vs-price/?date=$date'
          : '$_baseUrl/reports/monthly-check-vs-price/';
      final resp = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
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
      final resp = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
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
      
      final resp = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return ConsumablesUsageReport.fromJson(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }
}
