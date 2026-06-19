import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/appointment.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

class AppointmentProvider extends ChangeNotifier {
  final ApiService _api;
  final NotificationService _notificationService;
  StreamSubscription? _updateSubscription;

  AppointmentProvider({
    required ApiService api,
    required NotificationService notificationService,
  })  : _api = api,
        _notificationService = notificationService {
    _updateSubscription = _notificationService.onAppointmentUpdated.listen((_) {
      notifyListeners();
    });
  }

  List<Appointment> _appointmentList = [];
  bool _loading = true;
  String? _errorMessage;
  bool _hasDeletedByAdmin = false;
  String _currentUser = '';

  Map<String, dynamic> _busySlots = {
    'num_boxes': 2,
    'busy_slots': [[], []]
  };

  // Pagination cache
  final Map<int, List<Appointment>> _cacheAppointments = {};
  final Map<int, String> _cacheDates = {};
  final Map<int, int> _cacheTotalPages = {};
  int _currentPage = 1;
  int _totalPages = 1;
  String _currentDate = '';
  List<String> _uniqueDates = [];

  List<Appointment> get appointments => _appointmentList;
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  bool get hasDeletedByAdmin => _hasDeletedByAdmin;
  Map<String, dynamic> get busySlots => _busySlots;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  String get currentDate => _currentDate;
  List<String> get uniqueDates => _uniqueDates;

  List<Appointment> get favoriteAppointments =>
      _appointmentList.where((a) => a.isFavorite).toList();

  void clearError() => _errorMessage = null;

