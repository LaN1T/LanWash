import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
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
  // Token management делегируется ApiClient (единая точка правды)
  static Future<String?> getToken() => ApiClient.getToken();
  static Future<void> setToken(String token) => ApiClient.setToken(token);
  static Future<void> deleteToken() => ApiClient.deleteToken();

  // ─── Auth ───────────────────────────────────────────────────────────────────
  Future<User?> login(String username, String password) async {
    final result = await ApiClient.post('/auth/login', body: {
      'username': username,
      'password': password,
    });
    return result.when(
      success: (data) async {
        await setToken(data['access_token']);
        return User.fromMap(data['user']);
      },
      failure: (err) {
        debugPrint('[ApiService.login] error: ${err.message}');
        return null;
      },
    );
  }

  Future<Map<String, dynamic>?> register({
    required String username,
    required String password,
    required String displayName,
    String phone = '',
    String carModel = '',
    String carNumber = '',
  }) async {
    final result = await ApiClient.post('/auth/register', body: {
      'username': username,
      'password': password,
      'displayName': displayName,
      'phone': phone,
      'carModel': carModel,
      'carNumber': carNumber,
    });
    return result.when(
      success: (data) async {
        await setToken(data['access_token']);
        return {'user': data['user']};
      },
      failure: (err) {
        debugPrint('[ApiService.register] error: ${err.message}');
        if (err.statusCode != null &&
            err.statusCode! >= 400 &&
            err.statusCode! < 500) {
          return {'error': err.message};
        }
        return {'error': 'Нет связи с сервером'};
      },
    );
  }

  Future<User?> updateProfile(
    int userId, {
    String? displayName,
    String? phone,
    String? carModel,
    String? carNumber,
    String? newPassword,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (phone != null) body['phone'] = phone;
    if (carModel != null) body['carModel'] = carModel;
    if (carNumber != null) body['carNumber'] = carNumber;
    if (newPassword != null) body['newPassword'] = newPassword;

    final result = await ApiClient.put('/auth/profile/$userId', body: body);
    return result.when(
      success: (data) => User.fromMap(data),
      failure: (err) {
        debugPrint('[ApiService.updateProfile] error: ${err.message}');
        return null;
      },
    );
  }

  // ─── Appointments ───────────────────────────────────────────────────────────
  Future<PaginatedAppointments> getAppointments(
      {int? page, String? date}) async {
    final queryParams = <String>[];
    if (page != null) queryParams.add('page=$page');
    if (date != null) queryParams.add('date=$date');
    final queryString =
        queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

    final result = await ApiClient.rawGet('/appointments/$queryString');
    return result.when(
      success: (resp) {
        final list = jsonDecode(resp.body) as List;
        final appointments = list.map((m) => Appointment.fromMap(m)).toList();

        final totalPagesHeader =
            resp.headers['x-total-pages'] ?? resp.headers['X-Total-Pages'];
        final totalPages =
            totalPagesHeader != null ? int.tryParse(totalPagesHeader) ?? 1 : 1;

        final currentPageHeader =
            resp.headers['x-current-page'] ?? resp.headers['X-Current-Page'];
        final currentPage = currentPageHeader != null
            ? int.tryParse(currentPageHeader) ?? 1
            : 1;

        final currentDate = resp.headers['x-current-date'] ??
            resp.headers['X-Current-Date'] ??
            '';

        final uniqueDatesHeader =
            resp.headers['x-unique-dates'] ?? resp.headers['X-Unique-Dates'];
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
      },
      failure: (err) {
        debugPrint('[ApiService.getAppointments] error: ${err.message}');
        return PaginatedAppointments(
            appointments: [],
            totalPages: 1,
            currentPage: 1,
            currentDate: '',
            uniqueDates: []);
      },
    );
  }

  Future<Map<String, dynamic>> getLastUpdated() async {
    final result = await ApiClient.get('/appointments/last-updated');
    return result.when(
      success: (data) => data,
      failure: (err) {
        debugPrint('[ApiService.getLastUpdated] error: ${err.message}');
        return {'count': 0, 'max_id': 0};
      },
    );
  }

  Future<List<Appointment>> getAppointmentsByOwner(String username) async {
    final result = await ApiClient.getList('/appointments/by-owner/$username');
    return result.when(
      success: (list) => list.map((m) => Appointment.fromMap(m)).toList(),
      failure: (err) {
        debugPrint('[ApiService.getAppointmentsByOwner] error: ${err.message}');
        return [];
      },
    );
  }

  Future<bool> createAppointment(Appointment a) async {
    final result = await ApiClient.post('/appointments/', body: a.toMap());
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.createAppointment] error: ${err.message}');
        return false;
      },
    );
  }

  Future<bool> updateAppointment(Appointment a) async {
    final result =
        await ApiClient.put('/appointments/${a.id}', body: a.toMap());
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.updateAppointment] error: ${err.message}');
        return false;
      },
    );
  }

  Future<bool> deleteAppointment(String id) async {
    final result = await ApiClient.delete('/appointments/$id');
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.deleteAppointment] error: ${err.message}');
        return false;
      },
    );
  }

  Future<Map<String, dynamic>> getBusySlots(String date) async {
    final result = await ApiClient.get('/appointments/busy-slots?date=$date');
    return result.when(
      success: (data) => data,
      failure: (err) {
        debugPrint('[ApiService.getBusySlots] error: ${err.message}');
        return {'num_boxes': 2, 'busy_slots': []};
      },
    );
  }

  Future<bool> hasDeletedNotification(String username) async {
    final result =
        await ApiClient.get('/appointments/deleted-notification/$username');
    return result.when(
      success: (data) => data['hasNotification'] == true,
      failure: (err) {
        debugPrint('[ApiService.hasDeletedNotification] error: ${err.message}');
        return false;
      },
    );
  }

  Future<bool> clearDeletedNotification(String username) async {
    final result =
        await ApiClient.delete('/appointments/deleted-notification/$username');
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint(
            '[ApiService.clearDeletedNotification] error: ${err.message}');
        return false;
      },
    );
  }

  Future<bool> clearAdminModifiedFlag(String id) async {
    final result = await ApiClient.post('/appointments/$id/clear-admin-flag');
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.clearAdminModifiedFlag] error: ${err.message}');
        return false;
      },
    );
  }

  Future<bool> markAppointmentSeen(String id) async {
    final result = await ApiClient.post('/appointments/$id/mark-seen');
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.markAppointmentSeen] error: ${err.message}');
        return false;
      },
    );
  }

  Future<bool> toggleAppointmentFavorite(String id) async {
    final result = await ApiClient.post('/appointments/$id/toggle-favorite');
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint(
            '[ApiService.toggleAppointmentFavorite] error: ${err.message}');
        return false;
      },
    );
  }

  Future<Map<String, int>> getAppointmentStats() async {
    final result = await ApiClient.get('/appointments/stats');
    return result.when(
      success: (m) => {
        'total': (m['total'] ?? 0) as int,
        'scheduled': (m['scheduled'] ?? 0) as int,
        'completed': (m['completed'] ?? 0) as int,
      },
      failure: (err) {
        debugPrint('[ApiService.getAppointmentStats] error: ${err.message}');
        return {'total': 0, 'scheduled': 0, 'completed': 0};
      },
    );
  }

  Future<List<Appointment>> getAppointmentsByWasher(String username) async {
    final result = await ApiClient.getList('/appointments/by-washer/$username');
    return result.when(
      success: (list) => list.map((m) => Appointment.fromMap(m)).toList(),
      failure: (err) {
        debugPrint(
            '[ApiService.getAppointmentsByWasher] error: ${err.message}');
        return [];
      },
    );
  }

  Future<bool> assignWasher(String appointmentId, String washerUsername) async {
    final result = await ApiClient.post(
        '/appointments/$appointmentId/assign-washer',
        body: {'washerUsername': washerUsername});
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.assignWasher] error: ${err.message}');
        return false;
      },
    );
  }

  Future<List<User>> getWashers() async {
    final result = await ApiClient.getList('/auth/washers');
    return result.when(
      success: (list) => list.map((m) => User.fromMap(m)).toList(),
      failure: (err) {
        debugPrint('[ApiService.getWashers] error: ${err.message}');
        return [];
      },
    );
  }

  // ─── Services ───────────────────────────────────────────────────────────────
  Future<List<Service>> getServices() async {
    final result = await ApiClient.getList('/services/');
    return result.when(
      success: (list) => list.map((m) => Service.fromMap(m)).toList(),
      failure: (err) {
        debugPrint('[ApiService.getServices] error: ${err.message}');
        return [];
      },
    );
  }

  Future<List<String>> getServiceCategories() async {
    final result = await ApiClient.getList('/services/categories');
    return result.when(
      success: (list) => list.cast<String>(),
      failure: (err) {
        debugPrint('[ApiService.getServiceCategories] error: ${err.message}');
        return [];
      },
    );
  }

  Future<bool> createService(Service s) async {
    final body = s.toMap();
    body['updatedAt'] = DateTime.now().toIso8601String();
    final result = await ApiClient.post('/services/', body: body);
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.createService] error: ${err.message}');
        return false;
      },
    );
  }

  Future<bool> updateService(Service s) async {
    final body = s.toMap();
    body['updatedAt'] = DateTime.now().toIso8601String();
    final result = await ApiClient.put('/services/${s.id}', body: body);
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.updateService] error: ${err.message}');
        return false;
      },
    );
  }

  Future<bool> deleteService(String id) async {
    final result = await ApiClient.delete('/services/$id');
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.deleteService] error: ${err.message}');
        return false;
      },
    );
  }

  // ─── Service Favorites ────────────────────────────────────────────────────
  Future<Set<String>> getServiceFavorites(String username) async {
    final result = await ApiClient.getList('/services/favorites/$username');
    return result.when(
      success: (list) => list.cast<String>().toSet(),
      failure: (err) {
        debugPrint('[ApiService.getServiceFavorites] error: ${err.message}');
        return {};
      },
    );
  }

  Future<bool> toggleServiceFavorite(String username, String serviceId) async {
    final result = await ApiClient.post('/services/favorites/toggle',
        body: {'username': username, 'serviceId': serviceId});
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.toggleServiceFavorite] error: ${err.message}');
        return false;
      },
    );
  }

  // ─── Extra Favorites ──────────────────────────────────────────────────────
  Future<Set<String>> getExtraFavorites(String username) async {
    final result =
        await ApiClient.getList('/services/extra-favorites/$username');
    return result.when(
      success: (list) => list.cast<String>().toSet(),
      failure: (err) {
        debugPrint('[ApiService.getExtraFavorites] error: ${err.message}');
        return {};
      },
    );
  }

  Future<bool> toggleExtraFavorite(String username, String serviceId) async {
    final result = await ApiClient.post('/services/extra-favorites/toggle',
        body: {'username': username, 'serviceId': serviceId});
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.toggleExtraFavorite] error: ${err.message}');
        return false;
      },
    );
  }

  // ─── Promos ────────────────────────────────────────────────────────────────
  Future<List<Promo>> getPromos() async {
    final result = await ApiClient.getList('/services/promos');
    return result.when(
      success: (list) => list.map((m) => Promo.fromMap(m)).toList(),
      failure: (err) {
        debugPrint('[ApiService.getPromos] error: ${err.message}');
        return [];
      },
    );
  }

  // ─── Wash Types ────────────────────────────────────────────────────────────
  Future<List<WashType>> getWashTypes() async {
    final result = await ApiClient.getList('/wash-types/');
    return result.when(
      success: (list) => list.map((m) => WashType.fromMap(m)).toList(),
      failure: (err) {
        debugPrint('[ApiService.getWashTypes] error: ${err.message}');
        return [];
      },
    );
  }

  Future<WashType?> updateWashType(WashType wt) async {
    final result =
        await ApiClient.put('/wash-types/${wt.id}', body: wt.toMap());
    return result.when(
      success: (data) => WashType.fromMap(data),
      failure: (err) {
        debugPrint('[ApiService.updateWashType] error: ${err.message}');
        return null;
      },
    );
  }

  // ─── Logs ─────────────────────────────────────────────────────────────────
  Future<List<LogEntry>> getLogs({int limit = 200}) async {
    final result = await ApiClient.getList('/logs/?limit=$limit');
    return result.when(
      success: (list) => list.map((m) => LogEntry.fromMap(m)).toList(),
      failure: (err) {
        debugPrint('[ApiService.getLogs] error: ${err.message}');
        return [];
      },
    );
  }

  Future<List<LogEntry>> getLogsByUser(String username) async {
    final result = await ApiClient.getList('/logs/by-user/$username');
    return result.when(
      success: (list) => list.map((m) => LogEntry.fromMap(m)).toList(),
      failure: (err) {
        debugPrint('[ApiService.getLogsByUser] error: ${err.message}');
        return [];
      },
    );
  }

  Future<bool> createLog(String username, String action, String details) async {
    final result = await ApiClient.post('/logs/', body: {
      'username': username,
      'action': action,
      'details': details,
    });
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.createLog] error: ${err.message}');
        return false;
      },
    );
  }

  Future<bool> clearLogs() async {
    final result = await ApiClient.delete('/logs/');
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.clearLogs] error: ${err.message}');
        return false;
      },
    );
  }

  // ─── Push Tokens ────────────────────────────────────────────────────────────
  Future<bool> saveFcmToken(String username, String token) async {
    final result = await ApiClient.post('/auth/fcm-token', body: {
      'username': username,
      'token': token,
      'platform': kIsWeb
          ? 'web'
          : (defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'ios'),
    });
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.saveFcmToken] error: ${err.message}');
        return false;
      },
    );
  }

  // ─── Notes ────────────────────────────────────────────────────────────────
  Future<List<Note>> getNotes() async {
    final result = await ApiClient.getList('/notes/');
    return result.when(
      success: (list) => list.map((m) => Note.fromMap(m)).toList(),
      failure: (err) {
        debugPrint('[ApiService.getNotes] error: ${err.message}');
        return [];
      },
    );
  }

  Future<List<Note>> getNotesByUser(String username) async {
    final result = await ApiClient.getList('/notes/by-user/$username');
    return result.when(
      success: (list) => list.map((m) => Note.fromMap(m)).toList(),
      failure: (err) {
        debugPrint('[ApiService.getNotesByUser] error: ${err.message}');
        return [];
      },
    );
  }

  Future<int> getUnreadNotesCount() async {
    final result = await ApiClient.get('/notes/unread-count');
    return result.when(
      success: (data) => data['count'] ?? 0,
      failure: (err) {
        debugPrint('[ApiService.getUnreadNotesCount] error: ${err.message}');
        return 0;
      },
    );
  }

  Future<Note?> createNote(
      String username, String title, String message, String category) async {
    final result = await ApiClient.post('/notes/?username=$username', body: {
      'title': title,
      'message': message,
      'category': category,
    });
    return result.when(
      success: (data) => Note.fromMap(data),
      failure: (err) {
        debugPrint('[ApiService.createNote] error: ${err.message}');
        return null;
      },
    );
  }

  Future<bool> markNoteRead(int noteId) async {
    final result = await ApiClient.put('/notes/$noteId/read');
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.markNoteRead] error: ${err.message}');
        return false;
      },
    );
  }

  Future<bool> markAllNotesRead() async {
    final result = await ApiClient.put('/notes/read-all');
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.markAllNotesRead] error: ${err.message}');
        return false;
      },
    );
  }

  Future<bool> deleteNote(int noteId) async {
    final result = await ApiClient.delete('/notes/$noteId');
    return result.when(
      success: (_) => true,
      failure: (err) {
        debugPrint('[ApiService.deleteNote] error: ${err.message}');
        return false;
      },
    );
  }

  // ─── Reports ───────────────────────────────────────────────────────────────
  Future<MonthlyReport?> getAverageCheckReport(String? date) async {
    final path = date != null
        ? '/reports/monthly-check-vs-price/?date=$date'
        : '/reports/monthly-check-vs-price/';
    final result = await ApiClient.get(path);
    return result.when(
      success: (data) => MonthlyReport.fromJson(data),
      failure: (err) {
        debugPrint('[ApiService.getAverageCheckReport] error: ${err.message}');
        return null;
      },
    );
  }

  Future<PopularServicesReport?> getPopularAdditionalServices(String? date,
      {String? category}) async {
    var path = date != null
        ? '/reports/popular-additional-services/?date=$date'
        : '/reports/popular-additional-services/';
    if (category != null && category != 'Все') {
      path += '&category=$category';
    }
    final result = await ApiClient.get(path);
    return result.when(
      success: (data) => PopularServicesReport.fromJson(data),
      failure: (err) {
        debugPrint(
            '[ApiService.getPopularAdditionalServices] error: ${err.message}');
        return null;
      },
    );
  }

  Future<ConsumablesUsageReport?> getConsumablesUsageReport(String? date,
      {String? category}) async {
    var path = '/reports/consumables-usage/';
    final params = <String>[];
    if (date != null) params.add('date=$date');
    if (category != null && category != 'Все') params.add('category=$category');
    if (params.isNotEmpty) {
      path += '?${params.join('&')}';
    }
    final result = await ApiClient.get(path);
    return result.when(
      success: (data) => ConsumablesUsageReport.fromJson(data),
      failure: (err) {
        debugPrint(
            '[ApiService.getConsumablesUsageReport] error: ${err.message}');
        return null;
      },
    );
  }
}
