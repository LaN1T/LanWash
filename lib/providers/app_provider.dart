import 'dart:async';
import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../models/service.dart';
import '../models/promo.dart';
import '../models/note.dart';
import '../models/user.dart';
import '../models/wash_type.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

class AppProvider extends ChangeNotifier {
  final _api = ApiService();
  final _notificationService = NotificationService();
  StreamSubscription? _updateSubscription;

  AppProvider() {
    _updateSubscription = _notificationService.onAppointmentUpdated.listen((_) {
      _refreshAllData();
    });
  }

  Future<void> _refreshAllData() async {
    notifyListeners();
  }

  List<Appointment> _appointmentList = [];
  List<Service>     _serviceList     = [];
  List<Promo>       _promoList       = [];
  List<WashType>    _washTypeList    = [];
  List<Note>        _noteList        = [];
  Set<String>       _extraFavSet     = {};
  Set<String>       _serviceFavSet   = {};
  String            _currentUser     = '';
  bool _loading    = true;
  bool _hasDeletedByAdmin = false;
  final bool _loadingApi = false;
  int  _unreadNotes = 0;
  int  _currentPage = 1;
  int  _totalPages = 1;
  String _currentDate = '';
  List<String> _uniqueDates = [];
  String? _errorMessage;
  
  final Map<int, List<Appointment>> _cacheAppointments = {};
  final Map<int, String> _cacheDates = {};
  final Map<int, int> _cacheTotalPages = {};

  int               get currentPage    => _currentPage;
  int               get totalPages     => _totalPages;
  String            get currentDate    => _currentDate;
  List<String>      get uniqueDates    => _uniqueDates;
  List<Appointment> get appointments   => _appointmentList;
  List<Service>     get services       => _serviceList;
  List<Promo>       get promos         => _promoList;
  List<WashType>    get washTypes      => _washTypeList;
  List<Note>        get notes          => _noteList;
  Set<String>       get extraFavorites => _extraFavSet;
  bool              get loading        => _loading;
  bool              get loadingApi     => _loadingApi;
  int               get unreadNotes    => _unreadNotes;
  bool              get hasDeletedByAdmin => _hasDeletedByAdmin;
  String?           get errorMessage   => _errorMessage;

  void clearError() {
    _errorMessage = null;
  }

  Map<String, dynamic> _busySlots = {'num_boxes': 2, 'busy_slots': [[], []]};
  Map<String, dynamic> get busySlots => _busySlots;

  List<Appointment> get favoriteAppointments => _appointmentList.where((a) => a.isFavorite).toList();
  List<Service> get favoriteServices => _serviceList.where((s) => _serviceFavSet.contains(s.id)).toList();
  bool isServiceFavorite(String id) => _serviceFavSet.contains(id);
  bool isExtraFavorite(String serviceId) => _extraFavSet.contains(serviceId);

  WashType? washTypeById(String id) {
    final results = _washTypeList.where((w) => w.id == id);
    return results.isNotEmpty ? results.first : null;
  }
  WashType? washTypeByCode(String code) {
    final results = _washTypeList.where((w) => w.code == code);
    return results.isNotEmpty ? results.first : null;
  }
  String washTypeName(String id) => washTypeById(id)?.name ?? id;
  Promo? promoById(String id) {
    final results = _promoList.where((p) => p.id == id);
    return results.isNotEmpty ? results.first : null;
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }

  void clearCache() {
    _cacheAppointments.clear();
    _cacheDates.clear();
    _cacheTotalPages.clear();
  }