  /// Apply a single appointment update received via WebSocket.
  /// For admin we do a full reload because of pagination cache.
  Future<void> applyWebSocketAppointment(
    Map<String, dynamic> map,
    String event,
    AuthProvider auth,
  ) async {
    try {
      final appointment = Appointment.fromMap(map);

      if (event == 'deleted') {
        _appointmentList.removeWhere((a) => a.id == appointment.id);
        notifyListeners();
        return;
      }

      final idx = _appointmentList.indexWhere((a) => a.id == appointment.id);
      if (idx != -1) {
        _appointmentList[idx] = appointment;
        notifyListeners();
      } else if (auth.isAdmin) {
        await reloadAppointments(auth);
      } else {
        _appointmentList.insert(0, appointment);
        notifyListeners();
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('applyWebSocketAppointment error: $e\n$st');
      NotificationService().emitAppointmentUpdated(
        map['id']?.toString() ?? '',
      );
    }
  }

  void clearCache() {
    _cacheAppointments.clear();
    _cacheDates.clear();
    _cacheTotalPages.clear();
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }

  Future<List<Appointment>> _fetchAppointments(AuthProvider auth,
      {String? targetDate, int? page}) async {
    if (auth.isAdmin) {
      final targetPage = page ?? _currentPage;
      final res =
          await _api.getAppointments(page: targetPage, date: targetDate);
      _totalPages = res.totalPages;
      _currentPage = res.currentPage;
      _currentDate = res.currentDate;
      _uniqueDates = res.uniqueDates;

      _cacheAppointments[_currentPage] = res.appointments;
      _cacheDates[_currentPage] = res.currentDate;
      _cacheTotalPages[_currentPage] = res.totalPages;

      return res.appointments;
    }
    if (auth.isWasher) return _api.getAppointmentsByWasher(auth.userLogin);
    return _api.getAppointmentsByOwner(auth.userLogin);
  }

  Future<void> _prefetchAdjacent(AuthProvider auth) async {
    if (!auth.isAdmin) return;

    final current = _currentPage;
    final next = current + 1;
    final prev = current - 1;

    final futures = <Future<void>>[];

    if (next <= _totalPages && !_cacheAppointments.containsKey(next)) {
      futures.add(_api.getAppointments(page: next).then((res) {
        _cacheAppointments[next] = res.appointments;
        _cacheDates[next] = res.currentDate;
        _cacheTotalPages[next] = res.totalPages;
      }).catchError((_) {}));
    }

    if (prev >= 1 && !_cacheAppointments.containsKey(prev)) {
      futures.add(_api.getAppointments(page: prev).then((res) {
        _cacheAppointments[prev] = res.appointments;
        _cacheDates[prev] = res.currentDate;
        _cacheTotalPages[prev] = res.totalPages;
      }).catchError((_) {}));
    }

    if (futures.isNotEmpty) await Future.wait(futures);
  }

  Future<void> setPage(int page, AuthProvider auth) async {
    if (!auth.isAdmin) return;
    if (page < 1 || page > _totalPages) return;

    _currentPage = page;
    clearError();

    if (_cacheAppointments.containsKey(page)) {
      _appointmentList = _cacheAppointments[page]!;
      _currentDate = _cacheDates[page]!;
      _totalPages = _cacheTotalPages[page]!;
      notifyListeners();

      _prefetchAdjacent(auth);

      try {
        final freshList = await _fetchAppointments(auth);
        _appointmentList = freshList;
        notifyListeners();
      } catch (e) {
        _errorMessage = 'Ошибка загрузки записей';
        notifyListeners();
      }
    } else {
      try {
        _appointmentList = await _fetchAppointments(auth);
        notifyListeners();
        _prefetchAdjacent(auth);
      } catch (e) {
        _errorMessage = 'Ошибка загрузки записей';
        notifyListeners();
      }
    }
  }

  Future<void> setDate(String date, AuthProvider auth) async {
    if (!auth.isAdmin) return;
    clearCache();
    _appointmentList = await _fetchAppointments(auth, targetDate: date);
    notifyListeners();
    _prefetchAdjacent(auth);
  }

  Future<void> init(AuthProvider auth) async {
    _loading = true;
    clearError();
    notifyListeners();
    clearCache();
    try {
      _appointmentList = await _fetchAppointments(auth, page: 1);
      if (auth.isAdmin && _totalPages > 1) {
        _currentPage = _totalPages;
        _appointmentList = await _fetchAppointments(auth);
      }
    } catch (e) {
      _errorMessage = 'Ошибка загрузки записей';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> reloadAppointments(AuthProvider auth) async {
    clearError();
    try {
      clearCache();
      _appointmentList = await _fetchAppointments(auth);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Ошибка обновления записей';
      notifyListeners();
    }
  }

  Future<void> reloadForUser(String username, AuthProvider auth) async {
    clearError();
    _currentUser = username.toLowerCase();
    clearCache();
    try {
      _appointmentList = await _fetchAppointments(auth);
      _hasDeletedByAdmin = await _api.hasDeletedNotification(_currentUser);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Ошибка загрузки данных пользователя';
      notifyListeners();
    }
  }

  Future<void> clearData() async {
    _appointmentList = [];
    _currentUser = '';
    _hasDeletedByAdmin = false;
    _currentPage = 1;
    _totalPages = 1;
    _currentDate = '';
    _uniqueDates = [];
    clearCache();
    notifyListeners();
  }

  Future<bool> addAppointment(Appointment a, AuthProvider auth) async {
    clearError();
    try {
      final success = await _api.createAppointment(a);
      if (success) await reloadAppointments(auth);
      return success;
    } catch (e) {
      _errorMessage = 'Ошибка создания записи';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAppointment(Appointment a, AuthProvider auth) async {
    clearError();
    try {
      final success = await _api.updateAppointment(a);
      if (success) {
        final i = _appointmentList.indexWhere((x) => x.id == a.id);
        if (i != -1) {
          _appointmentList[i] = a;
          notifyListeners();
        }
        await reloadAppointments(auth);
      }
      return success;
    } catch (e) {
      _errorMessage = 'Ошибка обновления записи';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelAppointment(String id, AuthProvider auth) async {
    final i = _appointmentList.indexWhere((a) => a.id == id);
    if (i == -1) return false;
    final a = _appointmentList[i];
    return updateAppointment(a.copyWith(status: 'cancelled'), auth);
  }

  Future<bool> reportLate(String id, int minutes, AuthProvider auth) async {
    clearError();
    try {
      final success = await _api.reportLate(id, minutes);
      if (success) {
        final i = _appointmentList.indexWhere((a) => a.id == id);
        if (i != -1) {
          _appointmentList[i] =
              _appointmentList[i].copyWith(lateMinutes: minutes);
          notifyListeners();
        }
        await reloadAppointments(auth);
      }
      return success;
    } catch (e) {
      _errorMessage = 'Ошибка при отправке опоздания';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelWithReason(
      String id, String reason, AuthProvider auth) async {
    clearError();
    try {
      final success = await _api.cancelWithReason(id, reason);
      if (success) {
        final i = _appointmentList.indexWhere((a) => a.id == id);
        if (i != -1) {
          _appointmentList[i] = _appointmentList[i].copyWith(
            status: 'cancelled',
            cancelReason: reason,
          );
          notifyListeners();
        }
        await reloadAppointments(auth);
      }
      return success;
    } catch (e) {
      _errorMessage = 'Ошибка при отмене записи';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAppointment(String id, AuthProvider auth) async {
    clearError();
    try {
      final ok = await _api.deleteAppointment(id);
      if (ok) {
        _appointmentList.removeWhere((a) => a.id == id);
        notifyListeners();
        await reloadAppointments(auth);
      }
      return ok;
    } catch (e) {
      _errorMessage = 'Ошибка удаления записи';
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleAppointmentFavorite(String id) async {
    clearError();
    try {
      final ok = await _api.toggleAppointmentFavorite(id);
      if (ok) {
        final i = _appointmentList.indexWhere((a) => a.id == id);
        if (i != -1) {
          _appointmentList[i] = _appointmentList[i]
              .copyWith(isFavorite: !_appointmentList[i].isFavorite);
          notifyListeners();
        }
      }
    } catch (e) {}
  }

  Future<void> fetchBusySlots(String date) async {
    _busySlots = await _api.getBusySlots(date);
    notifyListeners();
  }

  Future<List<User>> getWashers() => _api.getWashers();

  Future<List<Appointment>> getAppointmentsByWasher(String username) =>
      _api.getAppointmentsByWasher(username);

  Future<bool> assignWasher(String appointmentId, String washerUsername) async {
    final ok = await _api.assignWasher(appointmentId, washerUsername);
    if (ok) {
      final i = _appointmentList.indexWhere((a) => a.id == appointmentId);
      if (i != -1) {
        final current = List<String>.from(_appointmentList[i].assignedWashers);
        if (current.contains(washerUsername)) {
          current.remove(washerUsername);
        } else {
          current.add(washerUsername);
        }
        _appointmentList[i] =
            _appointmentList[i].copyWith(assignedWashers: current);
        notifyListeners();
      }
    }
    return ok;
  }

  Future<void> clearDeletedByAdminFlag() async {
    try {
      await _api.clearDeletedNotification(_currentUser);
      _hasDeletedByAdmin = false;
      notifyListeners();
    } catch (e) {}
  }

  Future<void> clearModifiedFlag(String id) async {
    try {
      final ok = await _api.clearAdminModifiedFlag(id);
      if (ok) {
        final i = _appointmentList.indexWhere((a) => a.id == id);
        if (i != -1) {
          _appointmentList[i] = _appointmentList[i]
              .copyWith(isModifiedByAdmin: false, isModifiedByWasher: false);
          notifyListeners();
        }
      }
    } catch (e) {}
  }

  Future<void> markAsSeen(String id) async {
    final i = _appointmentList.indexWhere((a) => a.id == id);
    if (i != -1 && !_appointmentList[i].isSeenByClient) {
      try {
        final ok = await _api.markAppointmentSeen(id);
        if (ok) {
          _appointmentList[i] =
              _appointmentList[i].copyWith(isSeenByClient: true);
          notifyListeners();
        }
      } catch (e) {}
    }
  }
}
