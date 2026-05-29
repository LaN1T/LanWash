import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';
import '../models/service.dart';
import '../models/appointment.dart';
import '../models/log_entry.dart';
import '../models/note.dart';
import '../models/user.dart';
import '../models/report_entry.dart';
import '../models/promo.dart';
import '../models/wash_type.dart';

class PaginatedAppointments {
  final List<Appointment> appointments;
  final int totalPages;
  final int currentPage;
  final String currentDate;
  final List<String> uniqueDates;

  PaginatedAppointments({
    required this.appointments,
    required this.totalPages,
    required this.currentPage,
    required this.currentDate,
    required this.uniqueDates,
  });
}

class ApiService {
  static String get _baseUrl => ApiConstants.baseUrl;

  static const _storage = FlutterSecureStorage();
  static String? _token;

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    _token = await _storage.read(key: 'jwt_token');
    return _token;
  }

  static Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: 'jwt_token', value: token);
  }

  static Future<void> deleteToken() async {
    _token = null;
    await _storage.delete(key: 'jwt_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Auth ───────────────────────────────────────────────────────────────────
  Future<User?> login(String username, String password) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(ApiConstants.requestTimeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        await setToken(data['access_token']);
        return User.fromMap(data['user']);
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
      ).timeout(ApiConstants.requestTimeout);
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        await setToken(data['access_token']);
        return {'user': data['user']};
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
        headers: await _getHeaders(),
        body: jsonEncode(body),
      ).timeout(ApiConstants.requestTimeout);
      if (resp.statusCode == 200) {
        return User.fromMap(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  // ─── Appointments ───────────────────────────────────────────────────────────
  Future<PaginatedAppointments> getAppointments({int? page, String? date}) async {
    try {
      final queryParams = <String>[];
      if (page != null) queryParams.add('page=$page');
      if (date != null) queryParams.add('date=$date');
      final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      
      final resp = await http.get(Uri.parse('$_baseUrl/appointments/$queryString'), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        final appointments = list.map((m) => Appointment.fromMap(m)).toList();
        
        final totalPagesHeader = resp.headers['x-total-pages'] ?? resp.headers['X-Total-Pages'];
        final totalPages = totalPagesHeader != null ? int.tryParse(totalPagesHeader) ?? 1 : 1;
        
        final currentPageHeader = resp.headers['x-current-page'] ?? resp.headers['X-Current-Page'];
        final currentPage = currentPageHeader != null ? int.tryParse(currentPageHeader) ?? 1 : 1;
        
        final currentDate = resp.headers['x-current-date'] ?? resp.headers['X-Current-Date'] ?? '';
        
        final uniqueDatesHeader = resp.headers['x-unique-dates'] ?? resp.headers['X-Unique-Dates'];
        List<String> uniqueDates = [];
        if (uniqueDatesHeader != null) {
          try {
            uniqueDates = List<String>.from(jsonDecode(uniqueDatesHeader));
          } catch (_) {}
        }
        
        return PaginatedAppointments(
          appointments: appointments,
          totalPages: totalPages,
          currentPage: currentPage,
          currentDate: currentDate,
          uniqueDates: uniqueDates,
        );
      }
    } catch (_) {}
    return PaginatedAppointments(appointments: [], totalPages: 1, currentPage: 1, currentDate: '', uniqueDates: []);
  }

  Future<Map<String, dynamic>> getLastUpdated() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/appointments/last-updated'), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
    } catch (_) {}
    return {'count': 0, 'max_id': 0};
  }

  Future<List<Appointment>> getAppointmentsByOwner(String username) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/appointments/by-owner/$username'),
        headers: await _getHeaders(),
      ).timeout(ApiConstants.requestTimeout);
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
        headers: await _getHeaders(),
        body: jsonEncode(a.toMap()),
      ).timeout(ApiConstants.requestTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateAppointment(Appointment a) async {
    try {
      final resp = await http.put(
        Uri.parse('$_baseUrl/appointments/${a.id}'),
        headers: await _getHeaders(),
        body: jsonEncode(a.toMap()),
      ).timeout(ApiConstants.requestTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAppointment(String id) async {
    try {
      final resp = await http.delete(Uri.parse('$_baseUrl/appointments/$id'), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getBusySlots(String date) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/appointments/busy-slots?date=$date'),
        headers: await _getHeaders(),
      ).timeout(ApiConstants.requestTimeout);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
    } catch (_) {}
    return {'num_boxes': 2, 'busy_slots': []};
  }

  Future<bool> hasDeletedNotification(String username) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/appointments/deleted-notification/$username'),
        headers: await _getHeaders(),
      ).timeout(ApiConstants.requestTimeout);
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
        headers: await _getHeaders(),
      ).timeout(ApiConstants.requestTimeout);
      return resp.statusCode == 200;
    } catch (_) {}
    return false;
  }

  Future<bool> clearAdminModifiedFlag(String id) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/appointments/$id/clear-admin-flag'),
        headers: await _getHeaders(),
      ).timeout(ApiConstants.requestTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAppointmentSeen(String id) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/appointments/$id/mark-seen'),
        headers: await _getHeaders(),
      ).timeout(ApiConstants.requestTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleAppointmentFavorite(String id) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/appointments/$id/toggle-favorite'),
        headers: await _getHeaders(),
      ).timeout(ApiConstants.requestTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, int>> getAppointmentStats() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/appointments/stats'), headers: await _getHeaders())
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
        headers: await _getHeaders(),
      ).timeout(ApiConstants.requestTimeout);
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
        headers: await _getHeaders(),
        body: jsonEncode({'washerUsername': washerUsername}),
      ).timeout(ApiConstants.requestTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<User>> getWashers() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/auth/washers'), headers: await _getHeaders())
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
      final resp = await http.get(Uri.parse('$_baseUrl/services/'), headers: await _getHeaders())
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
      final resp = await http.get(Uri.parse('$_baseUrl/services/categories'), headers: await _getHeaders())
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
        headers: await _getHeaders(),
        body: jsonEncode(body),
      ).timeout(ApiConstants.requestTimeout);
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
        headers: await _getHeaders(),
        body: jsonEncode(body),
      ).timeout(ApiConstants.requestTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteService(String id) async {
    try {
      final resp = await http.delete(Uri.parse('$_baseUrl/services/$id'), headers: await _getHeaders())
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
        headers: await _getHeaders(),
      ).timeout(ApiConstants.requestTimeout);
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
        headers: await _getHeaders(),
        body: jsonEncode({'username': username, 'serviceId': serviceId}),
      ).timeout(ApiConstants.requestTimeout);
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
        headers: await _getHeaders(),
      ).timeout(ApiConstants.requestTimeout);
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
        headers: await _getHeaders(),
        body: jsonEncode({'username': username, 'serviceId': serviceId}),
      ).timeout(ApiConstants.requestTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Promos ────────────────────────────────────────────────────────────────
  Future<List<Promo>> getPromos() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/services/promos'), headers: await _getHeaders())
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
      final resp = await http.get(Uri.parse('$_baseUrl/wash-types/'), headers: await _getHeaders())
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
        headers: await _getHeaders(),
        body: jsonEncode(wt.toMap()),
      ).timeout(ApiConstants.requestTimeout);
      if (resp.statusCode == 200) {
        return WashType.fromMap(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  // ─── Logs ─────────────────────────────────────────────────────────────────
  Future<List<LogEntry>> getLogs({int limit = 200}) async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/logs/?limit=$limit'), headers: await _getHeaders())
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
        headers: await _getHeaders(),
      ).timeout(ApiConstants.requestTimeout);
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
      ).timeout(ApiConstants.requestTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearLogs() async {
    try {
      final resp = await http.delete(Uri.parse('$_baseUrl/logs/'), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Push Tokens ────────────────────────────────────────────────────────────
  Future<bool> saveFcmToken(String username, String token) async {
    try {
      final url = '$_baseUrl/auth/fcm-token';
      debugPrint('[DEBUG] ApiService: saveFcmToken: calling $url');
      final resp = await http.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode({
          'username': username,
          'token': token,
          'platform': kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios'),
        }),
      ).timeout(ApiConstants.requestTimeout);
      debugPrint('[DEBUG] ApiService: saveFcmToken: status code ${resp.statusCode}, body: ${resp.body}');
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('[DEBUG] ApiService: saveFcmToken: error: $e');
      return false;
    }
  }

  // ─── Notes ────────────────────────────────────────────────────────────────
  Future<List<Note>> getNotes() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/notes/'), headers: await _getHeaders())
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
        headers: await _getHeaders(),
      ).timeout(ApiConstants.requestTimeout);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => Note.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<int> getUnreadNotesCount() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/notes/unread-count'), headers: await _getHeaders())
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
        headers: await _getHeaders(),
        body: jsonEncode({
          'title': title,
          'message': message,
          'category': category,
        }),
      ).timeout(ApiConstants.requestTimeout);
      if (resp.statusCode == 200) {
        return Note.fromMap(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  Future<bool> markNoteRead(int noteId) async {
    try {
      final resp = await http.put(Uri.parse('$_baseUrl/notes/$noteId/read'), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllNotesRead() async {
    try {
      final resp = await http.put(Uri.parse('$_baseUrl/notes/read-all'), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteNote(int noteId) async {
    try {
      final resp = await http.delete(Uri.parse('$_baseUrl/notes/$noteId'), headers: await _getHeaders())
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
      final resp = await http.get(Uri.parse(url), headers: await _getHeaders())
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
      final resp = await http.get(Uri.parse(url), headers: await _getHeaders())
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
      
      final resp = await http.get(Uri.parse(url), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return ConsumablesUsageReport.fromJson(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }
}