  Future<List<Appointment>> _fetchAppointments(AuthProvider auth, {String? targetDate}) async {
    if (auth.isAdmin) {
      final res = await _api.getAppointments(page: _currentPage, date: targetDate);
      _totalPages = res.totalPages;
      _currentPage = res.currentPage;
      _currentDate = res.currentDate;
      _uniqueDates = res.uniqueDates;
      
      // Update cache
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
    
    if (next <= _totalPages && !_cacheAppointments.containsKey(next)) {
      try {
        final res = await _api.getAppointments(page: next);
        _cacheAppointments[next] = res.appointments;
        _cacheDates[next] = res.currentDate;
        _cacheTotalPages[next] = res.totalPages;
      } catch (e, st) {
        debugPrint('[AppProvider._prefetchAdjacent next] error: $e\n$st');
      }
    }
    
    if (prev >= 1 && !_cacheAppointments.containsKey(prev)) {
      try {
        final res = await _api.getAppointments(page: prev);
        _cacheAppointments[prev] = res.appointments;
        _cacheDates[prev] = res.currentDate;
        _cacheTotalPages[prev] = res.totalPages;
      } catch (e, st) {
        debugPrint('[AppProvider._prefetchAdjacent prev] error: $e\n$st');
      }
    }
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
      } catch (e, st) {
        debugPrint('[AppProvider.setPage] error: $e\n$st');
        _errorMessage = 'Ошибка загрузки записей';
        notifyListeners();
      }
    } else {
      try {
        _appointmentList = await _fetchAppointments(auth);
        notifyListeners();
        _prefetchAdjacent(auth);
      } catch (e, st) {
        debugPrint('[AppProvider.setPage] error: $e\n$st');
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
      _serviceList  = await _api.getServices();
      _promoList    = await _api.getPromos();
      _washTypeList = await _api.getWashTypes();
      _appointmentList = await _fetchAppointments(auth);
    } catch (e, st) {
      debugPrint('[AppProvider.init] error: $e\n$st');
      _errorMessage = 'Ошибка загрузки данных. Проверьте подключение.';
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
    } catch (e, st) {
      debugPrint('[AppProvider.reloadAppointments] error: $e\n$st');
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
      _extraFavSet     = await _api.getExtraFavorites(_currentUser);
      _serviceFavSet   = await _api.getServiceFavorites(_currentUser);
      _hasDeletedByAdmin = await _api.hasDeletedNotification(_currentUser);
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AppProvider.reloadForUser] error: $e\n$st');
      _errorMessage = 'Ошибка загрузки данных пользователя';
      notifyListeners();
    }
  }

  Future<void> clearData() async {
    _appointmentList = []; _noteList = []; _extraFavSet = {}; _serviceFavSet = {};
    _currentUser = ''; _unreadNotes = 0; _hasDeletedByAdmin = false;
    notifyListeners();
  }

  Future<bool> addAppointment(Appointment a, AuthProvider auth) async {
    clearError();
    try {
      final success = await _api.createAppointment(a);
      if (success) await reloadAppointments(auth);
      return success;
    } catch (e, st) {
      debugPrint('[AppProvider.addAppointment] error: $e\n$st');
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
    } catch (e, st) {
      debugPrint('[AppProvider.updateAppointment] error: $e\n$st');
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
    } catch (e, st) {
      debugPrint('[AppProvider.deleteAppointment] error: $e\n$st');
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
          _appointmentList[i] = _appointmentList[i].copyWith(isFavorite: !_appointmentList[i].isFavorite);
          notifyListeners();
        }
      }
    } catch (e, st) {
      debugPrint('[AppProvider.toggleAppointmentFavorite] error: $e\n$st');
    }
  }

  Future<void> addService(Service s) async {
    clearError();
    try {
      await _api.createService(s);
      _serviceList = await _api.getServices();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AppProvider.addService] error: $e\n$st');
      _errorMessage = 'Ошибка добавления услуги';
      notifyListeners();
    }
  }

  Future<void> updateService(Service s) async {
    clearError();
    try {
      await _api.updateService(s);
      final i = _serviceList.indexWhere((x) => x.id == s.id);
      if (i != -1) _serviceList[i] = s;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AppProvider.updateService] error: $e\n$st');
      _errorMessage = 'Ошибка обновления услуги';
      notifyListeners();
    }
  }

  Future<void> deleteService(String id) async {
    clearError();
    try {
      await _api.deleteService(id);
      _serviceList.removeWhere((s) => s.id == id);
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AppProvider.deleteService] error: $e\n$st');
      _errorMessage = 'Ошибка удаления услуги';
      notifyListeners();
    }
  }

  Future<void> toggleServiceFavorite(String id) async {
    clearError();
    final user = _currentUser.isNotEmpty ? _currentUser : 'admin';
    try {
      final ok = await _api.toggleServiceFavorite(user, id);
      if (ok) {
        if (_serviceFavSet.contains(id)) {
          _serviceFavSet.remove(id);
        } else {
          _serviceFavSet.add(id);
        }
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('[AppProvider.toggleServiceFavorite] error: $e\n$st');
    }
  }

  Future<void> toggleExtraFavorite(String serviceId) async {
    clearError();
    final user = _currentUser.isNotEmpty ? _currentUser : 'admin';
    try {
      final ok = await _api.toggleExtraFavorite(user, serviceId);
      if (ok) {
        if (_extraFavSet.contains(serviceId)) {
          _extraFavSet.remove(serviceId);
        } else {
          _extraFavSet.add(serviceId);
        }
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('[AppProvider.toggleExtraFavorite] error: $e\n$st');
    }
  }

  Future<List<String>> getServiceCategories() => _api.getServiceCategories();

  Future<void> reloadWashTypes() async {
    _washTypeList = await _api.getWashTypes();
    notifyListeners();
  }

  Future<void> fetchBusySlots(String date) async {
    _busySlots = await _api.getBusySlots(date);
    notifyListeners();
  }

  Future<bool> updateWashType(WashType wt) async {
    final updated = await _api.updateWashType(wt);
    if (updated != null) {
      final i = _washTypeList.indexWhere((x) => x.id == updated.id);
      if (i != -1) {
        _washTypeList[i] = updated;
      } else {
        _washTypeList.add(updated);
      }
      _washTypeList.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<List<User>> getWashers() => _api.getWashers();
  Future<List<Appointment>> getAppointmentsByWasher(String username) => _api.getAppointmentsByWasher(username);

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
            _appointmentList[i] = _appointmentList[i].copyWith(assignedWashers: current);
            notifyListeners();
        }
    }
    return ok;
  }

  Future<void> loadNotes({String? username}) async {
    clearError();
    try {
      _noteList = username != null ? await _api.getNotesByUser(username) : await _api.getNotes();
      _unreadNotes = _noteList.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AppProvider.loadNotes] error: $e\n$st');
      _errorMessage = 'Ошибка загрузки заметок';
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount(AuthProvider auth) async {
    if (!auth.isAdmin) return;
    try {
      _unreadNotes = await _api.getUnreadNotesCount();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AppProvider.refreshUnreadCount] error: $e\n$st');
    }
  }

  Future<Note?> addNote(String username, String title, String message, String category) async {
    clearError();
    try {
      final note = await _api.createNote(username, title, message, category);
      if (note != null) {
        _noteList.insert(0, note);
        _unreadNotes = _noteList.where((n) => !n.isRead).length;
        notifyListeners();
      }
      return note;
    } catch (e, st) {
      debugPrint('[AppProvider.addNote] error: $e\n$st');
      _errorMessage = 'Ошибка создания заметки';
      notifyListeners();
      return null;
    }
  }

  Future<void> markNoteRead(int noteId) async {
    try {
      final ok = await _api.markNoteRead(noteId);
      if (ok) {
        final i = _noteList.indexWhere((n) => n.id == noteId);
        if (i != -1) {
          _noteList[i] = _noteList[i].copyWith(isRead: true);
          _unreadNotes = _noteList.where((n) => !n.isRead).length;
          notifyListeners();
        }
      }
    } catch (e, st) {
      debugPrint('[AppProvider.markNoteRead] error: $e\n$st');
    }
  }

  Future<void> markAllNotesRead() async {
    try {
      final ok = await _api.markAllNotesRead();
      if (ok) {
        _noteList = _noteList.map((n) => n.copyWith(isRead: true)).toList();
        _unreadNotes = 0;
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('[AppProvider.markAllNotesRead] error: $e\n$st');
    }
  }

  Future<void> deleteNote(int noteId) async {
    try {
      final ok = await _api.deleteNote(noteId);
      if (ok) {
        _noteList.removeWhere((n) => n.id == noteId);
        _unreadNotes = _noteList.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('[AppProvider.deleteNote] error: $e\n$st');
    }
  }
  
  Future<void> clearDeletedByAdminFlag() async {
    try {
      await _api.clearDeletedNotification(_currentUser);
      _hasDeletedByAdmin = false;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AppProvider.clearDeletedByAdminFlag] error: $e\n$st');
    }
  }
  
  Future<void> clearModifiedFlag(String id) async {
    try {
      final ok = await _api.clearAdminModifiedFlag(id);
      if (ok) {
        final i = _appointmentList.indexWhere((a) => a.id == id);
        if (i != -1) { 
          _appointmentList[i] = _appointmentList[i].copyWith(isModifiedByAdmin: false, isModifiedByWasher: false); 
          notifyListeners(); 
        }
      }
    } catch (e, st) {
      debugPrint('[AppProvider.clearModifiedFlag] error: $e\n$st');
    }
  }

  Future<void> markAsSeen(String id) async {
    final i = _appointmentList.indexWhere((a) => a.id == id);
    if (i != -1 && !_appointmentList[i].isSeenByClient) {
      try {
        final ok = await _api.markAppointmentSeen(id);
        if (ok) {
          _appointmentList[i] = _appointmentList[i].copyWith(isSeenByClient: true);
          notifyListeners();
        }
      } catch (e, st) {
        debugPrint('[AppProvider.markAsSeen] error: $e\n$st');
      }
    }
  }
}
