import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../models/service.dart';
import '../models/note.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  final _api = ApiService();

  List<Appointment> _appointmentList = [];
  List<Service>     _serviceList     = [];
  List<Note>        _noteList        = [];
  Set<String>       _extraFavSet     = {};
  Set<String>       _serviceFavSet   = {};
  String            _currentUser     = '';
  bool _loading    = true;
  bool _loadingApi = false;
  int  _unreadNotes = 0;

  List<Appointment> get appointments   => _appointmentList;
  List<Service>     get services       => _serviceList;
  List<Note>        get notes          => _noteList;
  Set<String>       get extraFavorites => _extraFavSet;
  bool              get loading        => _loading;
  bool              get loadingApi     => _loadingApi;
  int               get unreadNotes    => _unreadNotes;

  List<Appointment> get favoriteAppointments =>
      _appointmentList.where((a) => a.isFavorite).toList();

  List<Service> get favoriteServices =>
      _serviceList.where((s) => _serviceFavSet.contains(s.id)).toList();

  bool isServiceFavorite(String id) => _serviceFavSet.contains(id);

  Future<void> init() async {
    _loading = true;
    notifyListeners();

    _serviceList = await _api.getServices();
    _loading = false;
    notifyListeners();
  }

  Future<void> reloadAppointments() async {
    _appointmentList = await _api.getAppointments();
    notifyListeners();
  }

  Future<void> reloadForUser(String username) async {
    _currentUser     = username.toLowerCase();
    _appointmentList = await _api.getAppointmentsByOwner(_currentUser);
    _extraFavSet     = await _api.getExtraFavorites(_currentUser);
    _serviceFavSet   = await _api.getServiceFavorites(_currentUser);
    notifyListeners();
  }

  Future<void> clearData() async {
    _appointmentList = [];
    _noteList        = [];
    _extraFavSet     = {};
    _serviceFavSet   = {};
    _currentUser     = '';
    _unreadNotes     = 0;
    notifyListeners();
  }

  // ─── Записи ──────────────────────────────────────────────────────────────
  Future<void> addAppointment(Appointment a) async {
    await _api.createAppointment(a);
    if (_currentUser.isNotEmpty) {
      _appointmentList = await _api.getAppointmentsByOwner(_currentUser);
    } else {
      _appointmentList = await _api.getAppointments();
    }
    notifyListeners();
    await _api.createLog(_currentUser, 'Создание записи',
        '${a.washType.displayName} · ${a.carModel} ${a.carNumber} · ${a.totalPrice}₽');
  }

  Future<void> updateAppointment(Appointment a) async {
    await _api.updateAppointment(a);
    final i = _appointmentList.indexWhere((x) => x.id == a.id);
    if (i != -1) _appointmentList[i] = a;
    notifyListeners();
    await _api.createLog(_currentUser.isNotEmpty ? _currentUser : 'admin',
        'Редактирование записи',
        '${a.washType.displayName} · ${a.carModel} · статус: ${a.status}');
  }

  Future<void> deleteAppointment(String id) async {
    final appt = _appointmentList.firstWhere((a) => a.id == id,
        orElse: () => _appointmentList.first);
    await _api.deleteAppointment(id);
    _appointmentList.removeWhere((a) => a.id == id);
    notifyListeners();
    await _api.createLog(_currentUser.isNotEmpty ? _currentUser : 'admin',
        'Удаление записи',
        '${appt.washType.displayName} · ${appt.carModel} ${appt.carNumber}');
  }

  Future<void> toggleAppointmentFavorite(String id) async {
    await _api.toggleAppointmentFavorite(id);
    final i = _appointmentList.indexWhere((a) => a.id == id);
    if (i != -1) {
      _appointmentList[i] = _appointmentList[i].copyWith(
          isFavorite: !_appointmentList[i].isFavorite);
      notifyListeners();
    }
  }

  Future<Map<String, int>> getStats() => _api.getAppointmentStats();

  // ─── Услуги ──────────────────────────────────────────────────────────────
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
    if (_currentUser.isEmpty) return;
    final wasFav = _serviceFavSet.contains(id);
    await _api.toggleServiceFavorite(_currentUser, id);
    if (wasFav) {
      _serviceFavSet.remove(id);
    } else {
      _serviceFavSet.add(id);
    }
    notifyListeners();
    final svc = _serviceList.firstWhere((s) => s.id == id,
        orElse: () => _serviceList.first);
    await _api.createLog(_currentUser,
        wasFav ? 'Убрано из избранного' : 'Добавлено в избранное', svc.name);
  }

  Future<List<String>> getServiceCategories() => _api.getServiceCategories();

  // ─── Избранные доп. услуги ─────────────────────────────────────────────
  Future<void> toggleExtraFavorite(String serviceName) async {
    if (_currentUser.isEmpty) return;
    final wasFav = _extraFavSet.contains(serviceName);
    await _api.toggleExtraFavorite(_currentUser, serviceName);
    if (wasFav) {
      _extraFavSet.remove(serviceName);
    } else {
      _extraFavSet.add(serviceName);
    }
    notifyListeners();
    await _api.createLog(_currentUser,
        wasFav ? 'Доп. услуга убрана из избранного' : 'Доп. услуга добавлена в избранное',
        serviceName);
  }

  bool isExtraFavorite(String serviceName) =>
      _extraFavSet.contains(serviceName);

  // ─── Заметки мойщика ──────────────────────────────────────────────────────
  Future<void> loadNotes({String? username}) async {
    if (username != null) {
      _noteList = await _api.getNotesByUser(username);
    } else {
      _noteList = await _api.getNotes();
    }
    _unreadNotes = _noteList.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> refreshUnreadCount() async {
    _unreadNotes = await _api.getUnreadNotesCount();
    notifyListeners();
  }

  Future<Note?> addNote(String username, String title, String message, String category) async {
    final note = await _api.createNote(username, title, message, category);
    if (note != null) {
      _noteList.insert(0, note);
      notifyListeners();
      await _api.createLog(username, 'Создание заметки', title);
    }
    return note;
  }

  Future<void> markNoteRead(int noteId) async {
    await _api.markNoteRead(noteId);
    final i = _noteList.indexWhere((n) => n.id == noteId);
    if (i != -1) {
      _noteList[i] = Note(
        id: _noteList[i].id,
        username: _noteList[i].username,
        title: _noteList[i].title,
        message: _noteList[i].message,
        category: _noteList[i].category,
        isRead: true,
        createdAt: _noteList[i].createdAt,
      );
      _unreadNotes = _noteList.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  Future<void> markAllNotesRead() async {
    await _api.markAllNotesRead();
    _noteList = _noteList.map((n) => Note(
      id: n.id,
      username: n.username,
      title: n.title,
      message: n.message,
      category: n.category,
      isRead: true,
      createdAt: n.createdAt,
    )).toList();
    _unreadNotes = 0;
    notifyListeners();
  }

  Future<void> deleteNote(int noteId) async {
    await _api.deleteNote(noteId);
    _noteList.removeWhere((n) => n.id == noteId);
    _unreadNotes = _noteList.where((n) => !n.isRead).length;
    notifyListeners();
  }
}
