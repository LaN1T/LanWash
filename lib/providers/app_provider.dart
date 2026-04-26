import 'dart:async';
import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../models/service.dart';
import '../models/promo.dart';
import '../models/note.dart';
import '../models/user.dart';
import '../models/wash_type.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class AppProvider extends ChangeNotifier {
  final _api = ApiService();
  Timer? _refreshTimer;

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
  bool _loadingApi = false;
  int  _unreadNotes = 0;

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
    _refreshTimer?.cancel();
    super.dispose();
  }

  void startAutoRefresh(AuthProvider auth) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final userLogin = auth.userLogin;
        if (userLogin.isEmpty) return;

        final newAppointments = await _fetchAppointments(auth);

        if (_hasSignificantChanges(_appointmentList, newAppointments)) {
          _appointmentList = newAppointments;
          notifyListeners();
          debugPrint('[AppProvider] State updated with ${newAppointments.length} items');
        }
        await refreshUnreadCount();
      } catch (e, stack) {
        debugPrint('[AppProvider] Auto-refresh error: $e\n$stack');
      }
    });
  }

  Future<List<Appointment>> _fetchAppointments(AuthProvider auth) {
    if (auth.isAdmin) return _api.getAppointments();
    if (auth.isWasher) return _api.getAppointmentsByWasher(auth.userLogin);
    return _api.getAppointmentsByOwner(auth.userLogin);
  }

  bool _hasSignificantChanges(List<Appointment> oldList, List<Appointment> newList) {
    if (oldList.length != newList.length) return true;

    // Сравниваем по ключевым полям, которые определяют состояние записи.
    // Если объект Appointment не реализует Equatable, сравниваем критические поля вручную.
    for (int i = 0; i < newList.length; i++) {
      final old = oldList.firstWhere((a) => a.id == newList[i].id, orElse: () => Appointment(id: 'none', clientName: '', carModel: '', carNumber: '', dateTime: DateTime.now(), washTypeId: '', additionalServices: [], status: 'scheduled'));
      if (old.id == 'none') return true; // Новая запись
      if (old.status != newList[i].status || old.isFavorite != newList[i].isFavorite) return true;
    }
    return false;
  }

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      _serviceList  = await _api.getServices();
      _promoList    = await _api.getPromos();
      _washTypeList = await _api.getWashTypes();
      _appointmentList = await _api.getAppointments();
    } catch (e) {
      debugPrint('[AppProvider] init error: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> reloadAppointments() async {
    _appointmentList = await _api.getAppointments();
    notifyListeners();
  }

  Future<void> reloadForUser(String username) async {
    _currentUser = username.toLowerCase();
    _appointmentList = await _api.getAppointmentsByOwner(_currentUser);
    _extraFavSet     = await _api.getExtraFavorites(_currentUser);
    _serviceFavSet   = await _api.getServiceFavorites(_currentUser);
    _hasDeletedByAdmin = await _api.hasDeletedNotification(_currentUser);
    notifyListeners();
  }

  Future<void> clearData() async {
    _appointmentList = []; _noteList = []; _extraFavSet = {}; _serviceFavSet = {};
    _currentUser = ''; _unreadNotes = 0; _hasDeletedByAdmin = false;
    notifyListeners();
  }

  Future<void> addAppointment(Appointment a) async {
    await _api.createAppointment(a);
    _appointmentList = await _api.getAppointments();
    notifyListeners();
  }

  Future<void> updateAppointment(Appointment a) async {
    await _api.updateAppointment(a);
    final i = _appointmentList.indexWhere((x) => x.id == a.id);
    if (i != -1) _appointmentList[i] = a;
    notifyListeners();
  }

  Future<void> deleteAppointment(String id) async {
    await _api.deleteAppointment(id);
    _appointmentList.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  Future<void> toggleAppointmentFavorite(String id) async {
    await _api.toggleAppointmentFavorite(id);
    final i = _appointmentList.indexWhere((a) => a.id == id);
    if (i != -1) {
      _appointmentList[i] = _appointmentList[i].copyWith(isFavorite: !_appointmentList[i].isFavorite);
      notifyListeners();
    }
  }

  Future<void> addService(Service s) async {
    await _api.createService(s);
    _serviceList = await _api.getServices();
    notifyListeners();
  }

  Future<void> updateService(Service s) async {
    await _api.updateService(s);
    final i = _serviceList.indexWhere((x) => x.id == s.id);
    if (i != -1) _serviceList[i] = s;
    notifyListeners();
  }

  Future<void> deleteService(String id) async {
    await _api.deleteService(id);
    _serviceList.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<void> toggleServiceFavorite(String id) async {
    // Разрешаем админу менять, даже если _currentUser пуст (или используем 'admin')
    final user = _currentUser.isNotEmpty ? _currentUser : 'admin';
    await _api.toggleServiceFavorite(user, id);
    if (_serviceFavSet.contains(id)) _serviceFavSet.remove(id); else _serviceFavSet.add(id);
    notifyListeners();
  }

  Future<void> toggleExtraFavorite(String serviceId) async {
    final user = _currentUser.isNotEmpty ? _currentUser : 'admin';
    await _api.toggleExtraFavorite(user, serviceId);
    if (_extraFavSet.contains(serviceId)) _extraFavSet.remove(serviceId); else _extraFavSet.add(serviceId);
    notifyListeners();
  }

  Future<List<String>> getServiceCategories() => _api.getServiceCategories();

  Future<void> reloadWashTypes() async {
    _washTypeList = await _api.getWashTypes();
    notifyListeners();
  }

  Future<bool> updateWashType(WashType wt) async {
    final updated = await _api.updateWashType(wt);
    if (updated != null) {
      final i = _washTypeList.indexWhere((x) => x.id == updated.id);
      if (i != -1) _washTypeList[i] = updated; else _washTypeList.add(updated);
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
            if (current.contains(washerUsername)) current.remove(washerUsername); else current.add(washerUsername);
            _appointmentList[i] = _appointmentList[i].copyWith(assignedWashers: current);
            notifyListeners();
        }
    }
    return ok;
  }

  Future<void> loadNotes({String? username}) async {
    _noteList = username != null ? await _api.getNotesByUser(username) : await _api.getNotes();
    _unreadNotes = _noteList.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> refreshUnreadCount() async {
    _unreadNotes = await _api.getUnreadNotesCount();
    notifyListeners();
  }

  Future<Note?> addNote(String username, String title, String message, String category) async {
    final note = await _api.createNote(username, title, message, category);
    if (note != null) { _noteList.insert(0, note); notifyListeners(); }
    return note;
  }

  Future<void> markNoteRead(int noteId) async {
    await _api.markNoteRead(noteId);
    final i = _noteList.indexWhere((n) => n.id == noteId);
    if (i != -1) { _noteList[i] = _noteList[i].copyWith(isRead: true); _unreadNotes = _noteList.where((n) => !n.isRead).length; notifyListeners(); }
  }

  Future<void> markAllNotesRead() async {
    await _api.markAllNotesRead();
    _noteList = _noteList.map((n) => n.copyWith(isRead: true)).toList();
    _unreadNotes = 0;
    notifyListeners();
  }

  Future<void> deleteNote(int noteId) async {
    await _api.deleteNote(noteId);
    _noteList.removeWhere((n) => n.id == noteId);
    _unreadNotes = _noteList.where((n) => !n.isRead).length;
    notifyListeners();
  }
  
  Future<void> clearDeletedByAdminFlag() async {
    await _api.clearDeletedNotification(_currentUser);
    _hasDeletedByAdmin = false;
    notifyListeners();
  }
  
  Future<void> clearAdminModifiedFlag(String id) async {
    await _api.clearAdminModifiedFlag(id);
    final i = _appointmentList.indexWhere((a) => a.id == id);
    if (i != -1) { _appointmentList[i] = _appointmentList[i].copyWith(isModifiedByAdmin: false); notifyListeners(); }
  }
}
